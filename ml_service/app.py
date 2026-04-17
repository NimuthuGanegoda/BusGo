"""
BUSGO ML Microservice
=====================
Flask service exposing 3 endpoints for the Node.js backend:
  POST /ml/rating        — Driver rating prediction (Model 1)
  POST /ml/eta           — Bus ETA prediction       (Model 2)
  POST /ml/alert-priority — Alert prioritization    (Model 3)
Place all .pkl files in the ./models/ directory before starting.
"""
import os
import re
import json
import warnings
import logging
import numpy as np
import pandas as pd
import joblib
import emoji
import nltk
from flask import Flask, request, jsonify
from scipy.sparse import hstack, csr_matrix
from sentence_transformers import SentenceTransformer
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from deep_translator import GoogleTranslator
from langdetect import detect
warnings.filterwarnings("ignore")
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("busgo-ml")
nltk.download("stopwords", quiet=True)
nltk.download("wordnet", quiet=True)
app = Flask(__name__)
MODELS_DIR = os.path.join(os.path.dirname(__file__), "models")

# ── Global model holders ───────────────────────────────────────────────────────
rating_model = rating_vectorizer = rating_scaler = rating_meta_names = rating_calibrator = None
eta_model = eta_driver_encoder = eta_feature_cols = None
alert_fa_model = alert_prio_model = alert_tfidf = alert_features = alert_sbert = None

# ══════════════════════════════════════════════════════════════════════════════
#  STARTUP — load all models once
# ══════════════════════════════════════════════════════════════════════════════
def load_all_models():
    global rating_model, rating_vectorizer, rating_scaler, rating_meta_names, rating_calibrator
    global eta_model, eta_driver_encoder, eta_feature_cols
    global alert_fa_model, alert_prio_model, alert_tfidf, alert_features, alert_sbert

    log.info("Loading Model 1 — Rating Predictor...")
    rating_model       = joblib.load(os.path.join(MODELS_DIR, "bus_rating_model_v5.pkl"))
    rating_vectorizer  = joblib.load(os.path.join(MODELS_DIR, "vectorizer_v5.pkl"))
    rating_scaler      = joblib.load(os.path.join(MODELS_DIR, "meta_scaler_v5.pkl"))
    rating_meta_names  = joblib.load(os.path.join(MODELS_DIR, "meta_feature_names_v5.pkl"))
    cal_path = os.path.join(MODELS_DIR, "calibrator_v5.pkl")
    rating_calibrator  = joblib.load(cal_path) if os.path.exists(cal_path) else None
    log.info("✅ Rating model loaded")

    log.info("Loading Model 2 — ETA Predictor...")
    eta_model          = joblib.load(os.path.join(MODELS_DIR, "optimized_bus_model.pkl"))
    eta_driver_encoder = joblib.load(os.path.join(MODELS_DIR, "driver_id_encoder.pkl"))
    with open(os.path.join(MODELS_DIR, "model_metadata.json")) as f:
        meta = json.load(f)
    eta_feature_cols = meta["features"]
    log.info("✅ ETA model loaded")

    log.info("Loading Model 3 — Alert Prioritizer...")
    alert_fa_model   = joblib.load(os.path.join(MODELS_DIR, "model_false_alert_xgb.pkl"))
    alert_prio_model = joblib.load(os.path.join(MODELS_DIR, "model_priority_lgbm.pkl"))
    alert_tfidf      = joblib.load(os.path.join(MODELS_DIR, "tfidf_vectorizer.pkl"))
    alert_features   = joblib.load(os.path.join(MODELS_DIR, "feature_list.pkl"))
    log.info("Loading Sentence-BERT (this may take ~30s on first run)...")
    alert_sbert      = SentenceTransformer("all-MiniLM-L6-v2")
    log.info("✅ Alert prioritizer loaded")
    log.info("🚀 All 3 models ready!")

# ══════════════════════════════════════════════════════════════════════════════
#  MODEL 1 — RATING PREDICTION HELPERS
# ══════════════════════════════════════════════════════════════════════════════
base_stopwords = set(stopwords.words("english"))
sentiment_keep = {
    "not","no","never","don't","doesn't","didn't","won't","can't","couldn't",
    "wouldn't","shouldn't","isn't","aren't","wasn't","weren't","hasn't","haven't",
    "very","extremely","really","too","so","quite","completely","totally","utterly",
    "good","bad","well","better","worse","best","worst","more","most","less","least",
    "great","but","however","although","though","despite","even","still","only","just","yet",
}
english_stopwords = base_stopwords - sentiment_keep
lemmatizer = WordNetLemmatizer()

