%% Insane check for encode_all.m inputs
% Reports issues in these categories:
% - File existence/duplicates: k5_missing, k5_multiple, fp_missing, fp_multiple,
%   h10_missing, h10_multiple, log_missing, log_multiple_noncont
% - H10 header: h10_missing_fields, h10_no_gait_stage, h10_no_record_time
% - EMG export: emg_missing
% - Path: v3d_path_missing
%
% Required rules (default):
% - K5 required unless eval_fail
% - H10/Log required unless non_exo
% - FP always required
% - EMG required unless eval_fail (emg_exported_*.txt under V3D_PATH)
%
% Outputs:
% - DATA_DIR/export/insane_check_all.csv
% - DATA_DIR/export/insane_check_issues.csv
close all; clear

mp = mfilename('fullpath');
if contains(mp, 'AppData'), mp = matlab.desktop.editor.getActiveFilename; end
cd(fileparts(mp));

run('setup.m')
data_dir = getenv('DATA_DIR');
if ~isfolder(data_dir)
    error('DATA_DIR not found: %s', data_dir);
end

sub_pass = 5;
require_gait_stage = true;
require_record_time = true;
check_emg_export = true;
require_emg = true;
v3d_dir = getenv('V3D_PATH');
v3d_ok = isfolder(v3d_dir);

opts = detectImportOptions("h10_param.csv");
opts = setvartype(opts, opts.VariableNames, "string");
param = readtable('h10_param.csv', opts);

opts = detectImportOptions("sub_info.csv");
opts = setvartype(opts, opts.VariableNames, "string");
sub_info = readtable('sub_info.csv', opts);

walks = param.Properties.VariableNames(2:end);

rows = cell(0, 19);

for i = sub_pass+1:height(sub_info)
    sub_name = string(sub_info.ID(i));
    idx_info = build_idx_info(sub_info(i, :));

    for j = 1:numel(walks)
        walk = walks{j};
        walk_val = string(param(i, :).(walk));
        if walk_val == "null"
            continue
        end

        walk_idx = str2double(regexp(walk, '\d+', 'match', 'once'));
        if isnan(walk_idx)
            walk_idx = j;
        end

        is_non_exo = ismember(walk_idx, idx_info.non_exo);
        is_eval_fail = ismember(walk_idx, idx_info.eval_fail);
        is_cont = ismember(walk_idx, idx_info.cont);
        is_disc = ismember(walk_idx, idx_info.disc);
        is_train = ismember(walk_idx, idx_info.train);
        is_trans = ismember(walk_idx, idx_info.transparent);

        trial_type = classify_trial(is_non_exo, is_trans, is_disc, is_cont, is_train);

        k5_required = ~is_eval_fail;
        fp_required = true;
        h10_required = ~is_non_exo;
        log_required = ~is_non_exo;
        emg_required = require_emg && ~is_eval_fail;

        k5_files = find_trial_files(data_dir, "k5", sub_name, walk, ".xlsx");
        fp_files = find_trial_files(data_dir, "fp", sub_name, walk, ".tdms");
        h10_files = find_trial_files(data_dir, "h10", sub_name, walk, ".csv");
        log_files = find_trial_files(data_dir, "log", sub_name, walk, ".tdms");

        k5_count = numel(k5_files);
        fp_count = numel(fp_files);
        h10_count = numel(h10_files);
        log_count = numel(log_files);

        h10_has_gait_stage = false;
        h10_has_record_time = false;
        h10_has_required_fields = false;
        if h10_count > 0
            var_names = get_header_names(h10_files(1));
            h10_has_gait_stage = any(var_names == "Gait_Stage");
            h10_has_record_time = any(var_names == "Record_Time");
            req_fields = ["loopCnt", "incPosDeg_RH", "incPosDeg_LH", ...
                "MotorRefCurrent_RH", "MotorActCurrent_RH", ...
                "MotorRefCurrent_LH", "MotorActCurrent_LH"];
            h10_has_required_fields = all(ismember(req_fields, var_names));
        end

        emg_export_count = NaN;
        if check_emg_export
            if v3d_ok
                v3d_walk_dir = fullfile(v3d_dir, char(sub_name), char(string(walk)));
                if isfolder(v3d_walk_dir)
                    emg_export_count = numel(dir(fullfile(v3d_walk_dir, 'emg_exported_*.txt')));
                else
                    emg_export_count = 0;
                end
            else
                emg_export_count = -1;
            end
        end

        issues = strings(0, 1);
        if k5_required && k5_count == 0
            issues(end+1) = "k5_missing";
        end
        if k5_count > 1
            issues(end+1) = "k5_multiple";
        end
        if fp_required && fp_count == 0
            issues(end+1) = "fp_missing";
        end
        if fp_count > 1
            issues(end+1) = "fp_multiple";
        end
        if h10_required && h10_count == 0
            issues(end+1) = "h10_missing";
        end
        if h10_count > 1
            issues(end+1) = "h10_multiple";
        end
        if h10_count > 0 && ~h10_has_required_fields
            issues(end+1) = "h10_missing_fields";
        end
        if require_gait_stage && h10_count > 0 && ~h10_has_gait_stage
            issues(end+1) = "h10_no_gait_stage";
        end
        if require_record_time && h10_count > 0 && ~h10_has_record_time
            issues(end+1) = "h10_no_record_time";
        end
        if log_required && log_count == 0
            issues(end+1) = "log_missing";
        end
        if log_count > 1 && ~is_cont
            issues(end+1) = "log_multiple_noncont";
        end
        if check_emg_export && ~v3d_ok
            issues(end+1) = "v3d_path_missing";
        end
        if emg_required && emg_export_count == 0
            issues(end+1) = "emg_missing";
        end

        issue_str = strjoin(issues, ";");

        rows(end+1, :) = { ...
            sub_name, string(walk), walk_idx, trial_type, walk_val, ...
            k5_count, fp_count, h10_count, log_count, emg_export_count, ...
            k5_required, fp_required, h10_required, log_required, emg_required, ...
            h10_has_gait_stage, h10_has_record_time, h10_has_required_fields, ...
            issue_str ...
            };
    end
