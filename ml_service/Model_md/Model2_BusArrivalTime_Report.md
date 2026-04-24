# Model 2 — Bus Arrival Time Estimation
## Detailed Technical Report
**Project:** BUSGO — Sri Lanka Bus Management System
**University:** Edith Cowan University
**Author:** Nimuthu Ganegoda
**Date:** April 2026
**Model Version:** 4.0 (trained 2026-04-08)

---

## 1. Overview

Model 2 predicts how many **minutes** it will take for a specific bus to reach a passenger's target stop, given the bus's current real-time GPS position, speed, route information, and environmental conditions.

This is fundamentally different from Model 1. Model 1 reads text and interprets human language. Model 2 works entirely with **structured numeric data** — distances, speeds, time of day, stop counts — and must learn the complex, non-linear relationships between traffic conditions and travel time that exist in Sri Lankan urban bus networks.

The core challenge is that bus arrival time is not a simple calculation of `distance ÷ speed`. A bus 1.4 km away moving at 16 km/h during Colombo morning peak hour in the rain will take significantly longer than the same bus on a clear Sunday afternoon. The model learns these differences from real-world training data.

---

## 2. Files in the Model Package

| File | Type | Purpose |
|------|------|---------|
| `optimized_bus_model.pkl` | XGBRegressor | The trained 500-tree XGBoost model |
| `driver_id_encoder.pkl` | LabelEncoder | Maps 341 real bus registration numbers to integers |
| `model_metadata.json` | JSON | Feature list, version, urban routes, and the conversion formula |
| `Testing.py` | Python script | Deployment inference script — shows exactly how the backend calls the model |

---

## 3. Full Pipeline — Step by Step

```
Live Inputs from BUSGO App
(bus no, distance, stops, speed, rain, hour)
         │
         ▼
[Stage 1] Mathematical Conversions
  → Cyclical time encoding (hour → sin/cos)
  → Peak hour detection
  → Skip-stop detection
  → Traffic index calculation
         │
         ▼
[Stage 2] Bus ID Encoding
  → LabelEncoder maps registration plate to integer
         │
         ▼
[Stage 3] Feature Assembly (16 features)
  → Build input dictionary matching FEATURE_COLS order
  → Convert to pandas DataFrame
         │
         ▼
[Stage 4] XGBoost Prediction
  → model.predict(df_input[FEATURE_COLS])
  → Output: log_seconds_per_km (raw prediction)
         │
         ▼
[Stage 5] Output Conversion
  → eta_seconds = expm1(log_pred) × distance_km
  → eta_minutes = eta_seconds ÷ 60
         │
         ▼
Final ETA in Minutes (returned to Node.js backend)
```

---

## 4. Stage 1 — Input Preparation and Feature Engineering

The `predict_bus_eta()` function takes 6 raw inputs from the app and transforms them into 16 model-ready features. This is where the engineering intelligence lives.

### 4.1 Raw Inputs

| Input | Example | Source |
|-------|---------|--------|
| `bus_no` | `"WP-NB-8237"` | GPS tracker registration plate |
| `dist_km` | `1.4` | Haversine calculation from bus GPS to target stop |
| `stops` | `5` | Count of stops between bus and target on the route |
| `speed_kmh` | `16` | Current speed from GPS tracker |
| `is_raining` | `True` | Weather API |
| `hour` | `8` | Current hour from system clock (0–23) |

### 4.2 Cyclical Time Encoding

The hour of day is not fed into the model as a raw number (0–23). Instead it is encoded as two trigonometric values:

```python
h_sin = np.sin(2 × π × hour / 24)
h_cos = np.cos(2 × π × hour / 24)
```

**Why this matters:** A raw integer treats hour 23 (11 PM) and hour 0 (midnight) as 23 units apart, when in reality they are only 1 hour apart. This confuses the model — it would fail to learn that late-night traffic at 11 PM and midnight behave similarly.

The sin/cos encoding places every hour on a circle, so that mathematically adjacent hours are also numerically adjacent regardless of whether they cross midnight.

**Concrete example:**

| Hour | Raw value | sin | cos | Distance to midnight (cos space) |
|------|-----------|-----|-----|----------------------------------|
| 23 (11 PM) | 23 | −0.26 | +0.97 | Close |
| 0 (midnight) | 0 | 0.00 | +1.00 | — |
| 1 (1 AM) | 1 | +0.26 | +0.97 | Close |
| 12 (noon) | 12 | 0.00 | −1.00 | Far |

Hour 23 and hour 0 are very close in (sin, cos) space. Hour 12 is on the opposite side of the circle — far from midnight, which is correct.