SINHALA_MAP = {
    "ගොඩක්":"extremely very","ගොඩාක්":"extremely very","හරිම":"extremely",
    "ඉතා":"very","බොහෝ":"very much","නරකම":"terrible worst",
    "හොඳම":"superb finest","අපහසු":"extremely uncomfortable",
    "කෝපෙන්":"angry aggressive rude","ලේට්":"late delayed",
    "රූඩ්":"rude impolite","නරක":"bad poor","හොඳ":"good",
    "බය":"scared frightened dangerous",
}

# ── Sentiment word lists ───────────────────────────────────────────────────────
NEGATIVE_WORDS = [
    'rude','dirty','late','dangerous','drunk','reckless','aggressive','filthy',
    'bad','terrible','worst','horrible','awful','unacceptable','unsafe',
    'threatening','shouted','overcrowded','smelly','broken','overcharge',
    'delay','delayed','angry','impatient','careless','speeding','accident',
    'useless','disgusting','pathetic','irresponsible','dishonest',
    'dreadful','appalling','shocking','outrageous','horrible','nasty',
    'disappointing','disappointed','frustrating','frustrated','annoying',
    'annoyed','poor','unpleasant','uncomfortable','unhappy','unhelpful',
]

POSITIVE_WORDS = [
    'excellent','polite','helpful','clean','professional','friendly',
    'comfortable','punctual','great','amazing','wonderful','superb',
    'perfect','outstanding','courteous','pleasant','smooth','good',
    'nice','happy','satisfied','recommend','best','well','impressive',
    'brilliant','fantastic','exceptional','loved','love','awesome',
    'beautiful','safe','on time','arrived on time','very good',
    'very clean','very polite','very helpful','very friendly',
    'very comfortable','enjoyed','enjoyable','pleased','impressed',
    'glad','grateful','thankful','loving','fabulous','terrific',
    'delightful','marvelous','splendid','magnificent','incredible',
    'superb','positive','great experience','good experience',
    'highly recommend','well done','keep it up','appreciate',
    'grateful','thank you','thumbs up','five star','top notch',
]

STRONG_POSITIVE = [
    'fantastic','excellent','amazing','wonderful','superb','outstanding',
    'brilliant','exceptional','awesome','loved','love','loving','perfect',
    'best','incredible','fabulous','magnificent','terrific','splendid',
    'delightful','marvelous','enjoyed','enjoyable','pleased','impressed',
    'great experience','highly recommend','very good','very happy',
    'very satisfied','thoroughly enjoyed','absolutely','five star',
    'top notch','best ever','so good','really good','really great',
    'really happy','really satisfied','very impressed','very pleased',
]

def detect_lang(text):
    cleaned = str(text).strip()
    has_si  = bool(re.search(r"[\u0D80-\u0DFF]+", cleaned))
    has_en  = bool(re.search(r"[a-zA-Z]+", cleaned))
    if has_si and has_en: return "mixed"
    if has_si:
        try:    return "si" if detect(cleaned) == "si" else "en"
        except: return "si"
    return "en"

def protect_negs(text):
    pat = (r"\b(not|no|never|dont|doesnt|didnt|wont|cant|couldnt|wouldnt|"
           r"shouldnt|isnt|arent|wasnt|werent|hasnt|havent)\b\s+(\w+)")
    return re.sub(pat, lambda m: m.group(0).replace(" ", "_"), text, flags=re.IGNORECASE)

def handle_emojis(text):
    pos = {"😊","😄","😁","👍","❤️","🙏","✨","😍","🌟","👏","🎉","😃","🥰","💯","🤩","😀","🙌","💪"}
    neg = {"😡","😠","👎","💔","😤","🤬","😒","😞","😣","🤮","😢","😭","😩","🤦","💀","😑"}
    for e in pos: text = text.replace(e, " positive_emoji ")
    for e in neg: text = text.replace(e, " negative_emoji ")
    return emoji.replace_emoji(text, replace="")

