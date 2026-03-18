%% visual3d_result.m — Visual3D 역동역학 결과 정리
% V3D에서 내보낸 관절 토크·각도 데이터를 보행 주기별로 정규화하고
% 참여자·조건별 구조체(idyn_summary.mat)로 저장한다.
%
% 의존성:
%   - setup.m, config.m
%   - V3D_PATH의 exported_*.txt 파일
%
% 출력:
%   - DATA_DIR/export/idyn_summary.mat
close all; clear
mp = mfilename('fullpath');
if contains(mp, 'AppData'),  mp = matlab.desktop.editor.getActiveFilename; end
cd(fileparts(mp));

run('setup.m')
data_dir = getenv('DATA_DIR');
v3d_dir = getenv('V3D_PATH');
fprintf("Processed V3D Path: %s\n", v3d_dir)

opts = detectImportOptions("h10_param.csv");
opts = setvartype(opts, opts.VariableNames, "string");
param = readtable('h10_param.csv', opts);

opts = detectImportOptions("sub_info.csv");
opts = setvartype(opts, opts.VariableNames, "string");
sub_info = readtable('sub_info.csv', opts);

n_sub = height(sub_info);
sub_pass = 2;

%% 역동역학 데이터 정리

p = gcp('nocreate');
if isempty(p), p = parpool("Processes", 6); end

% parfor i = 1+sub_pass:n_sub
for i = [8, 16]%1+sub_pass:n_sub
    sub_name = sub_info.ID(i);
    sub_inv = struct();

    walk_folders = dir(fullfile(v3d_dir, sub_name, 'walk*'));
    if isempty(walk_folders)
        continue
    end

    % walking trial
    for j = 1:length(walk_folders)
        folder_name = walk_folders(j).folder;
        walk_name = walk_folders(j).name;

        reg_out = regexp(walk_name, '\d+$', 'match');
        walk_idx = reg_out{1};
        mcomp_list = dir(fullfile(folder_name, walk_name, 'model_computation_*.txt'));
        evt_list = dir(fullfile(folder_name, walk_name, 'events_*.txt'));
        rt_list = dir(fullfile(folder_name, walk_name, 'time_right_*.txt'));
        lt_list = dir(fullfile(folder_name, walk_name, 'time_left_*.txt'));

        % main processing
        fprintf("[%s] %s processing...", sub_name, walk_folders(j).name)
        for k = 1:numel(mcomp_list)
            mcomp_file = fullfile(mcomp_list(k).folder, mcomp_list(k).name);
            sub_inv.(['walk', walk_idx, '_', num2str(k)])= read_mcomp_struct(mcomp_file);
        end
        for k = 1:numel(evt_list)
            evt_file = fullfile(evt_list(k).folder, evt_list(k).name);
            sub_inv.(['walk', walk_idx, '_', num2str(k)]).evt = read_events_struct(evt_file);
        end
        % for k = 1:numel(rt_list)
        %     rt_file = fullfile(rt_list(k).folder, rt_list(k).name);
        %     sub_inv.(['walk', walk_idx, '_', num2str(k)]).right_time = read_mcomp_struct(rt_file).TIME.x;
        % end
        % for k = 1:numel(lt_list)
        %     lt_file = fullfile(lt_list(k).folder, lt_list(k).name);
        %     sub_inv.(['walk', walk_idx, '_', num2str(k)]).left_time = read_mcomp_struct(lt_file).TIME.x;
        % end

        fprintf(" done!\n")
    end

    fprintf("[%s] saving...", sub_name)
    var_saved = struct("sub_inv", sub_inv);
    save(fullfile(data_dir, 'c3d_v3d', sprintf('sub_inv_%s.mat', sub_name)), '-fromstruct', var_saved)
    fprintf(" done!\n")
end

p = gcp('nocreate');
if ~isempty(p), close(p), end

%% 역동역학 데이터 정리 (일부)
sub_name = "S008";
walk_name = "walk1";

