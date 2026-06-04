%% Target 3: Blood Pressure Predictive Model
%
% This script develops a predictive model for blood pressure estimation
% using Pulse Transit Time (PTT) features extracted from ECG and PPG signals.
%
% The model is based on the inverse relationship between blood pressure
% and PTT: Higher BP = faster pulse wave = shorter PTT.
%
% Approach: Calibration-Based Prediction
% - Each subject's first measurement is used as calibration
% - Model predicts BP CHANGES relative to calibration
% - Final prediction = calibration_BP + predicted_change
%
% Input: 
%     - output/ptt_individual.csv (individual PTT values from Target 2)
%
% Output: 
%     - output/model_predictions.csv (individual predictions)
%     - output/model_metrics.csv (evaluation metrics)
%     - output/fold_metrics.csv (per-fold cross-validation metrics)
%
% Author: Elena Cavazza
% Date: 2026

function [results_table, metrics_table] = target_3_predictive_model()
    %% Main entry point for the predictive model
    
    fprintf('============================================================\n');
    fprintf('Target 3: Blood Pressure Predictive Model\n');
    fprintf('============================================================\n\n');
    
    % ======================================================================
    % STEP 1: Load Individual PTT Data
    % ======================================================================
    fprintf('STEP 1: Loading Individual PTT Data\n');
    fprintf('----------------------------------------\n');
    
    individual_path = fullfile('..', 'output', 'ptt_individual.csv');
    if ~exist(individual_path, 'file')
        individual_path = fullfile('output', 'ptt_individual.csv');
    end
    
    ptt_data = load_individual_ptt(individual_path);
    fprintf('\n');
    
    % ======================================================================
    % STEP 2: Compute Segment Features
    % ======================================================================
    fprintf('STEP 2: Computing Segment Features\n');
    fprintf('----------------------------------------\n');
    
    segment_features = compute_segment_features(ptt_data);
    fprintf('\n');
    
    % ======================================================================
    % STEP 3: Verify PTT-BP Correlation
    % ======================================================================
    fprintf('STEP 3: Verifying PTT-BP Correlation\n');
    fprintf('----------------------------------------\n');
    
    verify_ptt_bp_correlation(segment_features);
    fprintf('\n');
    
    % ======================================================================
    % STEP 4: Prepare Calibration-Based Data
    % ======================================================================
    fprintf('STEP 4: Preparing Calibration-Based Data\n');
    fprintf('----------------------------------------\n');
    
    [calib_data, feature_names] = prepare_calibration_data(segment_features);
    fprintf('\n');
    
    % ======================================================================
    % STEP 5: Cross-Validate with LOSO
    % ======================================================================
    fprintf('STEP 5: Leave-One-Subject-Out Cross-Validation\n');
    fprintf('----------------------------------------\n');
    
    cv_results = cross_validate_loso(calib_data, feature_names);
    
    fprintf('\nOverall Cross-Validation Results:\n');
    fprintf('  Systolic BP:\n');
    fprintf('    R-squared:  %.4f\n', cv_results.sys_r2);
    fprintf('    RMSE:       %.2f mmHg\n', cv_results.sys_rmse);
    fprintf('    MAE:        %.2f mmHg\n', cv_results.sys_mae);
    fprintf('  Diastolic BP:\n');
    fprintf('    R-squared:  %.4f\n', cv_results.dia_r2);
    fprintf('    RMSE:       %.2f mmHg\n', cv_results.dia_rmse);
    fprintf('    MAE:        %.2f mmHg\n', cv_results.dia_mae);
    fprintf('\n');
    
    % ======================================================================
    % STEP 6: Train Final Models on All Data
    % ======================================================================
    fprintf('STEP 6: Training Final Models\n');
    fprintf('----------------------------------------\n');
    
    [sys_model, dia_model] = train_final_models(calib_data, feature_names);
    
    fprintf('Final Model Coefficients:\n');
    fprintf('  Systolic:  intercept=%.4f', sys_model.intercept);
    for i = 1:length(feature_names)
        fprintf(', %s=%.4f', feature_names{i}, sys_model.coefficients(i));
    end
    fprintf(' (lambda=%.3f)\n', sys_model.lambda);
    fprintf('  Diastolic: intercept=%.4f', dia_model.intercept);
    for i = 1:length(feature_names)
        fprintf(', %s=%.4f', feature_names{i}, dia_model.coefficients(i));
    end
    fprintf(' (lambda=%.3f)\n\n', dia_model.lambda);
    
    % Check if PTT coefficient has expected sign
    ptt_idx = find(strcmp(feature_names, 'delta_ptt'));
    if ~isempty(ptt_idx)
        ptt_coef_sys = sys_model.coefficients(ptt_idx);
        ptt_coef_dia = dia_model.coefficients(ptt_idx);
        
        fprintf('PTT-BP Relationship (delta_ptt coefficient):\n');
        fprintf('  Systolic:  %.4f', ptt_coef_sys);
        if ptt_coef_sys < 0
            fprintf(' ✓ (negative as expected)\n');
        else
            fprintf(' ✗ (positive - unexpected)\n');
        end
        fprintf('  Diastolic: %.4f', ptt_coef_dia);
        if ptt_coef_dia < 0
            fprintf(' ✓ (negative as expected)\n');
        else
            fprintf(' ✗ (positive - unexpected)\n');
        end
        fprintf('\n');
    else
        ptt_coef_sys = NaN;
        ptt_coef_dia = NaN;
    end
    
    % ======================================================================
    % STEP 7: Save Results
    % ======================================================================
    fprintf('STEP 7: Saving Results\n');
    fprintf('----------------------------------------\n');
    
    % Save predictions
    predictions_path = fullfile('..', 'output', 'model_predictions.csv');
    if ~exist(fullfile('..', 'output'), 'dir')
        predictions_path = fullfile('output', 'model_predictions.csv');
    end
    results_table = save_predictions(cv_results.predictions, predictions_path);
    
    % Save metrics (includes all model coefficients)
    metrics_path = fullfile('..', 'output', 'model_metrics.csv');
    if ~exist(fullfile('..', 'output'), 'dir')
        metrics_path = fullfile('output', 'model_metrics.csv');
    end
    metrics_table = save_metrics(cv_results, sys_model, dia_model, feature_names, metrics_path);
    
    % Save fold metrics
    fold_metrics_path = fullfile('..', 'output', 'fold_metrics.csv');
    if ~exist(fullfile('..', 'output'), 'dir')
        fold_metrics_path = fullfile('output', 'fold_metrics.csv');
    end
    save_fold_metrics(cv_results.fold_metrics, fold_metrics_path);
    
    fprintf('\n');
    
    % ======================================================================
    % SUMMARY
    % ======================================================================
    fprintf('============================================================\n');
    fprintf('SUMMARY\n');
    fprintf('============================================================\n\n');
    
    fprintf('Approach: Calibration-Based Prediction\n');
    fprintf('  - First measurement per subject used for calibration\n');
    fprintf('  - Model predicts BP changes relative to calibration\n');
    fprintf('  - predicted_BP = calibration_BP + model_prediction\n\n');
    
    fprintf('Features used: %s\n\n', strjoin(feature_names, ', '));
    
    fprintf('Cross-Validation Results (Leave-One-Subject-Out):\n');
    fprintf('  Systolic BP:   R² = %.4f, RMSE = %.2f mmHg, MAE = %.2f mmHg\n', ...
            cv_results.sys_r2, cv_results.sys_rmse, cv_results.sys_mae);
    fprintf('  Diastolic BP:  R² = %.4f, RMSE = %.2f mmHg, MAE = %.2f mmHg\n', ...
            cv_results.dia_r2, cv_results.dia_rmse, cv_results.dia_mae);
    fprintf('\n');
    
    % Clinical interpretation
    fprintf('Clinical Interpretation:\n');
    if cv_results.sys_rmse < 10
        fprintf('  Systolic RMSE < 10 mmHg: Good for screening purposes\n');
    elseif cv_results.sys_rmse < 15
        fprintf('  Systolic RMSE < 15 mmHg: Acceptable for monitoring trends\n');
    else
        fprintf('  Systolic RMSE >= 15 mmHg: May need more features or data\n');
    end
    
    if cv_results.sys_r2 > 0
        fprintf('  R² > 0: Model explains some variance (better than mean)\n');
    else
        fprintf('  R² <= 0: Model needs improvement\n');
    end
    fprintf('\n');
    
    fprintf('Output files:\n');
    fprintf('  - %s\n', predictions_path);
    fprintf('  - %s\n', metrics_path);
    fprintf('  - %s\n', fold_metrics_path);
    fprintf('\n');
