%% Blood Pressure Data Reader and Cleaner - MATLAB Version
% 
% This script reads ECG/PPG data from Excel files in the Non Intrusive BP Dataset
% and cleans it for further processing.
%
% Data Structure:
% - 11 subjects, each with an Excel file containing multiple sheets
% - Each sheet represents a time period with ECG and PPG measurements
% - First row contains SYS (systolic) and DIA (diastolic) blood pressure
% - Subsequent rows contain only ECG and PPG values
%
% Author: Elena Cavazza
% Date: 2026

function cleaned_data = target_1_data_washing()
    %% Main entry point for data loading and cleaning
    
    fprintf('============================================================\n');
    fprintf('Blood Pressure Data Reader and Cleaner (MATLAB)\n');
    fprintf('============================================================\n\n');
    
    % Set the data directory (relative to workspace)
    data_dir = fullfile('../data/Non Intrusive BP Dataset');
    
    % Check if running from matlab folder or project root
    if ~exist(data_dir, 'dir')
        data_dir = fullfile('data', 'Non Intrusive BP Dataset');
    end
    
    % Load all data
    cleaned_data = load_all_data(data_dir);
    
    if isempty(cleaned_data)
        fprintf('No data loaded!\n');
        return;
    end
    
    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('Data Summary\n');
    fprintf('============================================================\n');
    
    % Get summary statistics
    stats = get_summary_stats(cleaned_data);
    
    fprintf('Total records: %d\n', stats.total_records);
    fprintf('Number of subjects: %d\n', stats.num_subjects);
    fprintf('\n');
    
    fprintf('Records per subject:\n');
    subjects = unique(cleaned_data.subject_id);
    for i = 1:length(subjects)
        count = sum(strcmp(cleaned_data.subject_id, subjects{i}));
        fprintf('  %s: %d records\n', subjects{i}, count);
    end
    fprintf('\n');
    
    fprintf('Signal ranges:\n');
    fprintf('  ECG: %.2f - %.2f\n', stats.ecg_range(1), stats.ecg_range(2));
    fprintf('  PPG: %.2f - %.2f\n', stats.ppg_range(1), stats.ppg_range(2));
    fprintf('\n');
    
    fprintf('Signal units by subject:\n');
    for i = 1:length(subjects)
        idx = find(strcmp(cleaned_data.subject_id, subjects{i}), 1);
        fprintf('  %s: ECG=%s, PPG=%s\n', subjects{i}, ...
            cleaned_data.ecg_unit{idx}, cleaned_data.ppg_unit{idx});
    end
    fprintf('\n');
    
    fprintf('Blood pressure ranges:\n');
    fprintf('  Systolic: %.0f - %.0f mmHg\n', stats.sys_range(1), stats.sys_range(2));
    fprintf('  Diastolic: %.0f - %.0f mmHg\n', stats.dia_range(1), stats.dia_range(2));
    fprintf('\n');
    
    fprintf('Data columns: ');
    fprintf('%s ', cleaned_data.Properties.VariableNames{:});
    fprintf('\n\n');
    
    fprintf('Sample data (first 10 rows):\n');
    disp(head(cleaned_data, 10));
    fprintf('\n');
    
    % Save cleaned data
    output_path = '../output/cleaned_bp_data.csv';
    writetable(cleaned_data, output_path);
    fprintf('Cleaned data saved to: %s\n', output_path);
end

%% Get Subject Files
function subjects = get_subject_files(data_dir)
    % Find all subject Excel files in the dataset directory.
    %
    % Args:
    %     data_dir: Path to the dataset directory
    %
    % Returns:
    %     Cell array of structs with 'subject_id' and 'file_path' fields
    
    subjects = {};
    
    if ~exist(data_dir, 'dir')
        error('Dataset directory not found: %s', data_dir);
    end
    
    % Get list of subdirectories
    items = dir(data_dir);
    items = items([items.isdir]);  % Only directories
    items = items(~ismember({items.name}, {'.', '..'}));  % Remove . and ..
    
    % Sort by name
    [~, idx] = sort({items.name});
    items = items(idx);
    
    for i = 1:length(items)
        subject_dir = fullfile(data_dir, items(i).name);
        dir_name = items(i).name;
        
        % Extract subject ID from directory name (e.g., "B030816 S6" -> "S6")
        parts = strsplit(dir_name, ' ');
        if length(parts) > 1
            subject_id = parts{end};
        else
            subject_id = dir_name;
        end
        
        % Find Excel files
        excel_files = dir(fullfile(subject_dir, '*.xlsx'));
        
        if ~isempty(excel_files)
            subjects{end+1} = struct(...
                'subject_id', subject_id, ...
                'file_path', fullfile(subject_dir, excel_files(1).name));
        end
    end