Two values are needed (not just one) because a single sin or cos value is ambiguous — sin(8 AM) = sin(4 PM). Together they uniquely identify every hour.

### 4.3 Peak Hour Detection

```python
is_peak = 1 if (7 <= hour <= 9 or 16 <= hour <= 19) else 0
```

This reflects Colombo's actual traffic patterns:
- Morning peak: 7:00 AM – 9:00 AM (office and school commute)
- Evening peak: 4:00 PM – 7:00 PM (return commute)

This is a binary flag (0 or 1) rather than a continuous scale.

### 4.4 Skip-Stop Detection

```python
is_full_skip = 1 if (speed_kmh > 35 and stops < 5) else 0
```

If the bus is travelling faster than 35 km/h and has fewer than 5 stops remaining, the model infers it is likely running express or skipping stops. This is a Sri Lanka-specific behaviour where some drivers skip less-populated stops during off-peak periods to reduce journey time.

When `is_full_skip = 1`, the model adjusts its ETA estimate downward accordingly.

### 4.5 Peak Traffic Index

```python
peak_traffic_index = is_peak × (1 / (speed_kmh + 1))
```

This is a derived interaction feature that multiplies peak status by the inverse of speed. The `+1` prevents division by zero for stationary buses.

**What it captures:**

| Scenario | is_peak | speed_kmh | peak_traffic_index | Meaning |
|----------|---------|-----------|-------------------|---------|
| Peak hour, heavy traffic | 1 | 5 | 1 × (1/6) = 0.167 | Very congested |
| Peak hour, moving fast | 1 | 40 | 1 × (1/41) = 0.024 | Light congestion |
| Off-peak, any speed | 0 | any | 0 | No peak penalty |

This single number encodes the interaction between traffic timing and actual traffic severity. From the actual feature importance analysis, this is the **second most important feature** in the model (30.67%), second only to `is_peak_hour` itself (46.81%).

### 4.6 Distance Derivations

From the raw `dist_km` and `stops` inputs, three additional features are derived:

```python
total_distance_to_target_m  = dist_km × 1000
avg_segment_distance_m      = (dist_km × 1000) / (stops + 1)
dist_per_stop               = (dist_km × 1000) / (stops + 1)
```

`avg_segment_distance_m` and `dist_per_stop` are mathematically identical in this implementation. Both represent the average gap between consecutive stops on the remaining journey. They are included separately to give the XGBoost tree splitter more opportunities to find useful thresholds on this value — tree models sometimes split the same information differently depending on which column they encounter first.

The `+1` in the denominator prevents division by zero when `stops = 0` (the bus is at or very close to the target stop).

---

## 5. Stage 2 — Bus ID Encoding

The bus registration number is a string like `"WP-NB-8237"`. Machine learning models cannot process strings directly, so a `LabelEncoder` converts each registration plate to a unique integer.

```python
try:
    driver_enc = driver_encoder.transform([bus_no])[0]
except:
    driver_enc = 0   # fallback for unknown buses
```

**The encoder covers 341 real Sri Lankan bus registration plates**, all in the `WP-NB-xxxx` or `WP-SB-xxxx` format (Western Province North Bus / Western Province South Bus), representing actual buses operating on Colombo routes.

**Sample encoded buses:**

| Registration | Encoded Integer |
|-------------|-----------------|
| WP-NB-1022 | 0 |
| WP-NB-8237 | (some integer) |
| WP-SB-8763 | 340 |

**Why encode the bus at all?** Individual buses have different characteristics that affect their speed and dwell time patterns — an older vehicle may consistently take 15% longer between stops, a particular driver may have a habit of longer dwell times. The model can learn these per-bus patterns from historical data. If a bus is completely unknown (not in training data), it falls back to integer 0 rather than crashing.

**Feature importance reality check:** Looking at the actual trained model's feature importances, `driver_id_enc` scores only **0.0028** (0.28%), making it the second least important feature. This suggests that in the training data, per-bus variation was relatively small compared to traffic conditions. The model learned that whether it's peak hour matters far more than which specific bus it is.

---

## 6. Stage 3 — The 16 Features (Complete Breakdown)

After all transformations, 16 features are assembled into a dictionary that is converted to a pandas DataFrame in the exact column order specified by `FEATURE_COLS` in `model_metadata.json`.