end

col_names = { ...
    'subject', 'walk', 'walk_idx', 'trial_type', 'param_value', ...
    'k5_count', 'fp_count', 'h10_count', 'log_count', 'emg_export_count', ...
    'k5_required', 'fp_required', 'h10_required', 'log_required', 'emg_required', ...
    'h10_has_gait_stage', 'h10_has_record_time', 'h10_has_required_fields', ...
    'issues' ...
    };
results = cell2table(rows, 'VariableNames', col_names);

issues = results(results.issues ~= "", :);

export_dir = fullfile(data_dir, 'export');
if ~isfolder(export_dir)
    mkdir(export_dir);
end
writetable(results, fullfile(export_dir, 'insane_check_all.csv'));
if ~isempty(issues)
    writetable(issues, fullfile(export_dir, 'insane_check_issues.csv'));
end

fprintf('Total trials: %d\n', height(results));
fprintf('Trials with issues: %d\n', height(issues));
fprintf('Missing K5 (required): %d\n', sum(results.k5_required & results.k5_count == 0));
fprintf('Missing FP: %d\n', sum(results.fp_required & results.fp_count == 0));
fprintf('Missing H10 (required): %d\n', sum(results.h10_required & results.h10_count == 0));
fprintf('Missing Log (required): %d\n', sum(results.log_required & results.log_count == 0));
fprintf('Missing EMG export (required): %d\n', sum(results.emg_required & results.emg_export_count == 0));

%% helpers
function idx_info = build_idx_info(row)
idx_info = struct();
idx_info.non_exo = parse_idx_list(row.non_exo);
idx_info.transparent = parse_idx_list(row.transparent);
idx_info.train = parse_idx_list(row.disc_train);
idx_info.disc = parse_idx_list(row.disc_eval);
idx_info.cont = parse_idx_list(row.cont_eval);
idx_info.eval_fail = parse_idx_list(row.eval_fail);
idx_info.stand_fail = parse_idx_list(row.stand_fail);
end

function idx = parse_idx_list(val)
if ismissing(val) || strlength(strtrim(string(val))) == 0
    idx = [];
    return
end
parts = split(string(val));
idx = str2double(parts);
idx = idx(~isnan(idx));
end

function trial_type = classify_trial(is_non_exo, is_trans, is_disc, is_cont, is_train)
if is_non_exo
    trial_type = "non_exo";
elseif is_trans
    trial_type = "transparent";
elseif is_disc
    trial_type = "disc";
elseif is_cont
    trial_type = "cont";
elseif is_train
    trial_type = "train";
else
    trial_type = "unknown";
end
end

function files = find_trial_files(data_dir, sub_dir, sub_name, walk, ext)
walk_str = char(string(walk));
ext_str = char(string(ext));
sub_dir = char(string(sub_dir));
sub_name = char(string(sub_name));

pattern_glob = sprintf('%s*%s', walk_str, ext_str);
dir_list = dir(fullfile(data_dir, sub_dir, sub_name, pattern_glob));
pattern_re = ['^', walk_str, '(_\d+)?', regexptranslate('escape', ext_str), '$'];
files = dir_list(arrayfun(@(x) ~isempty(regexp(x.name, pattern_re, 'once')), dir_list));
end

function var_names = get_header_names(file_info)
file_path = fullfile(file_info.folder, file_info.name);
opts = detectImportOptions(file_path);
var_names = string(opts.VariableNames);
end