end

%% Parse Sheet
function parsed_data = parse_sheet(file_path, sheet_name)
    % Parse a single sheet from the Excel file.
    %
    % The data format is:
    % - Row 0: TIME/DATE, ECG value, PPG value, SYS, DIA, (optional PULSE)
    % - Row 1+: TIME, ECG value, PPG value (no BP readings)
    %
    % Args:
    %     file_path: Path to the Excel file
    %     sheet_name: Name of the sheet
    %
    % Returns:
    %     Table with standardized columns
    
    % Initialize empty table
    parsed_data = table();
    
    try
        % Read raw data including headers
        [~, ~, raw] = xlsread(file_path, sheet_name);
    catch
        % Try readcell for newer MATLAB versions
        try
            raw = readcell(file_path, 'Sheet', sheet_name);
        catch
            return;
        end
    end
    
    if isempty(raw)
        return;
    end
    
    % Initialize output arrays
    dates = {};
    times = {};
    ecg_vals = [];
    ppg_vals = [];
    sys_vals = [];
    dia_vals = [];
    pulse_vals = [];
    sheets = {};
    
    % Process each row
    for row_idx = 1:size(raw, 1)
        row = raw(row_idx, :);
        
        row_data = struct('date', [], 'time', [], 'ecg', NaN, 'ppg', NaN, ...
                          'sys', NaN, 'dia', NaN, 'pulse', NaN);
        
        col = 1;
        while col <= length(row)
            val = row{col};
            
            if ischar(val) || isstring(val)
                val_upper = upper(strrep(char(val), ':', ''));
                
                if strcmp(val_upper, 'DATE')
                    if col + 1 <= length(row)
                        row_data.date = row{col + 1};
                        col = col + 2;
                        continue;
                    end
                    
                elseif strcmp(val_upper, 'TIME')
                    if col + 1 <= length(row)
                        row_data.time = row{col + 1};
                        col = col + 2;
                        continue;
                    end
                    
                elseif strcmp(val_upper, 'ECG')
                    if col + 1 <= length(row)
                        row_data.ecg = convert_to_numeric(row{col + 1});
                        col = col + 2;
                        continue;
                    end
                    
                elseif strcmp(val_upper, 'PPG')
                    if col + 1 <= length(row)
                        row_data.ppg = convert_to_numeric(row{col + 1});
                        col = col + 2;
                        continue;
                    end
                    
                elseif strcmp(val_upper, 'SYS')
                    if col + 1 <= length(row)
                        row_data.sys = convert_to_numeric(row{col + 1});
                        col = col + 2;
                        continue;
                    end
                    
                elseif strcmp(val_upper, 'DIA')
                    if col + 1 <= length(row)
                        row_data.dia = convert_to_numeric(row{col + 1});
                        col = col + 2;
                        continue;
                    end
                    
                elseif strcmp(val_upper, 'PULSE')
                    if col + 1 <= length(row)
                        row_data.pulse = convert_to_numeric(row{col + 1});
                        col = col + 2;
                        continue;
                    end
                end
            end
            
            col = col + 1;
        end
        
        % Only add if we have ECG data
        if ~isnan(row_data.ecg)
            dates{end+1} = convert_date_to_string(row_data.date);
            times{end+1} = convert_time_to_string(row_data.time);
            ecg_vals(end+1) = row_data.ecg;
            ppg_vals(end+1) = row_data.ppg;
            
            % Only first row has BP readings
            if row_idx == 1
                sys_vals(end+1) = row_data.sys;
                dia_vals(end+1) = row_data.dia;
                pulse_vals(end+1) = row_data.pulse;
            else
                sys_vals(end+1) = NaN;
                dia_vals(end+1) = NaN;
                pulse_vals(end+1) = NaN;
            end
            
            sheets{end+1} = sheet_name;
        end
    end
    
    % Create table if we have data
    if ~isempty(ecg_vals)
        parsed_data = table(dates', times', ecg_vals', ppg_vals', ...
                           sys_vals', dia_vals', pulse_vals', sheets', ...
                           'VariableNames', {'date', 'time', 'ecg', 'ppg', ...
                                            'sys', 'dia', 'pulse', 'sheet'});
    end
end

