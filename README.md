# MATLAB Blood Pressure Prediction

## Project Overview

This project implements a non-intrusive blood pressure prediction system using Pulse Transit Time (PTT) derived from ECG and PPG signals. The work follows the 5 target objectives outlined in the assignment specification.

---

## Target 1: Data Washing

**File:** [`target_1_data_washing.m`](./matlab/target_1_data_washing.m)

### Purpose

Read ECG, PPG, and blood pressure data from the 11-subject dataset and preprocess to a workable level.

### Implementation Details

- Reads Excel files from `data/Non Intrusive BP Dataset/` directory
- Each subject folder contains ECG/PPG signals with associated BP measurements
- Parses multiple sheets per subject (different measurement sessions/positions)
- First row of each sheet contains SYS and DIA blood pressure readings
- Subsequent rows contain ECG and PPG signal values

### Key Functions

- `get_subject_files()` - Discovers all subject Excel files
- `parse_sheet()` - Extracts data from individual sheets
- `read_subject_data()` - Combines all sheets for a subject
- `detect_signal_units()` - Identifies mV vs ADC signal units
- `clean_data()` - Removes invalid entries and standardizes format

### Output

- **File:** `output/cleaned_bp_data.csv`
- **Columns:** date, time, ecg, ppg, sys, dia, pulse, sheet, subject_id, ecg_unit, ppg_unit
- **Records:** Data from 11 subjects with multiple measurement sessions

---

## Target 2: Peak Detection

**File:** [`target_2_peak_detection.m`](./matlab/target_2_peak_detection.m)

### Purpose

Autonomously identify peak values and calculate the Pulse Transit Time (PTT) between ECG R-peaks and PPG systolic peaks.

### Implementation Details

- Sampling rate: 250 Hz
- PTT physiological range: 120-600 ms (30-150 samples)
- Heart rate bounds: 40-200 bpm (R-R interval: 300-1500 ms)

### Algorithm

1. **ECG R-Peak Detection** (Pan-Tompkins inspired):
   - Bandpass filter (0.5-40 Hz)
   - Differentiate and square
   - Moving window integration (80ms)
   - Adaptive threshold with fallback strategies
   - Refine to actual R-peak location

2. **PPG Peak Detection**:
   - Lowpass filter at 8 Hz
   - Handle inverted signals via skewness check
   - Derivative-based zero-crossing detection
   - Search window: 80ms to 600ms after R-peak

3. **PTT Validation**:
   - Physiological bounds check (120-500ms)
   - IQR-based outlier removal
   - R-R interval validation

### Output

- **File:** `output/ptt_individual.csv`
- **Columns:** subject_id, sheet, beat_index, ecg_peak_idx, ppg_peak_idx, ptt_samples, ptt_ms, heart_rate_bpm, sys_bp, dia_bp, quality

---

## Target 3: Predictive Model

**File:** [`target_3_predictive_model.m`](./matlab/target_3_predictive_model.m)

### Purpose

Develop a predictive model for blood pressure estimation based on PTT features.

### Theoretical Basis

The model leverages the inverse relationship between blood pressure and PTT:

```
Higher BP → Stiffer arteries → Faster pulse wave → Shorter PTT
```

Based on the Moens-Korteweg equation:

```
PWV = sqrt(E * h / (2 * ρ * r))
```

### Approach: Calibration-Based Prediction

Due to individual variation in arterial properties:

1. First measurement per subject used as calibration (baseline BP and PTT)
2. Model predicts BP **changes** relative to calibration
3. Final prediction = calibration_BP + model_prediction(delta_features)

### Features Used

| Feature | Description |
|---------|-------------|
| `delta_ptt` | Change in median PTT from calibration |
| `delta_hr` | Change in heart rate from calibration |
| `ptt_iqr` | Interquartile range of PTT (variability) |
| `cv_ptt` | Coefficient of variation of PTT |

### Model Training

- Ridge regression with L2 regularization
- Cross-validated lambda selection (0.001 to 100)
- Leave-One-Subject-Out (LOSO) cross-validation

### Output Files

- **`output/model_predictions.csv`** - Individual predictions with actual/predicted values
- **`output/model_metrics.csv`** - Overall model performance metrics
- **`output/fold_metrics.csv`** - Per-subject cross-validation results

### Cross-Validation Results

| Metric | Systolic BP | Diastolic BP |
|--------|-------------|--------------|
| R² | -0.0503 | -0.0247 |
| RMSE | 14.66 mmHg | 9.15 mmHg |
| MAE | 10.77 mmHg | 6.58 mmHg |
| N Samples | 201 | 201 |

### Per-Subject Performance

| Subject | SYS RMSE | SYS MAE | DIA RMSE | DIA MAE |
|---------|----------|---------|----------|---------|
| S6 | 10.49 | 9.45 | 5.71 | 4.95 |
| S7 | 13.26 | 10.20 | 7.31 | 6.29 |
| S8 | 9.62 | 6.13 | 7.81 | 5.11 |
| S9 | 7.62 | 5.67 | 9.99 | 6.82 |
| S10 | 18.85 | 12.97 | 10.50 | 7.44 |
| S11 | 19.42 | 14.41 | 11.40 | 8.69 |
| S12 | 18.46 | 13.02 | 6.54 | 5.45 |
| S16 | 18.34 | 15.51 | 8.26 | 6.49 |
| S17 | 11.86 | 10.09 | 12.67 | 8.57 |
| S19 | 13.13 | 10.59 | 8.16 | 5.42 |
| S20 | 16.23 | 11.34 | 9.27 | 6.96 |