def clean_comment(comment):
    comment = str(comment).lower()
    comment = handle_emojis(comment)
    comment = protect_negs(comment)
    comment = re.sub(r"[^a-z_\s]", "", comment)
    comment = re.sub(r"\s+", " ", comment).strip()
    tokens  = [lemmatizer.lemmatize(t) for t in comment.split() if t not in english_stopwords]
    return " ".join(tokens)

def process_comment(comment):
    if not isinstance(comment, str) or not comment.strip():
        return ""
    lang = detect_lang(comment)
    if lang in ("si", "mixed"):
        for s, e in SINHALA_MAP.items():
            comment = comment.replace(s, e)
        try:
            comment = GoogleTranslator(source="auto", target="en").translate(comment) or comment
        except: pass
    return clean_comment(comment)

def extract_meta(comment_raw, hour=12, is_peak=0, is_weekend=0, is_night=0,
                 is_raining=0, driver_id=None, driver_history=None, specificity_score=None):
    raw   = str(comment_raw) if isinstance(comment_raw, str) else ""
    lower = raw.lower()
    words = raw.split()
    f = {}
    f["word_count"]           = len(words)
    f["char_count"]           = len(raw)
    f["avg_word_length"]      = np.mean([len(w) for w in words]) if words else 0
    f["exclamation_count"]    = raw.count("!")
    f["question_count"]       = raw.count("?")
    f["caps_word_count"]      = sum(1 for w in words if w.isupper() and len(w) > 2)
    f["caps_ratio"]           = f["caps_word_count"] / max(len(words), 1)
    pos_em = {"😊","😄","😁","👍","❤️","🙏","✨","😍","🌟","👏","🎉","🥰","💯"}
    neg_em = {"😡","😠","👎","💔","😤","🤬","😒","😞","🤮","😢","😭","🤦"}
    f["positive_emoji_count"] = sum(raw.count(e) for e in pos_em)
    f["negative_emoji_count"] = sum(raw.count(e) for e in neg_em)
    f["negation_count"]       = sum(lower.count(n) for n in
        ["not","no","never","don't","doesn't","didn't","won't","can't"])
    f["mentions_driver"]      = int(any(w in lower for w in
        ["driver","rude","polite","helpful","friendly","aggressive",
         "shouted","yelled","courteous","impatient"]))
    f["mentions_vehicle"]     = int(any(w in lower for w in
        ["clean","dirty","seat","ac","air","smell","comfortable",
         "filthy","broken","damp","smelly","condition"]))
    f["mentions_punctuality"] = int(any(w in lower for w in
        ["late","delay","wait","punctual","schedule","cancel",
         "on time","behind","overdue"]))
    f["mentions_safety"]      = int(any(w in lower for w in
        ["safe","unsafe","speed","reckless","dangerous","drunk",
         "accident","swerving","brake","carelessly"]))
    f["mentions_fare"]        = int(any(w in lower for w in
        ["fare","price","charge","expensive","overcharge",
         "money","pay","extra","fee","rupee"]))
    f["has_numbers"]          = int(bool(re.search(r"\d", raw)))
    f["number_count"]         = len(re.findall(r"\d+", raw))
    f["hour_of_day"]          = int(hour)
    f["is_peak"]              = int(is_peak)
    f["is_weekend"]           = int(is_weekend)
    f["is_night"]             = int(is_night)
    f["is_morning_peak"]      = int(7 <= int(hour) <= 9 and not is_weekend)
    f["is_evening_peak"]      = int(17 <= int(hour) <= 19 and not is_weekend)
    f["is_raining"]           = int(is_raining)
    f["peak_x_lateness"]      = int(is_peak and f["mentions_punctuality"])
    f["rain_x_lateness"]      = int(is_raining and f["mentions_punctuality"])
    f["rain_x_cleanliness"]   = int(is_raining and f["mentions_vehicle"])
    f["peak_x_overcrowding"]  = int(is_peak and "crowd" in lower)
    f["offpeak_x_lateness"]   = int(not is_peak and f["mentions_punctuality"])
    f["night_x_lateness"]     = int(is_night and f["mentions_punctuality"])
    f["night_x_safety"]       = int(is_night and f["mentions_safety"])
    if specificity_score is not None:
        f["specificity_score"] = float(specificity_score)
    else:
        spec = 0.2
        if re.search(r"\d+\s*(min|hour|rs|rupee)", lower): spec += 0.25
        if re.search(r"route\s*\d+", lower):               spec += 0.20
        if len(words) > 20:                                 spec += 0.15
        f["specificity_score"] = round(min(spec, 1.0), 2)
    if driver_history and driver_id:
        hist = driver_history.get(driver_id, {})
        f["driver_historical_avg"] = float(hist.get("avg_rating", 5.0))
        f["driver_comment_count"]  = int(min(hist.get("count", 0), 100))
        f["driver_has_history"]    = int(hist.get("count", 0) > 0)
    else:
        f["driver_historical_avg"] = 5.0
        f["driver_comment_count"]  = 0
        f["driver_has_history"]    = 0
    return f

