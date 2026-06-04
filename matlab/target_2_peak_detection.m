%% Target 2: Peak Detection and PTT Calculation
%
% Detects ECG R-peaks and PPG peaks, calculates Pulse Transit Time (PTT)
%
% PTT = Time from ECG R-peak to PPG systolic peak (same cardiac cycle)
% Higher blood pressure = faster pulse wave = shorter PTT
%
% Output: output/ptt_individual.csv
%
% Author: Elena Cavazza | Date: 2026

function target_2_peak_detection()
    %% Configuration
    FS = 250;                          % Sampling rate (Hz)
    
    % Heart rate bounds: 40-200 bpm
    MIN_RR = round(0.300 * FS);        % Min R-R interval: 300ms (200 bpm max)
    MAX_RR = round(1.500 * FS);        % Max R-R interval: 1500ms (40 bpm min)
    
    % PTT bounds - physiologically realistic for finger PPG
    MIN_PTT = round(0.120 * FS);       % Min PTT: 120ms (30 samples)
    MAX_PTT = round(0.600 * FS);       % Max PTT: 600ms (150 samples)
    
    %% Load Data
    data_file = fullfile('output', 'cleaned_bp_data.csv');
    if ~exist(data_file, 'file')
        data_file = fullfile('..', 'output', 'cleaned_bp_data.csv');
    end
    data = readtable(data_file);
    fprintf('Target 2: Processing %d records...\n', height(data));
    
    %% Process Each Segment
    [groups, ~, group_idx] = unique(data(:, {'subject_id', 'sheet'}), 'rows');
    all_ptt = [];
    
    total_beats = 0;
    total_valid = 0;
    
    for i = 1:height(groups)
        mask = (group_idx == i);
        ecg = data.ecg(mask);
        ppg = data.ppg(mask);
        subj = char(groups.subject_id(i));
        
        % Handle sheet - it may be numeric, string, or cell
        sheet_val = groups.sheet(i);
        if isnumeric(sheet_val)
            sheet = num2str(sheet_val);
        elseif iscell(sheet_val)
            sheet = num2str(sheet_val{1});
        else
            sheet = char(sheet_val);
        end
        
        sys = data.sys(find(mask, 1));
        dia = data.dia(find(mask, 1));
        
        % Detect peaks and calculate PTT
        [ecg_peaks, ppg_peaks, ptt_vals, ptt_valid, heart_rates] = ...
            analyze_segment(ecg, ppg, FS, MIN_RR, MAX_RR, MIN_PTT, MAX_PTT);
        
        n_beats = length(ptt_vals);
        n_valid = sum(ptt_valid);
        total_beats = total_beats + n_beats;
        total_valid = total_valid + n_valid;
        
        % Store individual PTT values
        for j = 1:n_beats
            quality = 'invalid';
            if ptt_valid(j)
                quality = 'valid';
            end
            
            hr = NaN;
            if j <= length(heart_rates)
                hr = heart_rates(j);
            end
            
            all_ptt = [all_ptt; {subj, sheet, j, ecg_peaks(j), ppg_peaks(j), ...
                       ptt_vals(j), ptt_vals(j)*1000/FS, hr, sys, dia, quality}]; %#ok<AGROW>
        end
    end
    
    %% Save Results
    ptt_table = cell2table(all_ptt, 'VariableNames', ...
        {'subject_id','sheet','beat_index','ecg_peak_idx','ppg_peak_idx', ...
         'ptt_samples','ptt_ms','heart_rate_bpm','sys_bp','dia_bp','quality'});
    
    output_file = fullfile('output', 'ptt_individual.csv');
    if ~exist('output', 'dir')
        output_file = fullfile('..', 'output', 'ptt_individual.csv');
    end
    writetable(ptt_table, output_file);
    
    %% Summary
    valid_mask = strcmp(all_ptt(:,11), 'valid');
    valid_ptt_ms = cell2mat(all_ptt(valid_mask, 7));
    
    fprintf('Complete: %d beats, %d valid (%.1f%%)\n', ...
            total_beats, total_valid, 100*total_valid/max(1,total_beats));
    fprintf('PTT range: %.1f-%.1f ms (mean: %.1f ms)\n', ...
            min(valid_ptt_ms), max(valid_ptt_ms), mean(valid_ptt_ms));
    fprintf('Output: %s\n', output_file);