---

## Target 4: Validation

**File:** [`target_4_validation.m`](./matlab/target_4_validation.m)

### Purpose

Test and validate the predictive model using clinical standards and statistical analysis.

### Validation Components

#### 1. Error Distribution Analysis

- Mean error (bias)
- Standard deviation
- Median, MAE, RMSE
- Skewness and kurtosis
- Normality assessment

#### 2. Correlation Analysis

- Pearson correlation coefficient
- Spearman rank correlation
- R-squared (coefficient of determination)
- Lin's Concordance Correlation Coefficient (CCC)

#### 3. Bland-Altman Analysis

- Method comparison analysis
- Bias calculation (mean difference)
- Limits of Agreement (LoA = mean ± 1.96 × SD)
- Proportional bias detection

#### 4. Clinical Standards Evaluation

**AAMI Standard:**

- Mean Error: ≤ ±5 mmHg
- Standard Deviation: ≤ 8 mmHg

**BHS Grading:**

| Grade | ≤5 mmHg | ≤10 mmHg | ≤15 mmHg |
|-------|---------|----------|----------|
| A | ≥60% | ≥85% | ≥95% |
| B | ≥50% | ≥75% | ≥90% |
| C | ≥40% | ≥65% | ≥85% |
| D | Below C | Below C | Below C |

#### 5. Per-Subject Analysis

- Individual subject performance metrics
- Identifies best/worst performing subjects
- Subject variability assessment

#### 6. Residual Analysis

- Heteroscedasticity testing
- Durbin-Watson autocorrelation test

### Output Files

- `output/validation_metrics.csv`
- `output/bhs_assessment.csv`
- `output/validation_report.txt`
- `output/bland_altman_plots.png`
- `output/correlation_plots.png`
- `output/error_distribution.png`

---

## Target 5: Demonstration

**File:** [`target_5_demonstration.m`](./matlab/target_5_demonstration.m)

### Purpose

Demonstrate the model's ability to predict blood pressure for a subject outside the training data.

### Approach

Uses Leave-One-Subject-Out methodology to simulate a genuinely new subject:

1. Select one subject as "external/new" subject
2. Train model on remaining 10 subjects
3. Apply complete prediction pipeline to new subject
4. Compare predictions with actual values

### Demonstration Steps

1. Load all data (cleaned BP data + PTT measurements)
2. Select external subject (S8 used in demo)
3. Train model excluding demo subject
4. Process demo subject's signals
5. Generate calibration from first measurement
6. Predict BP for subsequent measurements
7. Calculate performance metrics
8. Generate visualization figures

### Output Files

- `output/external_demo_results.csv`
- `output/demo_signal_peaks.png`
- `output/demo_ptt_distribution.png`
- `output/demo_prediction_comparison.png`
- `output/final_report.md`

---

## Additional: Prediction Function

**File:** [`predict_new_subject.m`](./matlab/predict_new_subject.m)

### Purpose

Standalone function for predicting BP from new ECG/PPG signals.

### Usage

```matlab
% Basic usage
[pred_sys, pred_dia] = predict_new_subject(ecg, ppg, calib_sys, calib_dia);

% With options
[pred_sys, pred_dia, details] = predict_new_subject(ecg, ppg, 120, 80, ...
    'SamplingRate', 250, ...
    'CalibPTT', 100, ...
    'CalibHR', 75, ...
    'Verbose', true);

% From files
[sys, dia] = predict_bp_from_file('ecg.mat', 'ppg.mat', 120, 80);
```

### Features

- Self-contained peak detection algorithms
- Configurable sampling rate
- Optional calibration PTT/HR values
- Verbose mode for debugging
- File loading convenience wrapper

---

## Summary of Results

### Key Findings

1. **PTT-BP Relationship Confirmed**: The expected negative correlation between PTT and BP is observed in the data, though correlation strength varies by subject.

2. **Calibration Approach Essential**: Without subject-specific calibration, inter-individual variation in arterial properties makes absolute BP prediction challenging.

3. **Diastolic Better Than Systolic**: Diastolic BP predictions show lower RMSE (9.15 vs 14.66 mmHg), likely because diastolic BP primarily reflects arterial resistance while systolic is more influenced by cardiac output variability.

4. **Individual Variation**: Performance varies significantly across subjects:
   - Best: S9 (SYS MAE: 5.67 mmHg, DIA MAE: 6.82 mmHg)
   - Worst: S16 (SYS MAE: 15.51 mmHg, DIA MAE: 6.49 mmHg)

### Limitations

1. Limited dataset (11 subjects)
2. Mixed signal units (mV vs ADC) across subjects
3. No longitudinal data for within-subject changes
4. Postural effects not specifically modeled

# Matlab Setup

```bash
-----------------------------------------------------------------------------------------
MATLAB Version: 25.2.0.3123386 (R2025b) Update 3
MATLAB License Number: 41016256
Operating System: macOS  Version: 26.1 Build: 25B78 
Java Version: Java 11.0.30+7-LTS with Amazon.com Inc. OpenJDK 64-Bit Server VM mixed mode
-----------------------------------------------------------------------------------------
MATLAB                                                Version 25.2        (R2025b)
Econometrics Toolbox                                  Version 25.2        (R2025b)
Optimization Toolbox                                  Version 25.2        (R2025b)
Signal Processing Toolbox                             Version 25.2        (R2025b)
Statistics and Machine Learning Toolbox               Version 25.2        (R2025b)
```
