# Model 3 — Emergency Alert Prioritization System
## Detailed Technical Report
**Project:** BUSGO — Sri Lanka Bus Management System
**University:** Edith Cowan University
**Author:** Nimuthu Ganegoda
**Date:** April 2026

---

## 1. Overview

Model 3 is an **emergency alert triage engine** that reads a passenger-submitted emergency alert and outputs a priority level from 1 to 5, along with a recommended dispatcher action. It is not a simple keyword scanner — it is a two-stage machine learning pipeline backed by a real-world 911 dispatch dataset, domain-specific Sri Lankan synthetic data, and a Sentence-BERT semantic embedding layer.

The reason a machine learning model was needed here rather than a simple rule-based system is that passenger distress messages are highly variable in language, completeness, and emotional framing. A passenger typing *"man groping woman repeatedly — sexual assault"* is a CRITICAL (5) alert. A passenger typing *"ok bye nothing here"* is a FALSE (1) alert. A passenger typing *"I m hurt. help"* is an abbreviated but genuine CRITICAL concern that a keyword scanner would miss entirely. The model is designed to understand all three cases.

The pipeline operates in three sequential stages: false alert screening, priority scoring, and a VADER-based urgency override that corrects for a known failure mode on informal and abbreviated distress language.

---

## 2. Files in the Model Package

| File | Type | Purpose |
|------|------|---------|
| `model_false_alert_xgb.pkl` | XGBClassifier | Stage 1 — detects whether an alert is genuine or accidental/noise |
| `model_priority_lgbm.pkl` | LGBMClassifier | Stage 2 — scores genuine alerts with a priority from 2 (LOW) to 5 (CRITICAL) |
| `tfidf_vectorizer.pkl` | TfidfVectorizer | Converts cleaned comment text into an 800-feature text vector for Stage 1 |
| `feature_list.pkl` | Python list | Ordered list of the 14 structural feature names used in training |
| `all-MiniLM-L6-v2` | SentenceTransformer | Downloaded from Hugging Face at startup — generates 384-dim semantic embeddings for Stage 2 |

---

## 3. Training Dataset

The models were not trained on invented data. The training set was built by combining two sources:

### 3.1 Montgomery County 911 Dataset (Real Data)
A public dataset of 663,522 real emergency dispatch calls (Kaggle: `mchirico/montcoalert`). Each record contains an incident title like `EMS: CARDIAC ARREST` or `Traffic: VEHICLE FIRE`. These were mapped to the five BUSGO emergency categories using a 100-entry lookup table:

| 911 Title | BUSGO Category | Priority Assigned |
|-----------|---------------|-------------------|
| `EMS: CARDIAC ARREST` | Medical Emergency | 5 — CRITICAL |
| `EMS: SHOOTING` | Criminal Activity | 5 — CRITICAL |
| `Traffic: VEHICLE FIRE` | Bus Breakdown | 5 — CRITICAL |
| `EMS: SEIZURES` | Medical Emergency | 4 — HIGH |
| `EMS: FALL VICTIM` | Medical Emergency | 3 — MEDIUM |
| `Traffic: DISABLED VEHICLE` | Bus Breakdown | 2 — LOW |
| `EMS: TRANSFERRED CALL` | Other | 1 — FALSE |

Because the 911 dataset contains only incident codes and no free-text comment fields, a **natural language comment template** was generated for each incident type. For example, `EMS: CARDIAC ARREST` was assigned the comment template: *"passenger collapsed cardiac arrest not breathing please help"*. This gave the model realistic text patterns to learn from.

To address class imbalance, sampling was capped at **6,000 records per category per priority level**, producing a balanced real-data subset of approximately 50,000 records.

### 3.2 Sri Lankan Synthetic Data
The 911 dataset has no Harassment category and no Sri Lankan-specific language patterns. A targeted synthetic dataset of **82 hand-authored samples** was added to cover:

- Sexual harassment on buses (CRITICAL to LOW)
- Verbal and ethnic harassment
- Sri Lankan geographic references (Colombo Fort, Kandy road, Galle Road, Nugegoda)
- Sri Lankan bus-specific breakdowns (expressway, flooded roads, hill brakes)
- False alert patterns in Sri Lankan English (*"lol nothing happened", "pressed by kid sorry"*)

