# Model 1 — Bus Driver Rating System
## Detailed Technical Report
**Project:** BUSGO — Sri Lanka Bus Management System
**University:** Edith Cowan University
**Author:** Nimuthu Ganegoda
**Date:** April 2026

---

## 1. Overview

Model 1 is a **passenger review rating engine** that reads a written comment left by a bus passenger and outputs a numeric driver rating between **1 and 10**. It is not a simple sentiment analyser — it is a multi-input regression model that combines natural language understanding with contextual real-world factors such as the time of day, weather conditions, peak hour status, and the driver's own historical performance record.

The reason a machine learning model was needed here rather than a simple rule-based system is that passenger comments are messy, multilingual (English and Sinhala), emoji-heavy, and contextually nuanced. A comment like *"Bus was late but I understand it was rush hour and raining heavily"* should not be penalised the same way as *"Bus was late for no reason."* The model is designed to understand that distinction.

---

## 2. Files in the Model Package

| File | Type | Purpose |
|------|------|---------|
| `bus_rating_model_v5.pkl` | LGBMRegressor | The core trained ML model that predicts the raw rating |
| `vectorizer_v5.pkl` | TF-IDF Vectorizer | Converts cleaned comment text into a 3,000-feature numeric vector |
| `meta_scaler_v5.pkl` | StandardScaler | Normalises the 35 structural/contextual features to zero mean |
| `meta_feature_names_v5.pkl` | Python list | Ordered list of the 35 meta-feature names used during training |
| `calibrator_v5.pkl` | IsotonicRegression | Post-prediction calibrator that adjusts raw model output to true scale |
| `busgo_predictor.py` | Python script | Deployment wrapper — loads all 5 files and exposes the prediction API |

---

## 3. Full Pipeline — Step by Step

The prediction pipeline has **6 distinct stages**. Every comment passes through all 6 before a final rating is produced.

```
Raw Comment (text string)
        │
        ▼
[Stage 1] Language Detection & Translation
        │
        ▼
[Stage 2] Text Cleaning & Preprocessing
        │
        ▼
[Stage 3] TF-IDF Vectorization  ──────────────────┐
                                                   │
[Stage 4] Meta-Feature Extraction (35 features) ──┤
                                                   │
                                              [hstack]
                                                   │
                                                   ▼
                                        Combined Feature Matrix
                                                   │
                                                   ▼
                                        [Stage 5] LightGBM Regressor
                                                   │
                                                   ▼
                                        [Stage 5b] Isotonic Calibration
                                                   │
                                                   ▼
                                        [Stage 6] Context Adjustment
                                                   │
                                                   ▼
                                        Final Rating (1.0 – 10.0)
```

---

## 4. Stage 1 — Language Detection and Translation

Sri Lankan bus passengers write reviews in three ways: pure English, pure Sinhala, or mixed (Singlish). The model handles all three.

**How it works:**

The system first scans the comment for Unicode characters in the Sinhala block (U+0D80 to U+0DFF). If Sinhala characters are present alongside English characters, it is classified as `mixed`. If only Sinhala is present, `langdetect` confirms it as `si`. Everything else is treated as `en`.

For Sinhala and mixed comments, two things happen before translation:

1. A **Sinhala intensity map** replaces key Sinhala words with their English equivalents that carry the right emotional weight. For example:
   - `ගොඩක්` → `"extremely very"`
   - `නරකම` → `"terrible worst"`
   - `හොඳම` → `"superb finest"`
   - `කෝපෙන්` → `"angry aggressive rude"`

   This step is critical because Google Translate sometimes softens emotional intensity, so the replacement ensures the severity of the original Sinhala phrasing survives translation.

2. Google Translate (`deep-translator`) is then called to convert the full comment to English.

This makes the model usable for all BUSGO passengers regardless of their language.

---

## 5. Stage 2 — Text Cleaning and Preprocessing

Once the comment is in English, a 5-step cleaning pipeline runs:

**Step 1 — Emoji Handling**
Emojis are not removed — they carry sentiment. Instead, positive emojis (`😊 👍 ❤️ 🙏 💯`) are replaced with the token `positive_emoji` and negative emojis (`😡 👎 😤 🤬 💀`) are replaced with `negative_emoji`. Unknown emojis are then stripped.