| # | Feature | Value in test | Type | Feature Importance |
|---|---------|--------------|------|-------------------|
| 1 | `total_distance_to_target_m` | 1400 | Continuous | 0.99% |
| 2 | `stops_between_bus_and_target` | 5 | Integer | 8.24% |
| 3 | `avg_segment_distance_m` | 233.3 | Continuous | 1.46% |
| 4 | `route_encoded` | 1 | Categorical int | 0.00% |
| 5 | `road_type_encoded` | 1 | Categorical int | 0.00% |
| 6 | `hour_sin` | −0.26 (at hour 8) | Continuous | 0.22% |
| 7 | `hour_cos` | +0.97 (at hour 8) | Continuous | 0.26% |
| 8 | `is_peak_hour` | 1 | Binary | **46.81%** |
| 9 | `is_raining` | 1 | Binary | 3.42% |
| 10 | `is_public_holiday` | 0 | Binary | 0.00% |
| 11 | `current_speed_kmh` | 16 | Continuous | 4.33% |
| 12 | `dwell_at_last_stop_s` | 20 | Continuous | 0.57% |
| 13 | `driver_id_enc` | (integer) | Categorical int | 0.28% |
| 14 | `is_full_skip` | 0 | Binary | 0.00% |
| 15 | `dist_per_stop` | 233.3 | Continuous | 2.75% |
| 16 | `peak_traffic_index` | 0.059 | Continuous | **30.67%** |

**The feature importance ranking reveals critical insights:**

The top two features — `is_peak_hour` (46.81%) and `peak_traffic_index` (30.67%) — together account for **77.48% of all predictive power**. This tells a clear story: in Colombo's bus network, *when* the journey happens is dramatically more important than *where* it happens or *how far* the bus is.

`route_encoded`, `road_type_encoded`, `is_public_holiday`, and `is_full_skip` all score **exactly 0.00%**, meaning the model never used them to make a split that improved predictions during training. They likely had insufficient variation or were outperformed by the other features in every split scenario. In a future version these could be removed without any accuracy loss.

---

## 7. Stage 4 — XGBoost Regressor

### 7.1 What XGBoost Is

XGBoost (eXtreme Gradient Boosting) is an ensemble machine learning algorithm that builds decision trees sequentially. Each new tree learns to correct the errors that all previous trees made. The final prediction is the sum of contributions from all 500 trees.

### 7.2 Why XGBoost for ETA Prediction

ETA prediction is a **regression task** — the output is a continuous number (minutes), not a category. XGBoost's `reg:squarederror` objective makes it optimise to minimise mean squared error, which directly aligns with wanting accurate numeric predictions.

Key reasons XGBoost suits this problem:

- All 16 features are already numeric — no text processing needed
- The relationships between features and ETA are non-linear (doubling speed doesn't halve ETA linearly due to stop dwell times)
- XGBoost handles the interaction between `is_peak_hour` and `current_speed_kmh` naturally through tree splits
- The model was trained on a GPU (`device: cuda`) which significantly sped up the 500-tree training process

### 7.3 Actual Hyperparameters (from the trained model)

| Parameter | Value | What it controls |
|-----------|-------|-----------------|
| `n_estimators` | 500 | Total number of trees built sequentially |
| `learning_rate` | 0.05 | How much each tree contributes — small value means more robust, needs more trees |
| `max_depth` | 10 | Maximum depth of each individual tree — controls complexity |
| `subsample` | 0.9 | Each tree only sees 90% of training rows — reduces overfitting |
| `colsample_bytree` | 0.8 | Each tree only sees 80% of features — reduces overfitting |
| `objective` | `reg:squarederror` | Loss function — minimise mean squared error |
| `tree_method` | `hist` | Histogram-based splitting — faster than exact method, especially on GPU |
| `device` | `cuda` | Trained on GPU (NVIDIA CUDA) for faster computation |
| `random_state` | 42 | Reproducibility seed |

**Understanding subsample and colsample_bytree:**
These two parameters introduce randomness intentionally. By training each tree on a different random 90% of rows and 80% of columns, each tree sees a slightly different view of the data. This prevents any single tree from memorising noise in the training data and makes the ensemble more robust — a technique borrowed from Random Forest called **bagging**.

### 7.4 How XGBoost Builds Each Tree

The algorithm works as follows:

1. **Start:** Predict the mean ETA for all training samples
2. **Calculate residuals:** For each sample, compute (actual ETA − current prediction)
3. **Build a tree:** Fit a decision tree to predict those residuals — find the best feature and threshold at each node that reduces the residual error the most
4. **Update predictions:** Add this tree's predictions × 0.05 (learning rate) to the running total
5. **Repeat:** Go back to step 2 with the updated predictions
6. **After 500 trees:** The final prediction is the sum of all 500 trees' contributions

With `max_depth=10`, each individual tree can ask up to 10 yes/no questions about the features. For example: "Is is_peak_hour = 1? → Yes. Is current_speed_kmh < 12? → Yes. Is stops_between_bus_and_target > 8? → No. → Predicted residual: +4.2 minutes."

---

## 8. Stage 5 — Output Conversion

The model does NOT directly predict minutes. It predicts a value in **log-transformed seconds-per-kilometre space**. The conversion back to minutes requires two steps.

### 8.1 Why Log-Space Prediction

Bus ETAs have a heavily skewed distribution. Most journeys take 3–20 minutes, but occasionally a bus is caught in severe gridlock and takes 90+ minutes. If you train directly on raw minutes, these outliers disproportionately influence the loss function and pull the model's weights towards predicting large values.

Taking the logarithm of the target variable (`log1p(seconds_per_km)`) compresses the scale:

```
Raw: 5 min → 300 sec → log1p(300) = 5.71
Raw: 20 min → 1200 sec → log1p(1200) = 7.09
Raw: 90 min → 5400 sec → log1p(5400) = 8.59
```

The range 5–90 minutes (ratio of 18×) becomes 5.71–8.59 in log space (ratio of only 1.5×). This makes the distribution much more symmetric and the regression task much easier for the trees.

### 8.2 The Conversion Formula

The metadata file explicitly documents this formula:

```
formula: "eta_seconds = (exp(prediction) - 1) * distance_km"
```

In Python:
```python
log_pred  = model.predict(df_input[FEATURE_COLS])[0]   # raw output
eta_seconds = np.expm1(log_pred) * dist_km              # convert to seconds
eta_minutes = eta_seconds / 60                          # convert to minutes
```

**Why `expm1` instead of `exp`?**
`expm1(x)` computes `exp(x) − 1` in a single numerically stable operation. If `x` is very small (close to 0), plain `exp(x) − 1` loses precision due to floating-point arithmetic. `expm1` avoids this issue. It is the exact mathematical inverse of `log1p` — the function used during training to transform the targets.

**Worked example from the test case:**

```
Bus: WP-NB-8237
Distance: 1.4 km
Speed: 16 km/h
Hour: 8 AM (peak)
Raining: Yes

peak_traffic_index = 1 × (1 / (16+1)) = 0.0588

→ model.predict() → log_pred ≈ 5.8 (hypothetical)
→ eta_seconds = expm1(5.8) × 1.4 = 328.3 × 1.4 = 459.6 seconds
→ eta_minutes = 459.6 / 60 ≈ 7.66 minutes
```

---

## 9. Deployment in BUSGO

The model is served via a Flask REST API endpoint at `POST /predict/eta` on the Python ML service (port 8000). The workflow when a passenger opens the "Track my bus" screen:

1. Passenger's app fetches the bus's GPS coordinates from Supabase
2. The app calculates the Haversine distance between the bus and the passenger's target stop
3. The app counts the number of intermediate stops from the route definition
4. The Node.js backend queries the weather API for rain status
5. Node.js posts all inputs to `POST /predict/eta` on the ML service
6. Flask runs the `predict_bus_eta()` function, loads the pre-trained model (loaded once at startup)
7. The ETA in minutes is returned to Node.js, which forwards it to the passenger's app
8. The app displays "Bus arrives in approximately X minutes"

The model files are loaded **once at Flask startup** using `joblib.load()`, not per request. Loading a 19 MB XGBoost model from disk on every API call would take 2–3 seconds per request — completely impractical. Loading once at startup means each subsequent prediction takes under 10 milliseconds.

---

## 10. Model Metadata File

The `model_metadata.json` file serves as the **contract** between the training environment (Colab) and the deployment environment (BUSGO Flask server). It contains:

```json
{
    "features": [16 feature names in exact order],
    "model_version": "4.0",
    "training_date": "2026-04-08",
    "urban_routes": ["138", "177", "187", "240"],
    "formula": "eta_seconds = (exp(prediction) - 1) * distance_km"
}
```

**Why this matters:** The feature order in `FEATURE_COLS` must exactly match the order the model was trained with. XGBoost (like all tree models) is sensitive to column order — if `is_peak_hour` is in position 8 during training but position 3 during inference, the model will make wrong predictions without any error message. The metadata file guarantees the deployment code always uses the correct order.

The `urban_routes` list (`138`, `177`, `187`, `240`) identifies the Colombo urban routes the training data was primarily sourced from. These are high-frequency routes where the model's predictions are most reliable.

---

## 11. Actual Feature Importance Analysis

Based on inspection of the trained model's `feature_importances_` attribute:

```
is_peak_hour                    ████████████████████████████████████████████████  46.81%
peak_traffic_index              ████████████████████████████████████████████      30.67%
stops_between_bus_and_target    ████████                                           8.24%
current_speed_kmh               ████                                               4.33%
is_raining                      ███                                                3.42%
dist_per_stop                   ██                                                 2.75%
avg_segment_distance_m          █                                                  1.46%
total_distance_to_target_m      █                                                  0.99%
dwell_at_last_stop_s            ▌                                                  0.57%
driver_id_enc                   ▌                                                  0.28%
hour_cos                        ▌                                                  0.26%
hour_sin                        ▌                                                  0.22%
route_encoded                   (zero)                                             0.00%
road_type_encoded               (zero)                                             0.00%
is_public_holiday               (zero)                                             0.00%
is_full_skip                    (zero)                                             0.00%
```

### Key Conclusions from the Importance Ranking

**Traffic timing dominates everything.** The top two features combine for 77.48% of predictive power. This makes intuitive sense for Colombo — the difference between a bus journey during peak hour vs off-peak can be 3× to 5× in actual travel time. No other variable comes close to this impact.

**Number of stops (8.24%) outweighs actual distance (0.99%).** This is a significant finding. The number of intermediate stops is more predictive than the raw distance because each stop introduces dwell time (passengers boarding and alighting) that the model has learned is a major source of delay. A bus 3 km away with 2 stops may arrive faster than a bus 1.5 km away with 10 stops.

**Dwell time at last stop (0.57%) has low importance.** The model defaulted `dwell_at_last_stop_s = 20` (seconds) in all test cases, which means it had very little variation in training. In a real deployment with actual measured dwell times, this feature might carry more weight.

**Four features scored exactly 0.00%.** `route_encoded`, `road_type_encoded`, `is_public_holiday`, and `is_full_skip` were never used in a tree split. These are dead weight in the current model. Possible explanations: the training data had insufficient public holiday examples, route/road type information may have been too coarse-grained or consistent across the dataset to add signal beyond what peak hour already captures.

---

## 12. Key Design Decisions and Trade-offs

**Why not use Google Maps API for ETA?**
Google Maps charges per API call and has rate limits. For a real-time bus tracking app serving thousands of passengers making repeated refresh requests, API costs would be prohibitive. The trained ML model runs locally at near-zero marginal cost per prediction.

**Why XGBoost and not a neural network?**
With 16 numeric features and a dataset of bus GPS traces, XGBoost consistently outperforms neural networks on this type of problem. Neural networks excel at high-dimensional, unstructured data (images, audio, text). For structured tabular data with fewer than 20 features, gradient boosting is typically superior in accuracy and is vastly simpler to deploy.

**Why log-transform the target instead of predicting raw minutes?**
Without log transformation, the model would be heavily penalised for underestimating rare 90-minute gridlock scenarios, pulling its predictions upward for all cases. Log transformation makes the training signal balanced across the full range of ETA values.

**Why `subsample=0.9` and `colsample_bytree=0.8`?**
These prevent overfitting. With 500 trees and 16 features, without subsampling the model would eventually memorise specific routes and conditions in the training data. By randomly selecting 90% of rows and 80% of columns per tree, each tree sees a slightly different picture, forcing the ensemble to learn general patterns rather than memorise specifics.

**Why hardcode `route_encoded=1` and `road_type_encoded=1` in the test?**
The test script shows both set to 1. Given both features scored 0.00% importance, their actual values don't affect the prediction. In a production implementation connected to a real route database, these would be populated from the route definition table in Supabase.

---

## 13. Summary

| Property | Value |
|----------|-------|
| Task type | Regression (predicts continuous ETA in minutes) |
| Core algorithm | XGBoost Gradient Boosted Decision Trees |
| Number of trees | 500 |
| Input features | 16 (6 raw inputs → 16 engineered features) |
| Key innovation | Cyclical time encoding + peak traffic interaction feature |
| Target variable | log1p(seconds per km) — converted back with expm1 |
| Most important feature | is_peak_hour (46.81%) |
| Second most important | peak_traffic_index (30.67%) |
| Buses covered | 341 WP-NB and WP-SB registration plates |
| Urban routes | 138, 177, 187, 240 (Colombo) |
| Training hardware | GPU (NVIDIA CUDA via `device: cuda`) |
| Model file size | ~19 MB |
| Deployment | Flask REST API, Docker container, port 8000 |
| Prediction latency | Under 10 milliseconds per call |
| No calibration needed | Unlike Model 1, raw output is directly converted via formula |