These samples were merged with the real data and shuffled so the model treats both sources as equally important.

---

## 4. Full Pipeline — Step by Step

The prediction pipeline has **3 distinct stages** in production. All 3 run for every incoming alert.

```
Raw Alert (emergency_type + comment)
        │
        ▼
[Stage 1] Feature Engineering (14 structural features)
        │
        ├──── Structural features (14 columns)
        │           │
        │     [TF-IDF Text Vector] ──────────────────────┐
        │                                                 │
        │                                            [hstack]
        │                                                 │
        │                                                 ▼
        │                                    XGBoost False Alert Detector
        │                                                 │
        │                                       false_prob (0.0–1.0)
        │                                                 │
        │                              ┌──────────────────┴──────────────────┐
        │                          is_false = True                   is_false = False
        │                          priority = 1                              │
        │                                                                    ▼
        │                                                   [Stage 2] SBERT Embedding
        │                                                   (384-dim semantic vector)
        │                                                                    │
        │                                              Structural (14) + SBERT (384)
        │                                                         = 398 features
        │                                                                    │
        │                                                                    ▼
        │                                                  LightGBM Priority Scorer
        │                                                  priority = 2, 3, 4, or 5
        │                                                                    │
        └────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
                      [Stage 3] VADER Urgency Override (post-processing)
                      Checks raw comment for informal distress language
                      May boost priority by +1 or +2 if conditions met
                                        │
                                        ▼
                          Final Priority (1–5) + Action + Labels
```

---

## 5. Stage 1 — Feature Engineering (14 Structural Features)

Before either ML model sees the alert, 14 structured numeric features are extracted from the emergency type and the passenger comment. These features are defined in `feature_list.pkl` and were used identically during training.

### 5.1 Baseline Priority (1 feature)
| Feature | What it captures |
|---------|-----------------|
| `base_priority` | Default urgency score for the emergency category before reading the comment. Medical Emergency = 4, Criminal Activity = 3, Harassment = 3, Bus Breakdown = 2, Other = 2. This gives the model a starting expectation before the text is analysed. |

### 5.2 Comment Structure Features (3 features)
| Feature | What it captures |
|---------|-----------------|
| `comment_length` | Total character count of the raw comment. Very short comments (< 4 chars) often indicate accidental taps. |
| `word_count` | Number of space-separated tokens in the cleaned comment. |
| `has_comment` | Binary flag — 1 if comment length exceeds 3 characters, 0 otherwise. |

### 5.3 Keyword Detection Features (4 features)
Three keyword lists were hand-curated from real 911 dispatch terminology and Sri Lankan bus incident patterns:

| Feature | Keyword list examples | Effect |
|---------|----------------------|--------|
| `critical_kw` | unconscious, cardiac, stabbing, rape, brake failure, choking, electrocution | Count of CRITICAL-level keywords present |
| `high_kw` | assault, blood, injured, threatening, robbery, overcrowding, fracture | Count of HIGH-level keywords present |
| `false_kw` | accident, mistake, test, lol, nothing, sorry, bye, asdf | Count of FALSE-alert keywords present |
| `is_gibberish` | Computed — not a keyword list | 1 if alpha ratio < 50% or short-word ratio > 80%, else 0 |

### 5.4 Urgency Score (1 feature — the key signal)
```
urgency_score = (critical_kw × 2) + high_kw − (false_kw × 2) − (is_gibberish × 3)
```
This formula is the single most influential feature in the priority scoring model. It mathematically weights the evidence: critical words count double, false-alert words and gibberish impose heavy penalties. The score can be negative for junk messages.

### 5.5 Emergency Type Encoding (5 features)
| Feature | Value |
|---------|-------|
| `type_medical` | 1 if Medical Emergency, else 0 |
| `type_criminal` | 1 if Criminal Activity, else 0 |
| `type_breakdown` | 1 if Bus Breakdown, else 0 |
| `type_harassment` | 1 if Harassment, else 0 |
| `type_other` | 1 if Other, else 0 |