LATENESS_W  = ["late","delay","delayed","wait","waiting","behind schedule",
                "not on time","slow","long time"]
CLEANNESS_W = ["dirty","filthy","smell","wet","muddy","damp","smelly",
                "unclean","stinky","grimy"]
RUDENESS_W  = ["rude","shouted","screamed","abused","aggressive",
                "threatening","insulted","yelled"]
SAFETY_W    = ["drunk","reckless","dangerous","speeding","accident",
                "swerving","no brakes"]
CROWD_W     = ["overcrowd","overcrowded","packed","crush","standing room",
                "no seats","crammed"]

def apply_context(raw_comment, base_pred, is_raining=False, is_peak=False,
                  is_weekend=False, is_night=False):
    if not isinstance(raw_comment, str): return base_pred, "no adjustment", 1.0
    lower   = raw_comment.lower()
    adj     = float(base_pred)
    reasons = []
    conf    = 1.0
    is_rude = any(w in lower for w in RUDENESS_W)
    is_safe = any(w in lower for w in SAFETY_W)
    is_late = any(w in lower for w in LATENESS_W)
    if is_late and not is_rude and not is_safe:
        if is_peak:
            adj += 1.0; reasons.append("peak_lateness_tolerance +1.0"); conf *= 0.95
        elif is_night:
            adj -= 0.4; reasons.append("night_lateness -0.4")
        elif is_weekend:
            adj -= 0.2; reasons.append("weekend_lateness -0.2")
        else:
            adj -= 0.3; reasons.append("offpeak_lateness -0.3")
        if is_raining:
            adj += 0.6; reasons.append("rain_lateness_tolerance +0.6")
    if any(w in lower for w in CLEANNESS_W) and is_raining and not is_safe:
        adj += 0.5; reasons.append("rain_cleanliness_tolerance +0.5"); conf *= 0.95
    if any(w in lower for w in CROWD_W) and is_peak and not is_safe and not is_rude:
        adj += 0.6; reasons.append("peak_crowd_tolerance +0.6"); conf *= 0.95
    adj  = float(np.clip(adj, 1.0, 10.0))
    conf = float(np.clip(conf, 0.1, 1.0))
    return round(adj, 1), " | ".join(reasons) if reasons else "no adjustment", round(conf, 2)

def apply_sentiment_adjustment(comment, base_pred):
    """
    Post-prediction sentiment correction to compensate for training
    data imbalance (too many low-rated reviews in training set).
    """
    comment_lower = comment.lower()
    neg_count    = sum(1 for w in NEGATIVE_WORDS if w in comment_lower)
    pos_count    = sum(1 for w in POSITIVE_WORDS if w in comment_lower)
    strong_count = sum(1 for w in STRONG_POSITIVE if w in comment_lower)
    has_negative = neg_count > 0
    has_positive = pos_count > 0
    has_strong   = strong_count > 0

    adjusted = base_pred

    # Neutral floor — non-negative comments don't score below 4.0
    if not has_negative and adjusted < 4.0:
        adjusted = 4.0

    # Strong positive floor — "fantastic", "loved", "excellent" etc
    # guarantee at least 7.0 regardless of base prediction
    if has_strong and not has_negative:
        adjusted = max(adjusted, 7.0)

    # Additional boost per positive word
    if has_positive and not has_negative:
        boost    = min(pos_count * 0.8, 3.0)
        adjusted = min(adjusted + boost, 9.5)

    # Mixed signal — has both positive and negative words
    if has_positive and has_negative:
        if pos_count > neg_count * 2:
            # Mostly positive despite some negatives
            adjusted = min(adjusted + 0.8, 7.5)
        elif pos_count > neg_count:
            adjusted = min(adjusted + 0.5, 7.0)
        elif neg_count > pos_count:
            adjusted = max(adjusted - 0.5, 1.0)

    return round(float(np.clip(adjusted, 1.0, 10.0)), 1)