**Step 2 — Negation Protection**
Words like `not`, `don't`, `didn't`, `can't`, `never` are joined with the word that follows them using an underscore. For example, `"not good"` becomes `"not_good"` and `"didn't arrive"` becomes `"didn't_arrive"`. This prevents the model from reading `not_good` as just `good` — a common failure mode in naive NLP pipelines.

**Step 3 — Character Cleaning**
Everything except lowercase letters and underscores is removed. Numbers and punctuation are stripped at this stage.

**Step 4 — Custom Stopword Removal**
Standard English stopwords are removed, but with one important modification: sentiment-critical words are kept even though they appear in standard stopword lists. Preserved words include: `not`, `no`, `never`, `very`, `extremely`, `really`, `good`, `bad`, `better`, `worse`, `best`, `worst`, `but`, `however`, `still`, `only`, `just`.

**Step 5 — Lemmatization**
Each remaining token is lemmatized using NLTK's `WordNetLemmatizer`. This reduces `"driving"`, `"driven"`, and `"drove"` all to `"drive"` so the model treats them as the same word.

---

## 6. Stage 3 — TF-IDF Vectorization

The cleaned comment text is converted into a **3,000-dimensional numeric vector** using a trained TF-IDF (Term Frequency–Inverse Document Frequency) vectorizer.

**Key configuration:**

| Parameter | Value | What it means |
|-----------|-------|----------------|
| `max_features` | 3,000 | Only the 3,000 most informative words/phrases from the training corpus are kept |
| `ngram_range` | (1, 3) | Single words, 2-word phrases, AND 3-word phrases are all captured |
| `min_df` | 2 | A word must appear in at least 2 different training comments to be included |
| `sublinear_tf` | True | Term frequency is log-scaled — prevents very long comments from dominating |

The `ngram_range=(1,3)` setting is particularly important for this domain. Phrases like `"very rude"`, `"not on time"`, `"extremely helpful driver"`, and `"nearly caused accident"` all carry different meaning than their individual words. Capturing trigrams lets the model learn these compound phrases directly from training data.

The output of this stage is a sparse matrix of shape `(1, 3000)`.

---

## 7. Stage 4 — Meta-Feature Extraction (35 Features)

This is what makes Model 1 significantly more sophisticated than a basic text classifier. In parallel with the text vectorization, 35 structured features are extracted directly from the raw (untranslated) comment and from the prediction context provided by the app.

These 35 features are grouped into 6 categories:

### 7.1 Linguistic / Structural Features (7 features)
| Feature | What it captures |
|---------|-----------------|
| `word_count` | Length of the review — very short reviews are often vague |
| `char_count` | Total character count |
| `avg_word_length` | Vocabulary complexity |
| `exclamation_count` | Emotional intensity |
| `question_count` | Uncertainty or complaint framing |
| `caps_word_count` | Shouting / strong emotion (e.g. "RUDE DRIVER") |
| `caps_ratio` | Proportion of ALL-CAPS words |

### 7.2 Sentiment Signals (3 features)
| Feature | What it captures |
|---------|-----------------|
| `positive_emoji_count` | Count of 😊👍❤️ type emojis in the original text |
| `negative_emoji_count` | Count of 😡👎💀 type emojis |
| `negation_count` | How many negation words appear (not, never, don't, can't) |

### 7.3 Topic Mentions (5 features)
These are binary flags (0 or 1) that detect whether specific complaint categories appear:
| Feature | Triggered by keywords like... |
|---------|------------------------------|
| `mentions_driver` | rude, polite, helpful, friendly, aggressive, shouted, courteous |
| `mentions_vehicle` | clean, dirty, seat, AC, smell, comfortable, filthy, broken |
| `mentions_punctuality` | late, delay, wait, punctual, schedule, cancel, on time |
| `mentions_safety` | safe, speed, reckless, dangerous, drunk, accident, braking |
| `mentions_fare` | fare, price, charge, expensive, overcharge, rupee |

### 7.4 Temporal / Contextual Features (8 features)
These are passed in from the app at prediction time and tell the model **when and under what conditions** the journey happened:
| Feature | Source |
|---------|--------|
| `hour_of_day` | From timestamp (0–23) |
| `is_peak` | True if 7–9am or 5–7pm on a weekday |
| `is_morning_peak` | Specifically 7–9am weekday |
| `is_evening_peak` | Specifically 5–7pm weekday |
| `is_weekend` | Saturday or Sunday |
| `is_night` | After 10pm or before 5am |
| `is_raining` | Passed in from weather API |

