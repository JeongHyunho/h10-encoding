%% EMG Data Processing
% 이 스크립트는 EMG 데이터의 기본 처리를 수행합니다.
% 피험자별 EMG 데이터를 처리하여 emg_rs 구조체를 생성합니다.

function emg_rs = emg_data_processing(idx_info, sub_info, sub_pass, n_sub, dyn_offsets)
	% 환경 설정
	mfile_dir = fileparts(mfilename('fullpath'));
	if contains(mfile_dir,'Editor')
		mfile_dir = fileparts(matlab.desktop.editor.getActiveFilename);
	end
	cd(mfile_dir)
	
	run('../setup.m')
	data_dir = getenv('DATA_DIR');
	v3d_dir = getenv('V3D_PATH');
	
	% ─── 수동 skip 리스트 정의 ───
	% 특정 피험자, walk, dyn을 수동으로 skip하기 위한 리스트
	% 형식: {피험자ID, walk번호, dyn번호}
	manual_skip_list = {
		% 예시: {'S025', 17, 1},  % S025의 walk17, dyn_1을 skip
		% {'S030', 5, 2},        % S030의 walk5, dyn_2를 skip
		% 추가할 항목들을 여기에 작성
		{'S025', 17, 1}, ...
		{'S026', 1, 1}, ...
		{'S029', 16, 1},
	};
	
	% 병렬 처리 설정
	p = gcp('nocreate');
	if isempty(p), p = parpool("Processes", 6); end
	results_cell = {};
	
	% 피험자별 EMG 데이터 처리
	parfor i = 1+sub_pass:n_sub
		sub_name = sub_info.ID(i);
		sub_idx_info = idx_info.(sub_name);
		
		% 이 워커의 결과를 담을 임시 Cell 배열
		worker_results = cell(0, 3); % {sub_name, walk_name, processed_data}
		
		set_name = 'set2';
		if ismember(sub_name, ["S017", "S018"]), set_name = 'set1'; end
		
		walk_dirs = dir(fullfile(data_dir, 'c3d',sub_name, 'walk*'));
		for j = 1:numel(walk_dirs)
			walk = walk_dirs(j).name;
			reg_out = regexp(walk_dirs(j).name, '\d+$', 'match');
			walk_idx = str2double(reg_out{1});
			walk_dir = fullfile(walk_dirs(j).folder, walk_dirs(j).name);
			
			% 실험 조건 분류
			if ismember(walk_idx, sub_idx_info.non_exo)
				type = 'nat';
			elseif ismember(walk_idx, sub_idx_info.transparent)
				type = 'trans';
			elseif ismember(walk_idx, sub_idx_info.disc)
				type = 'disc';
			elseif ismember(walk_idx, sub_idx_info.cont)
				type = 'cont';
			else
				type = 'unknown';
				warning('[%s] Exceptional walk_idx(%d)!\n', sub_name, walk_idx)
			end
			
			c3d_dir = dir(fullfile(walk_dir, "*.c3d"));
			c3d_files = {c3d_dir.name};
			mvc_files = c3d_files(contains(lower(c3d_files), 'mvc'));
			
			% walk_rs 초기화
			walk_rs = struct();
			
			% V3D 경로에서 dyn 데이터 처리
			v3d_walk_dir = fullfile(v3d_dir, sub_name, walk);
			if exist(v3d_walk_dir, 'dir')
				emg_list = dir(fullfile(v3d_walk_dir, 'emg_exported_*.txt'));
				
				if ~isempty(emg_list)
					% 모든 emg_exported 파일들을 순서대로 처리하고 concatenate
					concatenated_rt = struct();
					concat_count = 0;
					for k = 1:numel(emg_list)
						% ─── 수동 skip 검증 ───
						% 현재 처리 중인 trial이 skip 리스트에 있는지 확인
						skip_this_trial = false;
						for skip_idx = 1:size(manual_skip_list, 1)
							skip_sub = manual_skip_list{skip_idx}{1};
							skip_walk = manual_skip_list{skip_idx}{2};
							skip_dyn = manual_skip_list{skip_idx}{3};
							
							if strcmp(sub_name, skip_sub) && walk_idx == skip_walk && k == skip_dyn
								fprintf('[EMG 인코딩] 수동 스킵: %s walk%d dyn_%d\n', sub_name, walk_idx, k);
								skip_this_trial = true;
								break;
							end
						end
						
						if skip_this_trial
							continue;
						end
						
						emg_file = fullfile(emg_list(k).folder, emg_list(k).name);
						% 빈/무효 EMG export 파일은 스킵
						if is_empty_emg_exported(emg_file)
							fprintf('[EMG 인코딩] 빈 emg_exported 스킵 (%s)\n', emg_list(k).name);
							continue
						end
						% 이벤트 데이터 읽기 (events_k.txt)
						evt_file = fullfile(emg_list(k).folder, sprintf('events_%d.txt', k));
						evt = struct();
						if exist(evt_file, 'file')
							try
								evt = read_events_struct(evt_file);
							catch ME
								fprintf('[EMG 인코딩] 이벤트 파싱 실패: %s\n   ↳ %s\n', evt_file, ME.message);
								evt = [];
							end
						else
							fprintf('[EMG 인코딩] 이벤트 파일 없음: %s\n', evt_file);
						end
						% evt를 전달하여 보행 단계/시간 정보 포함 처리
						rt = emg_dyn_process(emg_file, set_name, evt);
						
						% dyn 오프셋 적용: 절대 오프셋(offset_s)만큼 evt_time을 이동
						offset_rel = 0;
						tdms_k_local = NaN; % parfor 안전을 위해 매 반복에서 초기화
						if ~isempty(dyn_offsets)
							subj_match = strcmp(string(dyn_offsets.subject), string(sub_name));
							walk_match = strcmp(string(dyn_offsets.walk), string(walk));
							has_dyn_idx = ismember('dyn_idx', dyn_offsets.Properties.VariableNames);
							has_tdms_idx = ismember('tdms_idx', dyn_offsets.Properties.VariableNames);
							has_offset = ismember('offset_s', dyn_offsets.Properties.VariableNames);
							tdms_k_local = NaN;
							if has_dyn_idx && has_offset
								dyn_match_k = dyn_offsets.dyn_idx == k;
								row_idx = find(subj_match & walk_match & dyn_match_k, 1, 'first');
								if ~isempty(row_idx)
									offset_cur = dyn_offsets.offset_s(row_idx);
									if has_tdms_idx
										tdms_k_local = dyn_offsets.tdms_idx(row_idx);
									end
									offset_rel = offset_cur;
								end
							end
						end
						% evt_time에 offset 적용 및 tdms 인덱스 벡터 저장
						if isfield(rt, 'evt_time') && ~isempty(rt.evt_time)
							rt.evt_time = rt.evt_time + offset_rel;
							if numel(emg_list) > 1 && ~isnan(tdms_k_local)
								rt.evt_tdms_idx = repmat(tdms_k_local, size(rt.evt_time));
							else
								rt.evt_tdms_idx = [];
							end
						else
							rt.evt_tdms_idx = [];
						end
						
						if ~isempty(rt)
							% 첫 번째 파일이면 그대로 저장, 아니면 concatenate
							if concat_count == 0
								concatenated_rt = rt;
							else
								% 각 필드(근육 신호 및 메타데이터)를 규칙에 맞게 concatenate
								field_names = fieldnames(rt);
								for field_idx = 1:length(field_names)
									field_name = field_names{field_idx};
									new_val = rt.(field_name);
									if isvector(new_val)
										% 벡터(예: evt_time, stride_time, evt_tdms_idx): 세로 방향으로 이어 붙임 (열벡터로 맞춘 후 vercat)
										new_vec = new_val(:);
										if isfield(concatenated_rt, field_name)
											prev_vec = concatenated_rt.(field_name)(:);
											concatenated_rt.(field_name) = [prev_vec; new_vec];
										else
											concatenated_rt.(field_name) = new_vec;
										end
									else
										% 행렬(예: 정규화 EMG 301xN, stance_swing 301xN): 가로 방향으로 이어 붙임 (horzcat)
										if isfield(concatenated_rt, field_name)
											concatenated_rt.(field_name) = [concatenated_rt.(field_name), new_val];
										else
											concatenated_rt.(field_name) = new_val;
										end
									end
								end
							end
							concat_count = concat_count + 1;
						end
					end
					
					if concat_count > 0, walk_rs.dyn = concatenated_rt; end
					
					fprintf('[EMG 인코딩] %s walk#%d dyn (%d개 파일) 완료!\n', sub_name, walk_idx, numel(emg_list))
				end
			end
			
			% MVC trial 처리
			for k = 1:numel(c3d_dir)
				if contains(c3d_dir(k).name, 'static'), continue, end  % static 파일은 처리에서 제외
				if contains(c3d_dir(k).name, "dyn"), continue, end     % dyn 파일은 처리에서 제외 (V3D에서 처리됨)
				
				% MVC 파일만 처리
				if contains(c3d_dir(k).name, "mvc")
					mvc_idx = find(strcmp(c3d_dir(k).name, mvc_files));
					emg_case = sprintf('mvc%d', mvc_idx);
					
					c3d_file = fullfile(c3d_dir(k).folder, c3d_dir(k).name);
					c3d = ezc3dRead(char(c3d_file));
					
					rt = emg_mvc_process(c3d, set_name);
					if ~isempty(rt), walk_rs.(emg_case) = rt; end
					
					fprintf('[EMG 인코딩] %s walk#%d %s 완료!\n', sub_name, walk_idx, emg_case)
				end
			end
			
			worker_results(end+1, :) = {sub_name, walk, walk_rs};
		end
		
		% 이 워커가 처리한 모든 결과를 results_cell에 할당
		results_cell{i} = worker_results;
	end
	
	% 최종 구조체 조립
	emg_rs = struct();
	all_results = vertcat(results_cell{:});
	
	for i = 1:size(all_results, 1)
		sub_name = all_results{i, 1};
		walk_name = all_results{i, 2};
		data = all_results{i, 3};
		
		if ~isfield(emg_rs, sub_name)
			emg_rs.(sub_name) = struct();
		end
		emg_rs.(sub_name).(walk_name) = data;
	end
	
	p = gcp('nocreate');
	if ~isempty(p), delete(p), end
	
	% 결과 저장
	save(fullfile(data_dir, 'emg', 'emg_summary.mat'), 'emg_rs', '-v7.3')
	fprintf('EMG data processing completed. Results saved to emg_summary.mat\n');
end

% 내부 보조 함수: events_#.txt 파싱
function s = read_events_struct(evt_file)
% read events.txt
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