# ══════════════════════════════════════════════════════════════════════════════
#  MODEL 3 — ALERT PRIORITY HELPERS
# ══════════════════════════════════════════════════════════════════════════════
CRITICAL_KW = ["unconscious","not breathing","cardiac","heart attack","seizure",
               "bleeding","collapsed","knife","gun","weapon","armed","shooting",
               "explosion","fire","burning","dead","dying","ambulance","urgent",
               "immediately","brake failure","out of control","hijack","rape",
               "newborn","infant","poisoning","groping","sexual assault","stabbing",
               "unresponsive","stroke","choking","electrocution"]
HIGH_KW     = ["assault","fight","punch","blood","injury","injured","threatening",
               "robbery","steal","theft","dangerous","highway","panic","screaming",
               "harassment","following","inappropriate","exposed","recording",
               "overcrowding","intoxicated","drunk","wrong side","fracture",
               "overdose","hemorrhaging","maternity"]
FALSE_KW    = ["accident","mistake","wrong button","pocket","test","sorry",
               "nothing","lol","haha","hehe","bye","hi","ignore","false alarm",
               "ok","cancel","resolved","fine now","misunderstanding","aaa",
               "asdf","1234","nothing happened"]
TYPE_BASE   = {"Medical Emergency":4,"Criminal Activity":3,
               "Bus Breakdown":2,"Harassment":3,"Other":2}
PRIORITY_LABEL  = {5:"CRITICAL",4:"HIGH",3:"MEDIUM",2:"LOW",1:"FALSE"}
RESPONSE_ACTION = {
    5:"DISPATCH NOW — Call 119/118!",
    4:"Urgent — Contact nearest unit",
    3:"Moderate — Monitor & prepare",
    2:"Low — Log & follow up",
    1:"False Alert — No dispatch needed",
}

def clean_alert_text(text):
    if not text or str(text).strip() == "": return "no comment"
    text = str(text).lower().strip()
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    return re.sub(r"\s+", " ", text).strip()

def is_gibberish(text):
    if text == "no comment": return 0
    words = text.split()
    if not words: return 1
    alpha_r = sum(c.isalpha() for c in text) / max(len(text), 1)
    short_r = sum(1 for w in words if len(w) <= 2) / len(words)
    return 1 if (alpha_r < 0.5 or short_r > 0.8) else 0

def build_alert_features(etype, comment):
    cleaned = clean_alert_text(comment)
    crit_kw = sum(1 for kw in CRITICAL_KW if kw in cleaned)
    high_kw = sum(1 for kw in HIGH_KW if kw in cleaned)
    fals_kw = sum(1 for kw in FALSE_KW if kw in cleaned)
    row = {
        "base_priority":   TYPE_BASE.get(etype, 2),
        "comment_length":  len(str(comment)) if comment else 0,
        "word_count":      len(cleaned.split()),
        "has_comment":     int(len(str(comment)) > 3),
        "critical_kw":     crit_kw,
        "high_kw":         high_kw,
        "false_kw":        fals_kw,
        "is_gibberish":    is_gibberish(cleaned),
        "urgency_score":   crit_kw * 2 + high_kw - fals_kw * 2 - is_gibberish(cleaned) * 3,
        "type_medical":    int(etype == "Medical Emergency"),
        "type_criminal":   int(etype == "Criminal Activity"),
        "type_breakdown":  int(etype == "Bus Breakdown"),
        "type_harassment": int(etype == "Harassment"),
        "type_other":      int(etype == "Other"),
    }
    return pd.DataFrame([row])[alert_features], cleaned

# ══════════════════════════════════════════════════════════════════════════════
#  ROUTES
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "models": ["rating", "eta", "alert-priority"]})