### 7.5 Interaction / Cross Features (6 features)
These combine two signals to capture nuanced situations:
| Feature | What it means |
|---------|--------------|
| `peak_x_lateness` | Late during peak hour — more forgivable |
| `rain_x_lateness` | Late during rain — more forgivable |
| `rain_x_cleanliness` | Dirty during rain — partially forgivable |
| `peak_x_overcrowding` | Crowded during peak — expected, more forgivable |
| `offpeak_x_lateness` | Late when it is NOT peak — less forgivable |
| `night_x_safety` | Safety concern at night — more serious |

### 7.6 Driver History Features (3 features)
If the app passes in the driver's ID and their historical record:
| Feature | What it captures |
|---------|-----------------|
| `driver_historical_avg` | Their average rating across all past trips |
| `driver_comment_count` | How many reviews they have (experience level) |
| `driver_has_history` | Binary flag — whether history data exists at all |

### 7.7 Review Quality (1 feature)
| Feature | What it captures |
|---------|-----------------|
| `specificity_score` | How detailed and specific the review is (0–1). Boosted if the review mentions specific numbers, route numbers, or exceeds 20 words. Vague reviews like "ok" score near 0. |

After extraction, all 35 features are passed through a **StandardScaler** which normalises each feature to have zero mean and unit variance. This prevents large-magnitude features (like `char_count` which might be 300) from overwhelming small-magnitude features (like `is_peak` which is 0 or 1).

The scaled features become a sparse matrix of shape `(1, 35)`.

---

## 8. Feature Combination

The 3,000-dimensional TF-IDF vector and the 35-dimensional meta-feature vector are **horizontally stacked** using `scipy.sparse.hstack`, producing a combined feature matrix of shape `(1, 3035)`.

```python
combined = hstack([text_vec, meta_vec])  # shape: (1, 3035)
```

This combined matrix is what gets fed into the LightGBM model.

---

## 9. Stage 5 — LightGBM Regressor

The core prediction is made by a **LightGBM Gradient Boosting Decision Tree** regressor (`LGBMRegressor`).

**Why LightGBM and not another algorithm?**
LightGBM was chosen over alternatives like Random Forest and XGBoost for three reasons: it handles sparse matrices (from TF-IDF) efficiently, it performs well on mixed feature types (text features alongside binary flags and continuous values), and it trains significantly faster. The model was originally explored with Random Forest (task 3.21 in the Gantt) before switching to LightGBM after accuracy testing.

**Trained hyperparameters:**

| Parameter | Value | Effect |
|-----------|-------|--------|
| `n_estimators` | 700 | 700 decision trees are built and combined |
| `learning_rate` | 0.05 | Each tree makes a small correction — prevents overfitting |
| `max_depth` | 10 | Maximum depth of each individual tree |
| `num_leaves` | 63 | Controls complexity — 63 leaf nodes per tree |
| `min_child_samples` | 5 | A leaf must cover at least 5 training samples |
| `boosting_type` | `gbdt` | Gradient Boosted Decision Trees (standard boosting) |
| `random_state` | 42 | Reproducibility seed |

The model outputs a raw floating-point regression value — not a class label. For example, it might output `6.234` for a moderately positive review.

---

## 10. Stage 5b — Isotonic Calibration

After the LightGBM model makes its raw prediction, the output is passed through an **Isotonic Regression calibrator** (`IsotonicRegression`).

**What calibration does and why it is needed:**

During training, regression models often exhibit a bias at the extremes of the scale — they tend to predict values closer to the mean than the true extremes. For a rating scale of 1–10, the model might predict 7.2 for what a passenger genuinely meant as a 9, or 3.8 for what was genuinely a 2. Isotonic regression is a non-parametric monotone function that was trained to correct this compression by mapping the model's output distribution to the true target distribution from the training data.

The calibrator is configured with `increasing=True` (the mapping is monotonically increasing) and `out_of_bounds='clip'` (values outside the trained range are clipped rather than extrapolated).

The final calibrated prediction is clipped to the range `[1.0, 10.0]`.

---

## 11. Stage 6 — Context Adjustment (Post-Prediction Rules)

After calibration, a rule-based adjustment layer is applied. This layer reads the raw comment again and the contextual inputs, and applies small upward or downward corrections to the rating.

**The adjustments work as follows:**