end


%% ==========================================================================
%  DATA LOADING FUNCTIONS
%  ==========================================================================

function data = load_individual_ptt(file_path)
    % Load individual PTT values from CSV file.
    %
    % Args:
    %     file_path: Path to the ptt_individual.csv file
    %
    % Returns:
    %     Table with individual PTT data (only valid values)
    
    if ~exist(file_path, 'file')
        error(['Individual PTT file not found: %s\n' ...
               'Please run target_2_peak_detection.m first.'], file_path);
    end
    
    data = readtable(file_path);
    
    % Filter to only valid PTT values
    if iscell(data.quality)
        valid_mask = strcmp(data.quality, 'valid');
    else
        valid_mask = (data.quality == "valid");
    end
    n_before = height(data);
    data = data(valid_mask, :);
    fprintf('Loaded %d individual PTT values (%d valid, %d invalid removed)\n', ...
            n_before, height(data), n_before - height(data));
end


%% ==========================================================================
%  FEATURE COMPUTATION
%  ==========================================================================

function segment_features = compute_segment_features(ptt_data)
    % Compute per-segment features from individual PTT values.
    %
    % Features computed:
    %   - median_ptt: Robust central tendency
    %   - mean_ptt: Mean PTT
    %   - std_ptt: PTT variability
    %   - ptt_iqr: Interquartile range
    %   - mean_hr: Mean heart rate (if available)
    %   - std_hr: Heart rate variability
    %   - n_beats: Number of valid beats
    %
    % Args:
    %     ptt_data: Table with individual PTT values
    %
    % Returns:
    %     Table with per-segment features
    
    % Get unique (subject_id, sheet) combinations
    if iscell(ptt_data.subject_id)
        [groups, ~, group_idx] = unique(table(ptt_data.subject_id, ptt_data.sheet), 'rows');
    else
        [groups, ~, group_idx] = unique(ptt_data(:, {'subject_id', 'sheet'}), 'rows');
    end
    
    num_segments = height(groups);
    
    % Initialize feature arrays
    subject_ids = cell(num_segments, 1);
    sheets = cell(num_segments, 1);
    sheet_nums = nan(num_segments, 1);  % Numeric sheet for sorting
    sys_bp = nan(num_segments, 1);
    dia_bp = nan(num_segments, 1);
    median_ptt = nan(num_segments, 1);
    mean_ptt = nan(num_segments, 1);
    std_ptt = nan(num_segments, 1);
    ptt_iqr_vals = nan(num_segments, 1);
    cv_ptt = nan(num_segments, 1);  % Coefficient of variation
    mean_hr = nan(num_segments, 1);
    std_hr = nan(num_segments, 1);
    n_beats = zeros(num_segments, 1);
    
    % Check if HR data is available
    has_hr = ismember('heart_rate_bpm', ptt_data.Properties.VariableNames);
    
    for i = 1:num_segments
        % Get data for this segment
        mask = (group_idx == i);
        segment_data = ptt_data(mask, :);
        
        % Extract subject_id and sheet
        if iscell(segment_data.subject_id)
            subject_ids{i} = segment_data.subject_id{1};
        else
            subject_ids{i} = char(segment_data.subject_id(1));
        end
        
        if iscell(segment_data.sheet)
            sheets{i} = segment_data.sheet{1};
            sheet_nums(i) = str2double(segment_data.sheet{1});
        elseif isnumeric(segment_data.sheet)
            sheets{i} = num2str(segment_data.sheet(1));
            sheet_nums(i) = segment_data.sheet(1);
        else
            sheets{i} = char(segment_data.sheet(1));
            sheet_nums(i) = str2double(char(segment_data.sheet(1)));
        end
        
        % Extract BP values
        sys_bp(i) = segment_data.sys_bp(1);
        dia_bp(i) = segment_data.dia_bp(1);
        
        % Compute PTT statistics
        ptt_values = segment_data.ptt_samples;
        n_beats(i) = length(ptt_values);
        
        if n_beats(i) >= 2
            median_ptt(i) = median(ptt_values);
            mean_ptt(i) = mean(ptt_values);
            std_ptt(i) = std(ptt_values);
            ptt_iqr_vals(i) = iqr(ptt_values);
            cv_ptt(i) = std_ptt(i) / mean_ptt(i);
        elseif n_beats(i) == 1
            median_ptt(i) = ptt_values(1);
            mean_ptt(i) = ptt_values(1);
            std_ptt(i) = 0;
            ptt_iqr_vals(i) = 0;
            cv_ptt(i) = 0;
        end
        
        % Compute HR statistics if available
        if has_hr
            hr_values = segment_data.heart_rate_bpm;
            hr_values = hr_values(~isnan(hr_values));
            if ~isempty(hr_values)
                mean_hr(i) = mean(hr_values);
                if length(hr_values) >= 2
                    std_hr(i) = std(hr_values);
                end
            end
        end
    end
    
    % Create output table
    segment_features = table(subject_ids, sheets, sheet_nums, sys_bp, dia_bp, ...
                             median_ptt, mean_ptt, std_ptt, ptt_iqr_vals, cv_ptt, ...
                             mean_hr, std_hr, n_beats, ...
                             'VariableNames', {'subject_id', 'sheet', 'sheet_num', ...
                                              'sys_bp', 'dia_bp', ...
                                              'median_ptt', 'mean_ptt', 'std_ptt', ...
                                              'ptt_iqr', 'cv_ptt', ...
                                              'mean_hr', 'std_hr', 'n_beats'});
    
    % Remove segments with no valid PTT data
    valid_mask = n_beats >= 1 & ~isnan(sys_bp) & ~isnan(dia_bp);
    segment_features = segment_features(valid_mask, :);
    
    fprintf('Computed features for %d segments\n', height(segment_features));
    fprintf('Features: median_ptt, mean_ptt, std_ptt, ptt_iqr, cv_ptt, mean_hr, std_hr\n');