These five binary flags are a standard one-hot encoding that lets the model learn category-specific priority patterns without treating category names as ordered numbers.

---

## 6. Stage 1 — False Alert Detector (XGBoost + TF-IDF)

The first model is an **XGBoost binary classifier** (`model_false_alert_xgb.pkl`). Its only task is to answer: *"Is this alert genuine, or is it accidental / noise?"*

### 6.1 Why XGBoost for This Stage?
XGBoost handles sparse matrices (from TF-IDF) efficiently and produces well-calibrated probability scores. The `predict_proba` output gives a `false_prob` between 0 and 1, which allows a configurable threshold (currently 0.50) for the false-alert decision.

### 6.2 Input to This Model
The 14 structural features and the TF-IDF text vector are horizontally stacked:

```python
X_tfidf    = alert_tfidf.transform([cleaned_comment])   # shape: (1, 800)
X_combined = hstack([csr_matrix(X_struct), X_tfidf])    # shape: (1, 814)
```

The TF-IDF vectorizer (`tfidf_vectorizer.pkl`) was trained with `max_features=800` and `ngram_range=(1,2)`, meaning both individual words and two-word phrases are captured. Phrases like *"false alarm"*, *"wrong button"*, and *"nothing happened"* are captured as single features.

### 6.3 Trained Hyperparameters
| Parameter | Value | Effect |
|-----------|-------|--------|
| `n_estimators` | 300 | 300 decision trees |
| `max_depth` | 5 | Moderate complexity per tree |
| `learning_rate` | 0.08 | Small step size — reduces overfitting |
| `scale_pos_weight` | computed | Adjusts for class imbalance — false alerts are minority class |
| `eval_metric` | logloss | Optimises for calibrated probabilities |

The `scale_pos_weight` parameter is critical. Without it, XGBoost would be biased toward predicting "REAL" on every alert because genuine alerts vastly outnumber false ones in the training data. Setting `scale_pos_weight = count(REAL) / count(FALSE)` forces the model to pay extra attention to false alert patterns.

### 6.4 Decision Threshold
If `false_prob > 0.50`, the alert is marked as a false alert and assigned `priority = 1` immediately. Stage 2 is skipped.

### 6.5 Rule-Based Fallback
If the XGBoost model fails at runtime (e.g. feature dimension mismatch after a model update), a lightweight rule-based fallback activates:
```python
false_prob = min(false_kw × 0.35 + is_gibberish × 0.40, 0.99)
```
This ensures the service never crashes silently on false alerts even in edge cases.

---

## 7. Stage 2 — Sentence-BERT Embedding

For genuine alerts that pass Stage 1, a **Sentence-BERT (SBERT) semantic embedding** is generated for the cleaned comment using the `all-MiniLM-L6-v2` model.

### 7.1 What SBERT Does
Unlike TF-IDF which treats each word independently, SBERT reads the entire sentence and outputs a single **384-dimensional vector** that captures the semantic meaning and context of the full message. Two sentences with completely different words but similar meaning will have similar vectors.

For example, SBERT understands that *"passenger collapsed and is unresponsive"* and *"someone fell unconscious on the bus"* are semantically similar, even though they share no keywords except "bus". TF-IDF would score them differently.

### 7.2 Why MiniLM?
`all-MiniLM-L6-v2` is a 22M-parameter distilled model that produces embeddings nearly as accurate as large BERT variants but runs 5× faster. For a real-time emergency alert system, inference latency matters — a slower model would delay dispatch recommendations.

### 7.3 Feature Combination for Stage 2
The 14 structural features and the 384-dimensional SBERT embedding are concatenated into a single numpy array:

```python
embedding = alert_sbert.encode([cleaned_comment])   # shape: (1, 384)
X_prio    = np.hstack([X_struct.values, embedding]) # shape: (1, 398)
```

This 398-feature vector is what the LightGBM classifier receives.