| Situation detected | Adjustment | Reasoning |
|--------------------|-----------|-----------|
| Lateness mentioned + peak hour | **+1.0** | Traffic-related delays during peak are expected and partially excusable |
| Lateness mentioned + raining | **+0.6** | Rain delays are partially excusable |
| Lateness mentioned + night time | **−0.4** | Night lateness is less excusable — fewer traffic reasons |
| Lateness mentioned + off-peak | **−0.3** | Off-peak lateness has no justification |
| Dirt/smell mentioned + raining | **+0.5** | Wet weather makes buses dirty — partially excusable |
| Overcrowding mentioned + peak | **+0.6** | Overcrowding during peak is structurally expected |

**Safety and rudeness override:** If the comment mentions drunk driving, reckless driving, dangerous behaviour, shouting, screaming, abuse, or threats — **no positive adjustments are applied regardless of context**. A driver who is drunk during peak hour does not receive a lateness tolerance bonus.

The final adjusted value is clipped to `[1.0, 10.0]` and rounded to one decimal place.

---

## 12. Output Format

Each prediction returns a dictionary with 6 fields:

```python
{
    'rating':     7.4,              # Final adjusted rating (1.0–10.0)
    'confidence': 0.95,             # Confidence score (0–1)
    'base_pred':  6.8,              # Raw LightGBM + calibrated prediction before adjustment
    'adjustment': 'peak_lateness_tolerance +1.0 | rain_lateness_tolerance +0.6',
    'context':    'PEAK+RAIN',      # Active context flags
    'cleaned':    'bus late understand rush hour rain heavi'  # Preprocessed text used
}
```

---

## 13. Deployment in BUSGO

In the BUSGO system, this model is served via a **Flask REST API** running inside a Docker container on port 8000, alongside the Node.js backend on port 5000.

When a passenger submits a review through the BUSGO client app:

1. The review text is sent to the Node.js backend
2. Node.js forwards it to the Python ML service at `/predict/rating`
3. The Flask service loads the pre-trained model files (loaded once at startup, not per request)
4. The 6-stage pipeline runs and returns the rating dictionary
5. Node.js stores the rating in the Supabase database against the driver's profile
6. The driver's cumulative average rating is updated in real time

The model files are not retrained on every new review. Retraining is a separate offline process handled by `retrain_rating_vectorizer.py` which is included in the deployment bundle.

---

## 14. Key Design Decisions and Trade-offs

**Why not just use a sentiment score?**
A simple positive/negative sentiment classifier cannot produce a 1–10 scale with any meaningful discrimination between a 6 and an 8. The combined TF-IDF + meta-feature approach allows much finer granularity.

**Why 3,000 TF-IDF features and not more?**
The training dataset was scraped from real bus review sources. With a limited corpus size, using more than 3,000 features would include very rare words that only appeared once or twice, which introduces noise rather than signal. The `min_df=2` threshold enforces this.

**Why trigrams?**
Unigrams alone miss phrases like `"not clean"`, `"very rude"`, `"arrived on time"`, `"no air conditioning"`. Trigrams capture these three-word complaint patterns that are very common in transport reviews.

**Why isotonic calibration rather than Platt scaling?**
Isotonic regression makes no assumptions about the shape of the calibration function — it just enforces monotonicity. For a rating scale where the relationship between raw predictions and true values may not be linear or sigmoid, this non-parametric approach is more appropriate than Platt scaling.

**Why a post-prediction rule layer instead of encoding context purely in the model?**
The context adjustment rules (peak tolerance, rain tolerance) encode domain knowledge that is stable and interpretable. Encoding these purely as learned features risks the model finding spurious correlations in limited training data. The hybrid approach gives the ML model responsibility for understanding the text, while the rule layer handles the structured context adjustments with full transparency and explainability.

---

## 15. Summary

| Property | Value |
|----------|-------|
| Task type | Regression (predicts a continuous rating 1–10) |
| Core algorithm | LightGBM Gradient Boosted Decision Trees |
| Text features | TF-IDF, 3,000 features, trigrams |
| Structural features | 35 meta-features (linguistic, temporal, contextual, driver history) |
| Total input features | 3,035 per prediction |
| Languages supported | English, Sinhala, mixed Singlish |
| Post-processing | Isotonic calibration + context adjustment rules |
| Output | Rating (1.0–10.0), confidence, base prediction, adjustment reason, context flags |
| Deployment | Flask REST API, Docker container, port 8000 |
| Model files | 5 .pkl files totalling approximately 2.3 MB |