for i = 1+sub_pass:n_sub
    if ~strcmp(sub_info.ID(i), sub_name), continue, end
    load(fullfile(data_dir, 'c3d_v3d', sprintf('sub_inv_%s.mat', sub_name)), 'sub_inv')

    walk_folders = dir(fullfile(v3d_dir, sub_name, 'walk*'));
    if isempty(walk_folders)
        continue
    end

    % walking trial
    for j = 1:length(walk_folders)
        folder_name = walk_folders(j).folder;
        if ~strcmp(walk_folders(j).name, walk_name), continue, end

        reg_out = regexp(walk_name, '\d+$', 'match');
        walk_idx = reg_out{1};
        mcomp_list = dir(fullfile(folder_name, walk_name, 'model_computation_*.txt'));
        evt_list = dir(fullfile(folder_name, walk_name, 'events_*.txt'));

        % main processing
        fprintf("[%s] %s processing...", sub_name, walk_folders(j).name)
        for k = 1:numel(mcomp_list)
            mcomp_file = fullfile(mcomp_list(k).folder, mcomp_list(k).name);
            sub_inv.(['walk', walk_idx, '_', num2str(k)])= read_mcomp_struct(mcomp_file);
        end
        for k = 1:numel(evt_list)
            evt_file = fullfile(evt_list(k).folder, evt_list(k).name);
            sub_inv.(['walk', walk_idx, '_', num2str(k)]).evt = read_events_struct(evt_file);
        end

        fprintf(" done!\n")
    end

    fprintf("[%s] saving...", sub_name)
    save(fullfile(data_dir, 'c3d_v3d', sprintf('sub_inv_%s.mat', sub_name)), 'sub_inv')
    fprintf(" done!\n")
end

%% whole file saving
inv_dyn = struct('path', v3d_dir);

for i = 1+sub_pass:n_sub
    sub_name = sub_info.ID(i);
    load(fullfile(data_dir, 'c3d_v3d', sprintf('sub_inv_%s.mat', sub_name)), 'sub_inv')
     inv_dyn.(sub_name) = sub_inv;
end

fprintf("saving...")
save(fullfile(data_dir, 'c3d_v3d', 'inv_dyn.mat'), 'inv_dyn', '-v7.3')
fprintf(" done! finished!\n")

%% Functions

function s = read_mcomp_struct(mcomp_file)
% read model_computation.txt
assert(exist(mcomp_file, 'file'))

s = struct();
rd = readcell(mcomp_file, 'Delimiter', '\t');
cat = rd(2, 2:end);

data_c = rd(6:end, 2:end);
missed = cellfun(@ismissing, data_c);
data_c(missed) = {nan};
data = cell2mat(data_c);

coord = rd(5, 2:end);
x_idx = strcmp(coord, 'X');
y_idx = strcmp(coord, 'Y');
z_idx = strcmp(coord, 'Z');

fields = unique(cat);
for i = 1:length(fields)
    f = fields{i};
    f_idx = strcmp(cat, f);

    s.(f).x = data(:, logical(x_idx .* f_idx));
    s.(f).y = data(:, logical(y_idx .* f_idx));
    s.(f).z = data(:, logical(z_idx .* f_idx));
end
end

function s = read_events_struct(evt_file)
% read events.txt
assert(exist(evt_file, 'file'))

s = struct();
rd = readcell(evt_file);
fields = rd(2, 2:end);
data_c = rd(6:end, 2:end);
missed = cellfun(@ismissing, data_c);
data_c(missed) = {nan};
data = cell2mat(data_c);

for i = 1:length(fields)
    f = fields{i};
    f_data = data(:, i);
    f_data = f_data(~isnan(f_data));    % remove nan

    switch f
        case 'Right Foot Off'
            s.rfo = f_data;
        case 'Right Foot Strike'
            s.rfs = f_data;
        case 'Left Foot Off'
            s.lfo = f_data;
        case 'Left Foot Strike'
            s.lfs = f_data;
    end
end
end