end


function verify_ptt_bp_correlation(data)
    % Verify the expected negative correlation between PTT and BP.
    %
    % Args:
    %     data: Table with segment features including median_ptt, sys_bp, dia_bp
    
    valid_mask = ~isnan(data.median_ptt) & ~isnan(data.sys_bp) & ~isnan(data.dia_bp);
    
    if sum(valid_mask) < 10
        fprintf('WARNING: Not enough data points for correlation analysis (%d)\n', sum(valid_mask));
        return;
    end
    
    ptt = data.median_ptt(valid_mask);
    sys = data.sys_bp(valid_mask);
    dia = data.dia_bp(valid_mask);
    
    % Calculate correlations
    [r_sys, p_sys] = corr(ptt, sys, 'Type', 'Pearson');
    [r_dia, p_dia] = corr(ptt, dia, 'Type', 'Pearson');
    
    fprintf('PTT-BP Correlation Analysis (n=%d):\n', sum(valid_mask));
    fprintf('  PTT vs Systolic:  r = %.4f (p = %.4f)\n', r_sys, p_sys);
    fprintf('  PTT vs Diastolic: r = %.4f (p = %.4f)\n', r_dia, p_dia);
    fprintf('\n');
    
    fprintf('Expected: NEGATIVE correlation (higher BP = shorter PTT)\n');
    
    if r_sys < 0
        fprintf('  Systolic:  ✓ Correlation is negative as expected\n');
    else
        fprintf('  Systolic:  ✗ Correlation is positive (unexpected)\n');
        fprintf('            This may indicate data quality issues or\n');
        fprintf('            confounding factors in the measurements.\n');
    end
    
    if r_dia < 0
        fprintf('  Diastolic: ✓ Correlation is negative as expected\n');
    else
        fprintf('  Diastolic: ✗ Correlation is positive (unexpected)\n');
    end