@app.route("/ml/rating", methods=["POST"])
def predict_rating():
    try:
        body    = request.get_json(force=True)
        comment = body.get("comment", "")
        if not isinstance(comment, str) or not comment.strip():
            return jsonify({"error": "comment is required"}), 400

        cleaned = process_comment(comment)
        if not cleaned.strip():
            return jsonify({"error": "comment could not be processed"}), 422

        # ── Context ───────────────────────────────────────────────────────────
        hour_v = wkend_v = night_v = peak_v = 0
        ts = body.get("timestamp")
        if ts:
            try:
                dt      = pd.to_datetime(ts)
                hour_v  = dt.hour
                peak_v  = int((7 <= dt.hour <= 9 or 17 <= dt.hour <= 19) and dt.weekday() < 5)
                wkend_v = int(dt.weekday() >= 5)
                night_v = int(dt.hour >= 22 or dt.hour <= 5)
            except: pass

        if body.get("is_peak")    is not None: peak_v  = int(body["is_peak"])
        if body.get("is_weekend") is not None: wkend_v = int(body["is_weekend"])
        if body.get("is_night")   is not None: night_v = int(body["is_night"])
        is_raining = int(body.get("is_raining", False))

        # ── Feature extraction ────────────────────────────────────────────────
        text_vec = rating_vectorizer.transform([cleaned])
        meta_raw = extract_meta(
            comment, hour=hour_v, is_peak=peak_v, is_weekend=wkend_v,
            is_night=night_v, is_raining=is_raining,
            driver_id=body.get("driver_id"),
            driver_history=body.get("driver_history"),
            specificity_score=body.get("specificity_score"),
        )
        meta_row = pd.DataFrame([meta_raw])[rating_meta_names]
        meta_vec = csr_matrix(rating_scaler.transform(meta_row))
        combined = hstack([text_vec, meta_vec])

        # ── Model prediction ──────────────────────────────────────────────────
        raw_pred = rating_model.predict(combined.toarray())[0]
        if rating_calibrator:
            base_pred = float(np.clip(rating_calibrator.predict([raw_pred])[0], 1, 10))
        else:
            base_pred = float(np.clip(raw_pred, 1, 10))

        # ── Sentiment adjustment (compensates for training data imbalance) ────
        base_pred = apply_sentiment_adjustment(comment, base_pred)

        # ── Context adjustment ────────────────────────────────────────────────
        adjusted, reason, confidence = apply_context(
            comment, base_pred,
            is_raining=bool(is_raining),
            is_peak=bool(peak_v),
            is_weekend=bool(wkend_v),
            is_night=bool(night_v),
        )

        ctx = []
        if peak_v:     ctx.append("PEAK")
        if wkend_v:    ctx.append("WEEKEND")
        if night_v:    ctx.append("NIGHT")
        if is_raining: ctx.append("RAIN")

        return jsonify({
            "rating":     adjusted,
            "confidence": confidence,
            "base_pred":  round(base_pred, 1),
            "adjustment": reason,
            "context":    "+".join(ctx) if ctx else "NORMAL",
            "cleaned":    cleaned,
        })
    except Exception as e:
        log.exception("Rating prediction error")
        return jsonify({"error": str(e)}), 500