end


%% Analyze Segment
function [ecg_peaks, ppg_peaks, ptt_vals, ptt_valid, heart_rates] = ...
        analyze_segment(ecg, ppg, fs, min_rr, max_rr, min_ptt, max_ptt)
    
    % Step 1: Detect ECG R-peaks
    ecg_peaks = detect_ecg_peaks(ecg, fs, min_rr);
    
    % Step 2: Validate R-R intervals
    ecg_peaks = validate_rr_intervals(ecg_peaks, min_rr, max_rr);
    
    % Step 3: Calculate heart rates
    heart_rates = calculate_heart_rates(ecg_peaks, fs);
    
    % Step 4: Find PPG peaks and calculate PTT
    [ppg_peaks, ptt_vals, ptt_valid] = find_ppg_peaks(ppg, ecg_peaks, fs, min_ptt, max_ptt);
    
    % Step 5: IQR-based outlier removal
    if sum(ptt_valid) >= 5
        valid_ptt = ptt_vals(ptt_valid);
        ptt_median = median(valid_ptt);
        ptt_iqr = iqr(valid_ptt);
        
        lower_bound = max(ptt_median - 1.5 * ptt_iqr, min_ptt);
        upper_bound = min(ptt_median + 1.5 * ptt_iqr, max_ptt);
        
        outlier_mask = (ptt_vals < lower_bound) | (ptt_vals > upper_bound);
        ptt_valid(outlier_mask) = false;
    end
end


%% ECG R-Peak Detection
function peaks = detect_ecg_peaks(ecg, fs, min_rr)
    % Pan-Tompkins inspired approach:
    % 1. Bandpass filter (0.5-40 Hz)
    % 2. Differentiate
    % 3. Square
    % 4. Moving window integration
    % 5. Adaptive threshold
    % 6. Refine to actual R-peak
    
    ecg = fillmissing(ecg(:), 'linear');
    ecg = fillmissing(ecg, 'constant', 0);
    
    if length(ecg) < 50
        peaks = [];
        return;
    end
    
    % Bandpass filter
    try
        [b, a] = butter(2, [0.5 40]/(fs/2), 'bandpass');
        ecg_filt = filtfilt(b, a, ecg);
    catch
        ecg_filt = ecg - movmean(ecg, round(0.5 * fs));
    end
    
    % Differentiate and square
    ecg_diff = [diff(ecg_filt); 0];
    ecg_sq = ecg_diff .^ 2;
    
    % Moving window integration (80ms)
    ecg_int = movmean(ecg_sq, round(0.080 * fs));
    
    % Adaptive threshold
    peaks = [];
    for tf = [1.0, 0.7, 0.5, 0.3, 0.2]
        threshold = mean(ecg_int) + tf * std(ecg_int);
        threshold = min(threshold, 0.5 * max(ecg_int));
        
        warning('off', 'all');
        [~, peaks] = findpeaks(ecg_int, 'MinPeakHeight', threshold, ...
                               'MinPeakDistance', min_rr);
        warning('on', 'all');
        
        if length(peaks) >= 3
            break;
        end
    end
    
    % Fallback
    if length(peaks) < 3
        [pks, all_peaks] = findpeaks(ecg_int, 'MinPeakDistance', min_rr);
        if ~isempty(pks)
            peaks = all_peaks(pks >= median(pks));
        end
    end
    
    if isempty(peaks)
        return;
    end
    
    % Refine to actual R-peak location
    for i = 1:length(peaks)
        search_start = max(1, peaks(i) - round(0.05 * fs));
        search_end = min(length(ecg_filt), peaks(i) + round(0.05 * fs));
        [~, idx] = max(ecg_filt(search_start:search_end));
        peaks(i) = search_start + idx - 1;
    end
    
    peaks = unique(peaks(:));
end


%% R-R Interval Validation
function peaks = validate_rr_intervals(peaks, min_rr, max_rr)
    if length(peaks) < 2
        return;
    end
    
    rr_intervals = diff(peaks);
    interval_valid = (rr_intervals >= min_rr) & (rr_intervals <= max_rr);
    
    rr_valid = true(size(peaks));
    for i = 1:length(peaks)
        if i == 1
            if ~interval_valid(1), rr_valid(1) = false; end
        elseif i == length(peaks)
            if ~interval_valid(end), rr_valid(end) = false; end
        else
            if ~interval_valid(i-1) && ~interval_valid(i)
                rr_valid(i) = false;
            end
        end
    end
    
    peaks = peaks(rr_valid);