end


%% ==========================================================================
%  CALIBRATION-BASED DATA PREPARATION
%  ==========================================================================

function [calib_data, feature_names] = prepare_calibration_data(data)
    % Prepare calibration-based data for modeling.
    %
    % For each subject:
    % - Sheet 1 (or lowest numbered sheet) = calibration
    % - Other sheets = test data with features relative to calibration
    %
    % Args:
    %     data: Table with segment features
    %
    % Returns:
    %     calib_data: Table with calibration-relative features
    %     feature_names: Names of features used
    
    % Get unique subjects
    unique_subjects = unique(data.subject_id);
    num_subjects = length(unique_subjects);
    
    fprintf('Preparing calibration data for %d subjects\n', num_subjects);
    
    % Initialize output arrays
    calib_data = struct();
    calib_data.subject_id = {};
    calib_data.sheet = {};
    calib_data.sys_bp = [];
    calib_data.dia_bp = [];
    calib_data.calib_sys = [];
    calib_data.calib_dia = [];
    calib_data.calib_ptt = [];
    calib_data.delta_ptt = [];
    calib_data.delta_ptt_norm = [];  % Normalized by calibration PTT
    calib_data.ptt_iqr = [];
    calib_data.cv_ptt = [];
    calib_data.delta_hr = [];
    calib_data.is_calibration = [];
    
    for s = 1:num_subjects
        if iscell(unique_subjects)
            subj = unique_subjects{s};
            subj_mask = strcmp(data.subject_id, subj);
        else
            subj = unique_subjects(s);
            subj_mask = (data.subject_id == subj);
        end
        
        subj_data = data(subj_mask, :);
        
        % Sort by sheet number
        [~, sort_idx] = sort(subj_data.sheet_num);
        subj_data = subj_data(sort_idx, :);
        
        if height(subj_data) < 1
            continue;
        end
        
        % First sheet = calibration
        calib_idx = 1;
        calib_ptt = subj_data.median_ptt(calib_idx);
        calib_sys = subj_data.sys_bp(calib_idx);
        calib_dia = subj_data.dia_bp(calib_idx);
        calib_hr = subj_data.mean_hr(calib_idx);
        
        if isnan(calib_ptt) || isnan(calib_sys)
            continue;
        end
        
        % Process all sheets (including calibration for reference)
        for i = 1:height(subj_data)
            if iscell(subj_data.subject_id)
                calib_data.subject_id{end+1} = subj_data.subject_id{i};
            else
                calib_data.subject_id{end+1} = char(subj_data.subject_id(i));
            end
            
            if iscell(subj_data.sheet)
                calib_data.sheet{end+1} = subj_data.sheet{i};
            else
                calib_data.sheet{end+1} = char(subj_data.sheet(i));
            end
            
            calib_data.sys_bp(end+1) = subj_data.sys_bp(i);
            calib_data.dia_bp(end+1) = subj_data.dia_bp(i);
            calib_data.calib_sys(end+1) = calib_sys;
            calib_data.calib_dia(end+1) = calib_dia;
            calib_data.calib_ptt(end+1) = calib_ptt;
            
            % Compute delta features relative to calibration
            if ~isnan(subj_data.median_ptt(i))
                calib_data.delta_ptt(end+1) = subj_data.median_ptt(i) - calib_ptt;
                calib_data.delta_ptt_norm(end+1) = (subj_data.median_ptt(i) - calib_ptt) / calib_ptt;
            else
                calib_data.delta_ptt(end+1) = 0;
                calib_data.delta_ptt_norm(end+1) = 0;
            end
            
            % Other features
            if ~isnan(subj_data.ptt_iqr(i))
                calib_data.ptt_iqr(end+1) = subj_data.ptt_iqr(i);
            else
                calib_data.ptt_iqr(end+1) = 0;
            end
            
            if ~isnan(subj_data.cv_ptt(i))
                calib_data.cv_ptt(end+1) = subj_data.cv_ptt(i);
            else
                calib_data.cv_ptt(end+1) = 0;
            end
            
            % Heart rate delta
            if ~isnan(subj_data.mean_hr(i)) && ~isnan(calib_hr)
                calib_data.delta_hr(end+1) = subj_data.mean_hr(i) - calib_hr;
            else
                calib_data.delta_hr(end+1) = 0;
            end
            
            % Mark calibration sheets
            calib_data.is_calibration(end+1) = (i == calib_idx);
        end
    end
    
    % Convert to table properly - transpose arrays to column vectors
    n_samples = length(calib_data.subject_id);
    
    if n_samples == 0
        calib_data = table();
        feature_names = {'delta_ptt'};
        fprintf('WARNING: No calibration data available.\n');
        return;
    end
    
    calib_data = table(calib_data.subject_id', ...
                       calib_data.sheet', ...
                       calib_data.sys_bp', ...
                       calib_data.dia_bp', ...
                       calib_data.calib_sys', ...
                       calib_data.calib_dia', ...
                       calib_data.calib_ptt', ...
                       calib_data.delta_ptt', ...
                       calib_data.delta_ptt_norm', ...
                       calib_data.ptt_iqr', ...
                       calib_data.cv_ptt', ...
                       calib_data.delta_hr', ...
                       calib_data.is_calibration', ...
                       'VariableNames', {'subject_id', 'sheet', 'sys_bp', 'dia_bp', ...
                                        'calib_sys', 'calib_dia', 'calib_ptt', ...
                                        'delta_ptt', 'delta_ptt_norm', ...
                                        'ptt_iqr', 'cv_ptt', 'delta_hr', 'is_calibration'});
    
    % Define features to use for modeling
    % Using multiple features for better prediction
    % Note: delta_ptt is the primary physiological feature
    % Additional features capture variability and heart rate effects
    feature_names = {'delta_ptt', 'delta_hr', 'ptt_iqr', 'cv_ptt'};
    
    % Remove features that are all zeros or have no variance
    valid_features = {};
    for f = 1:length(feature_names)
        feat_vals = calib_data.(feature_names{f});
        feat_vals = feat_vals(~calib_data.is_calibration);
        if std(feat_vals) > 1e-6  % Has some variance
            valid_features{end+1} = feature_names{f};
        else
            fprintf('Warning: Feature %s has no variance, excluding.\n', feature_names{f});
        end
    end
    feature_names = valid_features;
    
    if isempty(feature_names)
        feature_names = {'delta_ptt'};
        fprintf('Warning: No valid features found, falling back to delta_ptt only.\n');
    end
    
    fprintf('Total samples: %d (%d calibration, %d for prediction)\n', ...
            height(calib_data), sum(calib_data.is_calibration), ...
            sum(~calib_data.is_calibration));
    fprintf('Features selected: %s\n', strjoin(feature_names, ', '));