@app.route("/ml/eta", methods=["POST"])
def predict_eta():
    try:
        body    = request.get_json(force=True)
        bus_no  = str(body.get("bus_number", ""))
        dist_km = float(body.get("dist_km", 1))
        stops   = int(body.get("stops_remaining", 3))
        speed   = float(body.get("speed_kmh", 20))
        raining = int(body.get("is_raining", False))
        hour    = int(body.get("hour", 12))

        h_sin        = float(np.sin(2 * np.pi * hour / 24))
        h_cos        = float(np.cos(2 * np.pi * hour / 24))
        is_peak      = 1 if (7 <= hour <= 9 or 16 <= hour <= 19) else 0
        is_full_skip = 1 if (speed > 35 and stops < 5) else 0
        dist_m       = dist_km * 1000
        avg_seg      = dist_m / (stops + 1)

        try:
            driver_enc = int(eta_driver_encoder.transform([bus_no])[0])
        except:
            driver_enc = 0

        row = {
            "total_distance_to_target_m":   dist_m,
            "stops_between_bus_and_target": stops,
            "avg_segment_distance_m":       avg_seg,
            "route_encoded":                int(body.get("route_encoded", 1)),
            "road_type_encoded":            int(body.get("road_type_encoded", 1)),
            "hour_sin":                     h_sin,
            "hour_cos":                     h_cos,
            "is_peak_hour":                 is_peak,
            "is_raining":                   raining,
            "is_public_holiday":            int(body.get("is_public_holiday", 0)),
            "current_speed_kmh":            speed,
            "dwell_at_last_stop_s":         float(body.get("dwell_at_last_stop_s", 20)),
            "driver_id_enc":                driver_enc,
            "is_full_skip":                 is_full_skip,
            "dist_per_stop":                avg_seg,
            "peak_traffic_index":           is_peak * (1 / (speed + 1)),
        }

        df_input    = pd.DataFrame([row])
        log_pred    = eta_model.predict(df_input[eta_feature_cols])[0]
        eta_seconds = float(np.expm1(log_pred) * dist_km)
        eta_minutes = max(round(eta_seconds / 60, 1), 0.5)

        return jsonify({
            "eta_minutes": eta_minutes,
            "eta_seconds": round(eta_seconds, 1),
            "context": {
                "is_peak":      bool(is_peak),
                "is_full_skip": bool(is_full_skip),
                "speed_kmh":    speed,
            }
        })
    except Exception as e:
        log.exception("ETA prediction error")
        return jsonify({"error": str(e)}), 500

@app.route("/ml/alert-priority", methods=["POST"])
def predict_alert_priority():
    try:
        body    = request.get_json(force=True)
        etype   = body.get("emergency_type", "Other")
        comment = body.get("comment", "")

        X_struct, cleaned = build_alert_features(etype, comment)

        # ── Stage 1: False alert detection ────────────────────────────────────
        false_prob = None
        try:
            X_tfidf    = alert_tfidf.transform([cleaned])
            X_combined = hstack([csr_matrix(X_struct.values), X_tfidf])
            expected   = getattr(alert_fa_model, "n_features_in_", None)
            if expected is not None and X_combined.shape[1] != expected:
                raise ValueError(
                    f"Feature shape mismatch: expected {expected}, got {X_combined.shape[1]}"
                )
            false_prob = float(alert_fa_model.predict_proba(X_combined)[0][1])
            log.info(f"XGBoost false-alert prob: {false_prob:.3f}")
        except Exception as stage1_err:
            log.warning(f"Stage 1 ML failed ({stage1_err}), using rule-based fallback")

        if false_prob is None:
            fals_kw    = float(X_struct["false_kw"].values[0])
            gibs       = float(X_struct["is_gibberish"].values[0])
            false_prob = float(min(fals_kw * 0.35 + gibs * 0.40, 0.99))

        is_false = (false_prob > 0.50)

        # ── Stage 2: Priority scoring ─────────────────────────────────────────
        embedding = alert_sbert.encode([cleaned])
        X_prio    = np.hstack([X_struct.values, embedding])

        if is_false:
            priority = 1
            conf     = false_prob
        else:
            priority = int(alert_prio_model.predict(X_prio)[0])
            priority = int(np.clip(priority, 1, 5))
            conf     = float(max(alert_prio_model.predict_proba(X_prio)[0]))

        log.info(
            f"Alert priority result: {PRIORITY_LABEL.get(priority)} "
            f"(false={is_false}, conf={conf:.2f})"
        )

        return jsonify({
            "priority":        priority,
            "priority_label":  PRIORITY_LABEL.get(priority, "UNKNOWN"),
            "action":          RESPONSE_ACTION.get(priority, ""),
            "is_false_alert":  is_false,
            "false_prob":      round(false_prob, 3),
            "confidence":      round(conf, 3),
            "cleaned_comment": cleaned,
        })
    except Exception as e:
        log.exception("Alert priority error")
        return jsonify({"error": str(e)}), 500

# ══════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    load_all_models()
    port = int(os.environ.get("ML_PORT", 8000))
    log.info(f"Starting BUSGO ML Service on port {port}")
    app.run(host="0.0.0.0", port=port, debug=False)