### 7.4 Known Limitation of SBERT on Informal Text
`all-MiniLM-L6-v2` was pre-trained on formal English corpora (Wikipedia, Reddit, news). Abbreviated messages like *"I m hurt help"* (note: space in "I m") map to a significantly different vector space than *"I am severely injured"*, even though they express identical urgency. This is not a flaw that can be fixed by retraining the embedding model — it is a fundamental limitation of the pre-trained weights.

This limitation is why Stage 3 (the VADER override) was added.

---

## 8. Stage 2 — Priority Scorer (LightGBM + SBERT)

The second model is a **LightGBM multi-class classifier** (`model_priority_lgbm.pkl`) that assigns a priority from 2 (LOW) to 5 (CRITICAL). Priority 1 (FALSE) is never predicted here — that is handled entirely by Stage 1.

### 8.1 Why LightGBM for This Stage?
LightGBM was chosen because it handles large feature vectors efficiently, supports class weighting natively through `class_weight='balanced'`, and produces probability outputs via `predict_proba` for the confidence score. It also supports early stopping on a held-out validation set, which prevents the model from memorising rare training examples.

### 8.2 Trained Hyperparameters
| Parameter | Value | Effect |
|-----------|-------|--------|
| `n_estimators` | 400 | 400 decision trees, with early stopping active |
| `max_depth` | 7 | Moderate complexity |
| `learning_rate` | 0.05 | Small, careful steps |
| `num_leaves` | 63 | Controls tree complexity — 63 leaf nodes |
| `class_weight` | balanced | Prevents the model from ignoring rare priorities |
| `subsample` | 0.8 | Each tree uses 80% of training rows — reduces overfitting |
| `colsample_bytree` | 0.8 | Each tree uses 80% of features |

### 8.3 Class Balancing
The training set naturally has far more MEDIUM (3) alerts than CRITICAL (5) alerts. Without correction, the model would rarely predict CRITICAL. Two complementary strategies are used:

1. `class_weight='balanced'` in the classifier — LightGBM internally upweights rare classes during training.
2. `sample_weight` computed per training sample using `sklearn.utils.class_weight.compute_class_weight` — passed to `model.fit()` so each rare-class sample contributes more to the loss.

### 8.4 Training vs. Test Split
The dataset was split 80% training / 20% test with `stratify=priority_score` to ensure each priority level is proportionally represented in both splits.

### 8.5 Confidence Score
The confidence returned to the Node.js backend is `max(predict_proba(X_prio)[0])` — the maximum class probability across all five priority levels. A confidence of 0.95 means the model strongly favours one priority class. A confidence of 0.45 means two classes were nearly tied.

---

## 9. Stage 3 — VADER Urgency Override (Addition v1.1)

This stage is a **post-processing layer** added to `app.py` after the LightGBM + SBERT pipeline. It does not modify, retrain, or reload any pickle file.

### 9.1 Why This Stage Exists

Stage 2 (LightGBM + SBERT) has a known and documented failure mode on informal distress language:

> *"ML Model 3 rates informal distress language (e.g. 'I m hurt') as LOW"*
> — BUSGO Project Overview, Known Issues

The root cause is the `urgency_score` feature. A passenger typing *"I m hurt. help"* triggers **zero** CRITICAL_KW matches and **zero** HIGH_KW matches:

```
urgency_score = (0 × 2) + 0 − 0 − 0 = 0
```

With `urgency_score = 0` and `base_priority = 4` (Medical Emergency), LightGBM lacks sufficient signal to distinguish this from a neutral alert, and predicts LOW or MEDIUM. SBERT's semantic understanding is also weakened by the abbreviated spelling *"I m"* vs. *"I am"*.

VADER, however, reads the emotional tone of the sentence — including punctuation, capitalisation, and words like *"hurt"* and *"help"* — and returns a strongly negative compound score, independent of whether the keywords match a curated list.

### 9.2 VADER's Role in Model 3 (Different From Model 1)

It is important to understand that VADER is used **differently** in Model 1 and Model 3:

| | Model 1 (Rating) | Model 3 (Alert Priority) |
|---|---|---|
| **What VADER does** | Acts as an independent scorer alongside LightGBM, blended in a weighted ensemble | Acts as a post-processing override that only activates when LightGBM scores LOW or MEDIUM |
| **When VADER runs** | Every rating prediction, always | Every alert prediction, but only modifies the result under specific conditions |
| **Cultural calibration** | Yes — Sri Lankan informal positive/negative signals are applied as an offset | No — urgency override uses informal distress signals instead |
| **Blend weight** | 70% LightGBM / 30% VADER (agreement) or 50/50 (disagreement) | VADER does not blend — it either overrides or does nothing |
| **Downgrade possible** | No — cultural calibration can go negative, but is bounded | No — the override only increases priority, never decreases |

### 9.3 Informal Distress Signal List
A curated list of 30 patterns is checked against the raw comment (not the cleaned version, to preserve emotional punctuation):

| Category | Examples |
|----------|---------|
| Abbreviated distress | `"i m hurt"`, `"pls help"`, `"cant breathe"`, `"need help now"` |
| Sri Lankan informal | `"aiya help"`, `"aney aney"`, `"help karanna"` |
| Physiological distress | `"passed out"`, `"blacking out"`, `"lot of blood"`, `"going to faint"` |
| Injury/pain | `"in pain"`, `"badly hurt"`, `"so much pain"`, `"really hurts"` |
| Informal threat signals | `"has a knife"`, `"has a gun"`, `"people running"` |

### 9.4 Override Logic
The VADER compound score ranges from -1.0 (maximally negative) to +1.0 (maximally positive). Two threshold levels determine the boost:

| VADER compound | Informal signal present | Action |
|---------------|------------------------|--------|
| ≤ −0.50 | Yes | Boost priority by **+2** (e.g. LOW → HIGH, MEDIUM → CRITICAL) |
| ≤ −0.25 | Yes | Boost priority by **+1** (e.g. LOW → MEDIUM, MEDIUM → HIGH) |
| Any other | Any | No override — Model 3 result unchanged |
| Any | No | No override — informal signal required |
| Already ≥ 4 | Any | No override — HIGH/CRITICAL already correctly scored |

The override **never downgrades** a result. If Model 3 scored HIGH (4) or CRITICAL (5), the function returns immediately without checking VADER.

### 9.5 Why the Raw Comment Is Used
The VADER override runs on `comment` (the original raw string), not `cleaned` (the processed string). This is intentional — VADER's scoring is sensitive to uppercase letters, exclamation marks, and the word *"HELP"* written in capitals. The cleaning function strips these signals, which would reduce VADER's ability to detect urgency in short emotional messages.

---

## 10. Output Format

Each prediction returns a JSON dictionary with 8 fields:

```json
{
    "priority":        4,
    "priority_label":  "HIGH",
    "action":          "Urgent — Contact nearest unit",
    "is_false_alert":  false,
    "false_prob":      0.031,
    "confidence":      0.812,
    "cleaned_comment": "man groping female passengers repeatedly not stop",
    "vader_override":  false,
    "vader_compound":  -0.643
}
```

| Field | Type | Description |
|-------|------|-------------|
| `priority` | int (1–5) | Final priority after all three stages |
| `priority_label` | string | Human label: FALSE / LOW / MEDIUM / HIGH / CRITICAL |
| `action` | string | Dispatcher instruction for this priority level |
| `is_false_alert` | bool | True if Stage 1 detected this as an accidental alert |
| `false_prob` | float | XGBoost's probability estimate that alert is false (0–1) |
| `confidence` | float | LightGBM's confidence in priority prediction (0–1) |
| `cleaned_comment` | string | The preprocessed text that was fed into Stage 2 |
| `vader_override` | bool | True if Stage 3 modified the priority |
| `vader_compound` | float | VADER compound score from Stage 3 (null if priority ≥ 4) |

---

## 11. Priority Scale Reference

| Score | Label | Colour | Dispatcher Action |
|-------|-------|--------|------------------|
| 5 | CRITICAL | 🔴 | Dispatch immediately — call 119/118 |
| 4 | HIGH | 🟠 | Urgent response required |
| 3 | MEDIUM | 🟡 | Monitor and prepare response |
| 2 | LOW | 🟢 | Log and schedule follow-up |
| 1 | FALSE | ⚪ | Likely false alert — flag for review, no dispatch |