end


%% ==========================================================================
%  CROSS-VALIDATION
%  ==========================================================================

function cv_results = cross_validate_loso(data, feature_names)
    % Perform Leave-One-Subject-Out cross-validation.
    %
    % For each held-out subject:
    % 1. Train on all other subjects (using their calibration-relative data)
    % 2. Apply to held-out subject (excluding calibration sheet)
    %
    % Args:
    %     data: Calibration-based data table
    %     feature_names: Names of features to use
    %
    % Returns:
    %     cv_results: Struct with cross-validation results
    
    % Get unique subjects
    unique_subjects = unique(data.subject_id);
    num_subjects = length(unique_subjects);
    
    fprintf('Cross-validating with %d subjects (LOSO)\n', num_subjects);
    
    % Initialize prediction storage
    predictions = struct();
    predictions.subject_id = {};
    predictions.sheet = {};
    predictions.actual_sys = [];
    predictions.pred_sys = [];
    predictions.actual_dia = [];
    predictions.pred_dia = [];
    predictions.calib_sys = [];
    predictions.calib_dia = [];
    
    % Initialize fold metrics
    fold_metrics = struct();
    fold_metrics.subject = {};
    fold_metrics.n_train = [];
    fold_metrics.n_test = [];
    fold_metrics.sys_rmse = [];
    fold_metrics.sys_mae = [];
    fold_metrics.dia_rmse = [];
    fold_metrics.dia_mae = [];
    fold_metrics.calib_sys = [];
    fold_metrics.calib_dia = [];
    
    for fold = 1:num_subjects
        if iscell(unique_subjects)
            test_subject = unique_subjects{fold};
            test_mask = strcmp(data.subject_id, test_subject);
        else
            test_subject = unique_subjects(fold);
            test_mask = (data.subject_id == test_subject);
        end
        train_mask = ~test_mask;
        
        % Training data: non-calibration samples from other subjects
        train_data = data(train_mask & ~data.is_calibration, :);
        
        % Test data: non-calibration samples from test subject
        test_data = data(test_mask & ~data.is_calibration, :);
        
        if height(train_data) < 5 || height(test_data) < 1
            continue;
        end
        
        % Prepare feature matrix
        X_train = zeros(height(train_data), length(feature_names));
        for f = 1:length(feature_names)
            X_train(:, f) = train_data.(feature_names{f});
        end
        
        X_test = zeros(height(test_data), length(feature_names));
        for f = 1:length(feature_names)
            X_test(:, f) = test_data.(feature_names{f});
        end
        
        % Target: BP change from calibration
        y_train_sys = train_data.sys_bp - train_data.calib_sys;
        y_train_dia = train_data.dia_bp - train_data.calib_dia;
        
        % Train models
        sys_model = train_linear_model(X_train, y_train_sys);
        dia_model = train_linear_model(X_train, y_train_dia);
        
        % Predict BP changes
        delta_sys_pred = predict_linear(sys_model, X_test);
        delta_dia_pred = predict_linear(dia_model, X_test);
        
        % Convert to absolute BP
        pred_sys = test_data.calib_sys + delta_sys_pred;
        pred_dia = test_data.calib_dia + delta_dia_pred;
        
        % Store predictions
        for i = 1:height(test_data)
            if iscell(test_data.subject_id)
                predictions.subject_id{end+1} = test_data.subject_id{i};
            else
                predictions.subject_id{end+1} = char(test_data.subject_id(i));
            end
            if iscell(test_data.sheet)
                predictions.sheet{end+1} = test_data.sheet{i};
            else
                predictions.sheet{end+1} = char(test_data.sheet(i));
            end
            predictions.actual_sys(end+1) = test_data.sys_bp(i);
            predictions.pred_sys(end+1) = pred_sys(i);
            predictions.actual_dia(end+1) = test_data.dia_bp(i);
            predictions.pred_dia(end+1) = pred_dia(i);
            predictions.calib_sys(end+1) = test_data.calib_sys(i);
            predictions.calib_dia(end+1) = test_data.calib_dia(i);
        end
        
        % Calculate fold metrics
        fold_sys_rmse = sqrt(mean((test_data.sys_bp - pred_sys).^2));
        fold_sys_mae = mean(abs(test_data.sys_bp - pred_sys));
        fold_dia_rmse = sqrt(mean((test_data.dia_bp - pred_dia).^2));
        fold_dia_mae = mean(abs(test_data.dia_bp - pred_dia));
        
        if iscell(unique_subjects)
            fold_metrics.subject{end+1} = test_subject;
        else
            fold_metrics.subject{end+1} = char(test_subject);
        end
        fold_metrics.n_train(end+1) = height(train_data);
        fold_metrics.n_test(end+1) = height(test_data);
        fold_metrics.sys_rmse(end+1) = fold_sys_rmse;
        fold_metrics.sys_mae(end+1) = fold_sys_mae;
        fold_metrics.dia_rmse(end+1) = fold_dia_rmse;
        fold_metrics.dia_mae(end+1) = fold_dia_mae;
        fold_metrics.calib_sys(end+1) = test_data.calib_sys(1);
        fold_metrics.calib_dia(end+1) = test_data.calib_dia(1);
    end
    
    % Calculate overall metrics
    if ~isempty(predictions.actual_sys)
        actual_sys = predictions.actual_sys';
        pred_sys = predictions.pred_sys';
        actual_dia = predictions.actual_dia';
        pred_dia = predictions.pred_dia';
        
        sys_metrics = calculate_metrics(actual_sys, pred_sys);
        dia_metrics = calculate_metrics(actual_dia, pred_dia);
    else
        sys_metrics = struct('r2', 0, 'rmse', 0, 'mae', 0);
        dia_metrics = struct('r2', 0, 'rmse', 0, 'mae', 0);
    end
    
    % Store results
    cv_results = struct();
    cv_results.sys_r2 = sys_metrics.r2;
    cv_results.sys_rmse = sys_metrics.rmse;
    cv_results.sys_mae = sys_metrics.mae;
    cv_results.dia_r2 = dia_metrics.r2;
    cv_results.dia_rmse = dia_metrics.rmse;
    cv_results.dia_mae = dia_metrics.mae;
    cv_results.n_samples = length(predictions.actual_sys);
    cv_results.predictions = predictions;
    cv_results.fold_metrics = fold_metrics;
