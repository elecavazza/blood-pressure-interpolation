function simple_bp_validation_bhs()

    fprintf('========================================\n');
    fprintf('Simple BP Model Validation (BHS)\n');
    fprintf('========================================\n\n');

    %% STEP 1: Load Predictions
    predictions = load_predictions();
    fprintf('Loaded %d samples\n\n', height(predictions));

    %% STEP 2: Compute Errors
    sys_error = predictions.actual_sys - predictions.predicted_sys;
    dia_error = predictions.actual_dia - predictions.predicted_dia;

    %% STEP 3: Statistical Metrics

    % Systolic
    results.sys_mae = mean(abs(sys_error));
    results.sys_rmse = sqrt(mean(sys_error.^2));
    results.sys_r = corr(predictions.actual_sys, predictions.predicted_sys);

    % Diastolic
    results.dia_mae = mean(abs(dia_error));
    results.dia_rmse = sqrt(mean(dia_error.^2));
    results.dia_r = corr(predictions.actual_dia, predictions.predicted_dia);

    %% STEP 4: BHS Grading (Medical Evaluation)

    sys_abs = abs(sys_error);
    dia_abs = abs(dia_error);
    n = length(sys_error);

    % Percentages within thresholds
    results.sys_5 = sum(sys_abs <= 5) / n * 100;
    results.sys_10 = sum(sys_abs <= 10) / n * 100;
    results.sys_15 = sum(sys_abs <= 15) / n * 100;

    results.dia_5 = sum(dia_abs <= 5) / n * 100;
    results.dia_10 = sum(dia_abs <= 10) / n * 100;
    results.dia_15 = sum(dia_abs <= 15) / n * 100;

    % Grades
    results.sys_grade = get_bhs_grade(results.sys_5, results.sys_10, results.sys_15);
    results.dia_grade = get_bhs_grade(results.dia_5, results.dia_10, results.dia_15);

    %% STEP 5: Print Results

    fprintf('--- STATISTICAL RESULTS ---\n');

    fprintf('Systolic BP:\n');
    fprintf('  MAE  = %.2f mmHg\n', results.sys_mae);
    fprintf('  RMSE = %.2f mmHg\n', results.sys_rmse);
    fprintf('  r    = %.3f\n\n', results.sys_r);

    fprintf('Diastolic BP:\n');
    fprintf('  MAE  = %.2f mmHg\n', results.dia_mae);
    fprintf('  RMSE = %.2f mmHg\n', results.dia_rmse);
    fprintf('  r    = %.3f\n\n', results.dia_r);

    fprintf('--- BHS GRADING ---\n');

    fprintf('Systolic:\n');
    fprintf('  Within 5 mmHg  = %.1f%%\n', results.sys_5);
    fprintf('  Within 10 mmHg = %.1f%%\n', results.sys_10);
    fprintf('  Within 15 mmHg = %.1f%%\n', results.sys_15);
    fprintf('  Grade          = %s\n\n', results.sys_grade);

    fprintf('Diastolic:\n');
    fprintf('  Within 5 mmHg  = %.1f%%\n', results.dia_5);
    fprintf('  Within 10 mmHg = %.1f%%\n', results.dia_10);
    fprintf('  Within 15 mmHg = %.1f%%\n', results.dia_15);
    fprintf('  Grade          = %s\n\n', results.dia_grade);

end


%% ==============================
% LOAD DATA
% ==============================
function predictions = load_predictions()

    path1 = fullfile('..', 'output', 'model_predictions.csv');
    path2 = fullfile('output', 'model_predictions.csv');

    if exist(path1, 'file')
        predictions = readtable(path1);
    elseif exist(path2, 'file')
        predictions = readtable(path2);
    else
        error('Prediction file not found.');
    end

    % Ensure numeric
    predictions.actual_sys = double(predictions.actual_sys);
    predictions.predicted_sys = double(predictions.predicted_sys);
    predictions.actual_dia = double(predictions.actual_dia);
    predictions.predicted_dia = double(predictions.predicted_dia);
end


%% ==============================
% BHS GRADE FUNCTION
% ==============================
function grade = get_bhs_grade(p5, p10, p15)

    if p5 >= 60 && p10 >= 85 && p15 >= 95
        grade = 'A';
    elseif p5 >= 50 && p10 >= 75 && p15 >= 90
        grade = 'B';
    elseif p5 >= 40 && p10 >= 65 && p15 >= 85
        grade = 'C';
    else
        grade = 'D';
    end
end