---

## 12. Deployment in BUSGO

Model 3 is served by the same **Flask REST API** on port 8000 that serves Models 1 and 2.

When a passenger submits an emergency alert through the BUSGO client app:

1. The alert type and comment are sent to the Node.js backend
2. Node.js forwards the payload to the Python ML service at `/ml/alert-priority`
3. The Flask service runs the 3-stage pipeline and returns the priority JSON
4. Node.js stores the alert with its priority in the Supabase `emergency_alerts` table
5. The admin panel displays the incoming alert queue sorted by priority (CRITICAL first)
6. If `bus_id` is attached (via an active QR scan-in trip), it is auto-appended to the alert

The SBERT model (`all-MiniLM-L6-v2`) is loaded **once at startup** using `load_all_models()` and cached globally. It is not downloaded per request. The first startup takes approximately 30 seconds while the model weights are fetched from Hugging Face. All subsequent calls use the cached in-memory model.

---

## 13. Key Design Decisions and Trade-offs

**Why XGBoost for false alert detection and LightGBM for priority scoring?**
XGBoost was chosen for Stage 1 because false alert detection is a binary classification problem where the minority class (false alerts) must be heavily penalised. XGBoost's `scale_pos_weight` parameter handles this directly. LightGBM was chosen for Stage 2 because it handles the larger multi-class problem (5 priority levels) more efficiently with its `class_weight='balanced'` option and built-in early stopping.

**Why TF-IDF for Stage 1 and SBERT for Stage 2?**
False alert detection benefits from exact phrase matching — phrases like *"wrong button"* and *"nothing happened"* are reliable indicators regardless of context. TF-IDF's bigram vocabulary captures these patterns precisely. Priority scoring, however, requires understanding the full semantic meaning of a distress message — this is where SBERT's contextual embeddings are superior to frequency-based matching.

**Why not retrain Model 3 to handle informal distress?**
Retraining would require changing the Colab notebook, regenerating the pkl files, and redistributing them. The VADER override achieves the same correction as a post-processing layer in `app.py`, which is a faster, lower-risk fix that does not invalidate existing pkl files.

**Why does the VADER override require BOTH a negative compound AND an informal signal?**
Using VADER compound alone would cause false upgrades on genuinely LOW alerts (a lost umbrella described dramatically) or MEDIUM alerts (a missed stop). The informal distress signal acts as a gating condition — it only activates when the language pattern matches the specific abbreviated or informal style that the keyword scanner misses.

**Why is priority 1 never output by Stage 2?**
Priority 1 (FALSE) is the exclusive output of Stage 1's XGBoost model. The LightGBM in Stage 2 was trained only on real alerts (where `is_false_alert = False`), so it has never seen false alert patterns and would not correctly classify them. Separating these responsibilities makes each model better at its specific task.

---

## 14. Summary

| Property | Value |
|----------|-------|
| Task type | Two-stage classification (binary + 4-class) |
| Stage 1 algorithm | XGBoost binary classifier |
| Stage 2 algorithm | LightGBM multi-class classifier |
| Stage 3 (addition) | VADER post-processing urgency override |
| Text features (Stage 1) | TF-IDF, 800 features, bigrams |
| Semantic features (Stage 2) | SBERT all-MiniLM-L6-v2, 384 dimensions |
| Structural features | 14 engineered features (both stages) |
| Total input features (Stage 2) | 398 per prediction |
| Training data | ~50,000 real 911 records + 82 Sri Lankan synthetic samples |
| Emergency categories | Medical Emergency, Criminal Activity, Bus Breakdown, Harassment, Other |
| Priority scale | 1 (FALSE) to 5 (CRITICAL) |
| Post-processing | VADER urgency override for informal/abbreviated distress language |
| Output | Priority (1–5), label, action, confidence, false probability, VADER override flag |
| Deployment | Flask REST API, port 8000, endpoint `/ml/alert-priority` |
| Model files | 4 .pkl files + 1 Hugging Face model (downloaded at startup) |