end


%% ==========================================================================
%  MODEL TRAINING
%  ==========================================================================

function model = train_linear_model(X_train, y_train)
    % Train a Ridge regression model with cross-validated regularization.
    %
    % Uses the normal equation with L2 regularization:
    % beta = (X'X + lambda*I)^(-1) X'y
    %
    % Args:
    %     X_train: Training feature matrix
    %     y_train: Training target vector (BP changes)
    %
    % Returns:
    %     model: Struct with intercept, coefficients, and lambda
    
    y_train = y_train(:);
    n = size(X_train, 1);
    p = size(X_train, 2);
    
    % Standardize features for better regularization
    feature_means = mean(X_train, 1);
    feature_stds = std(X_train, 0, 1);
    feature_stds(feature_stds == 0) = 1;  % Avoid division by zero
    X_scaled = (X_train - feature_means) ./ feature_stds;
    
    % Center target
    y_mean = mean(y_train);
    y_centered = y_train - y_mean;
    
    % Try multiple regularization strengths and use cross-validation
    lambdas = [0.001, 0.01, 0.1, 1.0, 10.0, 100.0];
    best_lambda = 1.0;
    best_cv_error = inf;
    
    if n >= 5
        % K-fold cross-validation for lambda selection
        k_folds = min(5, n);
        fold_size = floor(n / k_folds);
        
        for lambda = lambdas
            cv_errors = zeros(k_folds, 1);
            
            for fold = 1:k_folds
                % Create validation indices
                val_start = (fold - 1) * fold_size + 1;
                val_end = min(fold * fold_size, n);
                val_idx = val_start:val_end;
                train_idx = setdiff(1:n, val_idx);
                
                if length(train_idx) < 2
                    continue;
                end
                
                % Train on this fold
                X_fold = X_scaled(train_idx, :);
                y_fold = y_centered(train_idx);
                
                I_reg = eye(p);
                beta_fold = (X_fold' * X_fold + lambda * I_reg) \ (X_fold' * y_fold);
                
                % Validate
                y_pred = X_scaled(val_idx, :) * beta_fold;
                cv_errors(fold) = mean((y_centered(val_idx) - y_pred).^2);
            end
            
            mean_cv_error = mean(cv_errors);
            if mean_cv_error < best_cv_error
                best_cv_error = mean_cv_error;
                best_lambda = lambda;
            end
        end
    end
    
    % Train final model with best lambda
    I_reg = eye(p);
    beta_scaled = (X_scaled' * X_scaled + best_lambda * I_reg) \ (X_scaled' * y_centered);
    
    % Convert back to original scale
    beta_original = beta_scaled ./ feature_stds(:);
    intercept = y_mean - feature_means * beta_original;
    
    model = struct();
    model.intercept = intercept;
    model.coefficients = beta_original;
    model.lambda = best_lambda;
    model.feature_means = feature_means;
    model.feature_stds = feature_stds;
end


function predictions = predict_linear(model, X)
    % Make predictions using trained model.
    %
    % Args:
    %     model: Trained model struct
    %     X: Feature matrix
    %
    % Returns:
    %     predictions: Prediction array
    
    predictions = model.intercept + X * model.coefficients;
end


function [sys_model, dia_model] = train_final_models(data, feature_names)
    % Train final models on all data.
    %
    % Args:
    %     data: Calibration-based data table
    %     feature_names: Names of features to use
    %
    % Returns:
    %     sys_model: Systolic BP model
    %     dia_model: Diastolic BP model
    
    % Use non-calibration data only
    train_data = data(~data.is_calibration, :);
    
    % Prepare feature matrix
    X = zeros(height(train_data), length(feature_names));
    for f = 1:length(feature_names)
        X(:, f) = train_data.(feature_names{f});
    end
    
    % Target: BP change from calibration
    y_sys = train_data.sys_bp - train_data.calib_sys;
    y_dia = train_data.dia_bp - train_data.calib_dia;
    
    % Train models
    sys_model = train_linear_model(X, y_sys);
    dia_model = train_linear_model(X, y_dia);
end


%% ==========================================================================
%  EVALUATION FUNCTIONS
%  ==========================================================================

function metrics = calculate_metrics(y_actual, y_predicted)
    % Calculate evaluation metrics.
    %
    % Args:
    %     y_actual: Actual values
    %     y_predicted: Predicted values
    %
    % Returns:
    %     metrics: Struct with r2, rmse, mae
    
    y_actual = y_actual(:);
    y_predicted = y_predicted(:);
    
    % R-squared
    ss_res = sum((y_actual - y_predicted).^2);
    ss_tot = sum((y_actual - mean(y_actual)).^2);
    
    if ss_tot == 0
        r2 = 0;
    else
        r2 = 1 - (ss_res / ss_tot);
    end
    
    % RMSE
    rmse = sqrt(mean((y_actual - y_predicted).^2));
    
    % MAE
    mae = mean(abs(y_actual - y_predicted));
    
    metrics = struct();
    metrics.r2 = r2;
    metrics.rmse = rmse;
    metrics.mae = mae;
end


%% ==========================================================================
%  RESULTS SAVING
%  ==========================================================================

function results_table = save_predictions(predictions, output_path)
    % Save predictions to CSV file.
    %
    % Args:
    %     predictions: Struct with prediction data
    %     output_path: Path to output CSV file
    %
    % Returns:
    %     results_table: Table of predictions
    
    n = length(predictions.subject_id);
    
    if n == 0
        fprintf('No predictions to save.\n');
        results_table = table();
        return;
    end
    
    % Build table
    subject_id = predictions.subject_id';
    sheet = predictions.sheet';
    actual_sys = round(predictions.actual_sys', 0);
    predicted_sys = round(predictions.pred_sys', 2);
    actual_dia = round(predictions.actual_dia', 0);
    predicted_dia = round(predictions.pred_dia', 2);
    calibration_sys = round(predictions.calib_sys', 0);
    calibration_dia = round(predictions.calib_dia', 0);
    sys_error = round(actual_sys - predicted_sys, 2);
    dia_error = round(actual_dia - predicted_dia, 2);
    
    results_table = table(subject_id, sheet, actual_sys, predicted_sys, ...
                          actual_dia, predicted_dia, ...
                          calibration_sys, calibration_dia, ...
                          sys_error, dia_error);
    
    writetable(results_table, output_path);
    fprintf('Predictions saved to: %s (%d records)\n', output_path, n);
end


function metrics_table = save_metrics(cv_results, sys_model, dia_model, feature_names, output_path)
    % Save metrics and all model coefficients to CSV file.
    %
    % Args:
    %     cv_results: Cross-validation results
    %     sys_model: Systolic model with intercept and coefficients
    %     dia_model: Diastolic model with intercept and coefficients
    %     feature_names: Names of features used
    %     output_path: Path to output CSV file
    %
    % Returns:
    %     metrics_table: Table of metrics
    
    % Start with approach and intercepts
    metrics = {
        'approach', 'calibration_based';
        'sys_intercept', round(sys_model.intercept, 6);
        'dia_intercept', round(dia_model.intercept, 6);
    };
    
    % Add all coefficients for each feature
    for i = 1:length(feature_names)
        feat_name = feature_names{i};
        metrics{end+1, 1} = ['sys_coef_' feat_name];
        metrics{end, 2} = round(sys_model.coefficients(i), 6);
        metrics{end+1, 1} = ['dia_coef_' feat_name];
        metrics{end, 2} = round(dia_model.coefficients(i), 6);
    end
    
    % Add feature names as comma-separated list
    metrics{end+1, 1} = 'feature_names';
    metrics{end, 2} = strjoin(feature_names, ',');
    
    % Add regularization lambdas
    metrics{end+1, 1} = 'sys_lambda';
    metrics{end, 2} = round(sys_model.lambda, 4);
    metrics{end+1, 1} = 'dia_lambda';
    metrics{end, 2} = round(dia_model.lambda, 4);
    
    % Add evaluation metrics
    metrics{end+1, 1} = 'sys_r2';
    metrics{end, 2} = round(cv_results.sys_r2, 4);
    metrics{end+1, 1} = 'sys_rmse';
    metrics{end, 2} = round(cv_results.sys_rmse, 2);
    metrics{end+1, 1} = 'sys_mae';
    metrics{end, 2} = round(cv_results.sys_mae, 2);
    metrics{end+1, 1} = 'dia_r2';
    metrics{end, 2} = round(cv_results.dia_r2, 4);
    metrics{end+1, 1} = 'dia_rmse';
    metrics{end, 2} = round(cv_results.dia_rmse, 2);
    metrics{end+1, 1} = 'dia_mae';
    metrics{end, 2} = round(cv_results.dia_mae, 2);
    metrics{end+1, 1} = 'n_samples';
    metrics{end, 2} = cv_results.n_samples;
    
    metrics_table = cell2table(metrics, 'VariableNames', {'metric', 'value'});
    writetable(metrics_table, output_path);
    fprintf('Metrics saved to: %s\n', output_path);
end


function save_fold_metrics(fold_metrics, output_path)
    % Save per-fold metrics to CSV file.
    %
    % Args:
    %     fold_metrics: Struct with per-fold metrics
    %     output_path: Path to output CSV file
    
    n = length(fold_metrics.subject);
    
    if n == 0
        fprintf('No fold metrics to save.\n');
        return;
    end
    
    fold = fold_metrics.subject';
    n_train_subjects = fold_metrics.n_train';
    n_test_samples = fold_metrics.n_test';
    calibration_sys = round(fold_metrics.calib_sys', 0);
    calibration_dia = round(fold_metrics.calib_dia', 0);
    sys_rmse = round(fold_metrics.sys_rmse', 2);
    sys_mae = round(fold_metrics.sys_mae', 2);
    dia_rmse = round(fold_metrics.dia_rmse', 2);
    dia_mae = round(fold_metrics.dia_mae', 2);
    
    fold_table = table(fold, n_train_subjects, n_test_samples, ...
                       calibration_sys, calibration_dia, ...
                       sys_rmse, sys_mae, dia_rmse, dia_mae);
    
    writetable(fold_table, output_path);
    fprintf('Fold metrics saved to: %s\n', output_path);
end