%% Read Subject Data
function subject_data = read_subject_data(file_path, subject_id)
    % Read all sheets from a subject's Excel file.
    %
    % Args:
    %     file_path: Path to the Excel file
    %     subject_id: Subject identifier
    %
    % Returns:
    %     Table with all data from all sheets
    
    subject_data = table();
    
    try
        % Get sheet names
        [~, sheets] = xlsfinfo(file_path);
    catch
        warning('Could not read file: %s', file_path);
        return;
    end
    
    all_sheets = {};
    
    for i = 1:length(sheets)
        sheet_name = sheets{i};
        parsed = parse_sheet(file_path, sheet_name);
        
        if ~isempty(parsed) && height(parsed) > 0
            all_sheets{end+1} = parsed;
        end
    end
    
    % Combine all sheets
    if ~isempty(all_sheets)
        subject_data = vertcat(all_sheets{:});
        
        % Add subject ID column
        subject_ids = repmat({subject_id}, height(subject_data), 1);
        subject_data.subject_id = subject_ids;
    end
end

%% Detect Signal Units
function df = detect_signal_units(df)
    % Detect and label the signal units (mV vs ADC) for each subject.
    %
    % The dataset contains two types of signal values:
    % - mV (millivolts): preprocessed values, ECG typically 0.69-4.06, PPG 3.99-8.29
    % - ADC (raw counts): unprocessed values, ECG typically 70-660, PPG 339-907
    %
    % Threshold of 20 is used because:
    % - All mV values are below 10 (max observed: 8.29)
    % - All ADC values are above 70 (min observed: 70)
    %
    % Args:
    %     df: Table with ecg and ppg columns
    %
    % Returns:
    %     Table with added ecg_unit and ppg_unit columns
    
    if isempty(df)
        return;
    end
    
    % Initialize unit columns
    n_rows = height(df);
    ecg_unit = repmat({''}, n_rows, 1);
    ppg_unit = repmat({''}, n_rows, 1);
    
    % Detect units per subject based on max values
    subjects = unique(df.subject_id);
    for i = 1:length(subjects)
        mask = strcmp(df.subject_id, subjects{i});
        subject_ecg = df.ecg(mask);
        subject_ppg = df.ppg(mask);
        
        % ECG unit detection: mV < 20, ADC >= 20
        subject_ecg_valid = subject_ecg(~isnan(subject_ecg));
        if ~isempty(subject_ecg_valid)
            ecg_max = max(subject_ecg_valid);
            if ecg_max < 20
                ecg_unit(mask) = {'mV'};
            else
                ecg_unit(mask) = {'ADC'};
            end
        else
            ecg_unit(mask) = {'unknown'};
        end
        
        % PPG unit detection: mV < 20, ADC >= 20
        subject_ppg_valid = subject_ppg(~isnan(subject_ppg));
        if ~isempty(subject_ppg_valid)
            ppg_max = max(subject_ppg_valid);
            if ppg_max < 20
                ppg_unit(mask) = {'mV'};
            else
                ppg_unit(mask) = {'ADC'};
            end
        else
            ppg_unit(mask) = {'unknown'};
        end
    end
    
    df.ecg_unit = ecg_unit;
    df.ppg_unit = ppg_unit;
end

%% Clean Data
function cleaned = clean_data(df)
    % Clean and standardize the data.
    %
    % Operations:
    % - Remove rows with missing ECG/PPG values
    % - Detect and label signal units (mV vs ADC)
    % - Sort by subject, sheet, and time
    %
    % Args:
    %     df: Raw table
    %
    % Returns:
    %     Cleaned table
    
    if isempty(df)
        cleaned = df;
        return;
    end
    
    cleaned = df;
    
    % Remove rows where both ECG and PPG are NaN
    valid_rows = ~(isnan(cleaned.ecg) & isnan(cleaned.ppg));
    cleaned = cleaned(valid_rows, :);
    
    % Detect signal units (mV vs ADC)
    cleaned = detect_signal_units(cleaned);
    
    % Convert sheet to numeric for sorting
    sheet_nums = str2double(cleaned.sheet);
    
    % Sort by subject_id, sheet number, then time
    [~, sort_idx] = sortrows([cleaned.subject_id, num2cell(sheet_nums)]);
    cleaned = cleaned(sort_idx, :);
end