end


%% Heart Rate Calculation
function heart_rates = calculate_heart_rates(ecg_peaks, fs)
    if length(ecg_peaks) < 2
        heart_rates = NaN(size(ecg_peaks));
        return;
    end
    
    rr_ms = diff(ecg_peaks) / fs * 1000;
    hr = 60000 ./ rr_ms;
    heart_rates = [NaN; hr(:)];
end


%% PPG Peak Detection
function [ppg_peaks, ptt_vals, ptt_valid] = find_ppg_peaks(ppg, ecg_peaks, fs, min_ptt, max_ptt)
    % Derivative-based PPG peak detection:
    % 1. Lowpass filter at 8 Hz
    % 2. Handle inverted signals
    % 3. Find largest valid peak after R-peak
    % 4. Validate PTT in physiological range (120-500ms)
    
    ppg = fillmissing(ppg(:), 'linear');
    ppg = fillmissing(ppg, 'constant', mean(ppg, 'omitmissing'));
    n = length(ppg);
    
    % Lowpass filter
    try
        [b, a] = butter(2, 8/(fs/2), 'low');
        ppg_filt = filtfilt(b, a, ppg);
    catch
        ppg_filt = movmean(ppg, round(0.04 * fs));
    end
    
    % Handle inverted PPG
    if skewness(ppg_filt - mean(ppg_filt)) < 0
        ppg_search = -ppg_filt;
    else
        ppg_search = ppg_filt;
    end
    
    % First derivative
    ppg_deriv = [0; diff(ppg_search)];
    
    % Initialize outputs
    ppg_peaks = zeros(length(ecg_peaks), 1);
    ptt_vals = zeros(length(ecg_peaks), 1);
    ptt_valid = false(length(ecg_peaks), 1);
    
    % Search window starts at 80ms after R-peak
    search_start_offset = round(0.080 * fs);
    
    for i = 1:length(ecg_peaks)
        win_start = ecg_peaks(i) + search_start_offset;
        win_end = min(n, ecg_peaks(i) + max_ptt);
        
        if win_start >= win_end || win_start >= n
            continue;
        end
        
        win_idx = win_start:win_end;
        deriv_win = ppg_deriv(win_idx);
        ppg_win = ppg_search(win_idx);
        
        % Find peaks via derivative zero-crossing
        peak_idx = [];
        for j = 2:length(deriv_win)
            if deriv_win(j-1) > 0 && deriv_win(j) <= 0
                peak_idx = [peak_idx; j]; %#ok<AGROW>
            end
        end
        
        found_via_derivative = false;
        local_peak_idx = [];
        
        if ~isempty(peak_idx)
            % Find largest peak above 50% threshold
            peak_vals = ppg_win(peak_idx);
            threshold = 0.5 * max(ppg_win);
            valid_peaks = peak_idx(peak_vals >= threshold);
            
            if ~isempty(valid_peaks)
                valid_vals = ppg_win(valid_peaks);
                [~, best_idx] = max(valid_vals);
                local_peak_idx = valid_peaks(best_idx);
                found_via_derivative = true;
            else
                [~, best_idx] = max(peak_vals);
                local_peak_idx = peak_idx(best_idx);
                found_via_derivative = true;
            end
        end
        
        if isempty(local_peak_idx)
            [~, local_peak_idx] = max(ppg_win);
        end
        
        ppg_peak = win_start + local_peak_idx - 1;
        ptt = ppg_peak - ecg_peaks(i);
        
        ppg_peaks(i) = ppg_peak;
        ptt_vals(i) = ptt;
        
        % Validate: PTT must be 120-500ms
        if found_via_derivative
            ptt_valid(i) = (ptt >= min_ptt) && (ptt <= max_ptt);
        else
            is_interior = (local_peak_idx > 1) && (local_peak_idx < length(ppg_win));
            ptt_valid(i) = (ptt >= min_ptt) && (ptt <= max_ptt) && is_interior;
        end
    end
end