%% Load All Data
function cleaned_data = load_all_data(data_dir)
    % Load and clean data from all subjects.
    %
    % Args:
    %     data_dir: Path to the dataset directory
    %
    % Returns:
    %     Table with all cleaned data
    
    subjects = get_subject_files(data_dir);
    
    if isempty(subjects)
        error('No subject files found in %s', data_dir);
    end
    
    fprintf('Found %d subjects\n', length(subjects));
    
    all_data = {};
    
    for i = 1:length(subjects)
        subject = subjects{i};
        fprintf('  Loading %s...\n', subject.subject_id);
        
        subject_df = read_subject_data(subject.file_path, subject.subject_id);
        
        if ~isempty(subject_df) && height(subject_df) > 0
            all_data{end+1} = subject_df;
            num_sheets = length(unique(subject_df.sheet));
            fprintf('    -> %d records from %d sheets\n', height(subject_df), num_sheets);
        end
    end
    
    if ~isempty(all_data)
        combined = vertcat(all_data{:});
        cleaned_data = clean_data(combined);
    else
        cleaned_data = table();
    end
end

%% Get Summary Statistics
function stats = get_summary_stats(df)
    % Get summary statistics for the dataset.
    %
    % Args:
    %     df: Cleaned table
    %
    % Returns:
    %     Struct with summary statistics
    
    if isempty(df)
        stats = struct();
        return;
    end
    
    stats = struct();
    stats.total_records = height(df);
    stats.num_subjects = length(unique(df.subject_id));
    stats.ecg_range = [min(df.ecg), max(df.ecg)];
    stats.ppg_range = [min(df.ppg), max(df.ppg)];
    
    % BP ranges (ignoring NaN)
    sys_valid = df.sys(~isnan(df.sys));
    dia_valid = df.dia(~isnan(df.dia));
    
    if ~isempty(sys_valid)
        stats.sys_range = [min(sys_valid), max(sys_valid)];
    else
        stats.sys_range = [NaN, NaN];
    end
    
    if ~isempty(dia_valid)
        stats.dia_range = [min(dia_valid), max(dia_valid)];
    else
        stats.dia_range = [NaN, NaN];
    end
end

%% Helper Functions
function num_val = convert_to_numeric(val)
    % Convert a value to numeric, returning NaN if not possible
    if isnumeric(val)
        num_val = val;
    elseif ischar(val) || isstring(val)
        num_val = str2double(val);
    elseif ismissing(val)
        num_val = NaN;
    else
        num_val = NaN;
    end
end

function str_val = convert_date_to_string(val)
    % Convert an Excel serial date number to YYYY-MM-DD string format
    % Excel serial numbers: 42590 represents 2016-08-08
    if ischar(val)
        str_val = val;
    elseif isstring(val)
        str_val = char(val);
    elseif isnumeric(val)
        if isnan(val) || isempty(val)
            str_val = '';
        else
            % Excel serial date conversion
            % Excel uses 1900-01-00 as day 0 (with a bug for 1900 leap year)
            % MATLAB's datenum uses different epoch
            % Excel serial date 42590 = 2016-08-08
            try
                % Convert Excel serial date to MATLAB datenum
                % Excel epoch: 1899-12-30 (accounting for Excel's leap year bug)
                matlab_datenum = val + datenum('1899-12-30');
                str_val = datestr(matlab_datenum, 'yyyy-mm-dd');
            catch
                str_val = num2str(val);
            end
        end
    elseif isdatetime(val)
        str_val = datestr(val, 'yyyy-mm-dd');
    elseif ismissing(val)
        str_val = '';
    else
        try
            str_val = char(val);
        catch
            str_val = '';
        end
    end
end

function str_val = convert_time_to_string(val)
    % Convert an Excel serial time number to HH:MM:SS string format
    % Excel serial time: 0.75927 represents ~18:13:21
    if ischar(val)
        str_val = val;
    elseif isstring(val)
        str_val = char(val);
    elseif isnumeric(val)
        if isnan(val) || isempty(val)
            str_val = '';
        else
            % Excel stores time as fraction of a day
            % 0.75927 = 75.927% of 24 hours = ~18:13:21
            try
                % Convert fractional day to time string
                % If value > 1, it contains both date and time, extract only time portion
                time_fraction = mod(val, 1);
                str_val = datestr(time_fraction, 'HH:MM:SS');
            catch
                str_val = num2str(val);
            end
        end
    elseif isdatetime(val)
        str_val = datestr(val, 'HH:MM:SS');
    elseif ismissing(val)
        str_val = '';
    else
        try
            str_val = char(val);
        catch
            str_val = '';
        end
    end
end
