%% EMG 채널 필터링
% 이 스크립트는 실패(불합격)한 EMG 채널의 데이터를 NaN으로 대체하고,
% 이상 보폭(outlier stride)을 제거하는 후처리를 수행합니다.
%
% dyn 신호는 stride 세그먼테이션 전(시간 연속 신호 concat) 상태이므로
% 여기서는 보폭(outlier stride) 제거를 수행하지 않음

function emg_proc = emg_channel_filtering(emg_rs)
    % 환경 설정
    mfile_dir = fileparts(mfilename('fullpath'));
    if contains(mfile_dir,'Editor')
        mfile_dir = fileparts(matlab.desktop.editor.getActiveFilename);
    end
    cd(mfile_dir)
    
    run('../../setup.m')
    data_dir = getenv('DATA_DIR');
    
    % 처리용으로 emg_rs의 깊은 복사본 생성
    emg_proc = emg_rs;
    
    % 채널 합격/불합격 정보 테이블 로드
    csv_file = fullfile(mfile_dir, '../emg_channel_success.csv');
    T_channels = readtable(csv_file, 'TextType', 'string');
    
    % 테이블(T_channels)의 각 행(피험자-보행 조합) 순회
    for i = 1:height(T_channels)
        sub_name = T_channels.sub_name(i);
        walk = T_channels.walk(i);
        
        % 세트 기준 근육 리스트 정의는 아래에서 자동 추정
        
        % 대상 피험자/보행이 emg_proc에 없으면 스킵
        if ~isfield(emg_proc, sub_name) || ~isfield(emg_proc.(sub_name), walk)
            continue
        end
        
        % 해당 보행의 동적 케이스는 concat된 단일 'dyn'만 존재
        walk_data = emg_proc.(sub_name).(walk);
        if ~isfield(walk_data, 'dyn') || ~isstruct(walk_data.dyn)
            continue
        end
        emg_case = 'dyn';
        
        % 세트 기준 근육 리스트 자동 추정 (emg_proc의 실제 필드 기반)
        set1_list = {'VM', 'VL', 'RF1', 'RF2', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};
        set2_list = {'VM1', 'VM2', 'VL', 'RF', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};
        aux_fields = {'stance_swing','stride_time','iemg','norm_factors','cci','activation'};
        present_fields = fieldnames(walk_data.(emg_case));
        present_fields = present_fields(~ismember(present_fields, aux_fields));
        cnt1 = sum(ismember(set1_list, present_fields));
        cnt2 = sum(ismember(set2_list, present_fields));
        if cnt1 > cnt2
            mc_list = set1_list;
        elseif cnt2 > cnt1
            mc_list = set2_list;
        else
            % 동률이면 피험자 ID 휴리스틱
            if ismember(sub_name, ["S017","S018"])
                mc_list = set1_list;
            else
                mc_list = set2_list;
            end
        end
            
            % 채널 상태를 확인하고 필요 시 데이터 업데이트
            % T_channels의 변수명 중 ch1~ch10 목록 추출
            channel_list = T_channels.Properties.VariableNames(contains(T_channels.Properties.VariableNames, 'ch'));
            
            for ch_idx = 1:numel(channel_list)
                channel = channel_list{ch_idx};
                if T_channels.(channel)(i) == 0  % 불합격 채널인 경우
                    % 채널 번호 추출 (예: 'ch3' → 3)
                    ch_num = str2double(regexp(channel, '\d+', 'match', 'once'));
                    
                    % 고정 근육 리스트(mc_list) 기반 매핑 (세트별 일관된 ch→근육 매핑)
                    if ch_num <= numel(mc_list)
                        muscle_name = mc_list{ch_num};
                        if isfield(walk_data.(emg_case), muscle_name)
                            % 해당 근육 데이터 전체를 NaN으로 설정
                            data_size = size(emg_proc.(sub_name).(walk).(emg_case).(muscle_name));
                            emg_proc.(sub_name).(walk).(emg_case).(muscle_name) = nan(data_size);
                            fprintf('[%s] Set %s to NaN for %s %s (ch%d)\n', ...
                                sub_name, muscle_name, walk, emg_case, ch_num);
                        end
                    end
                end
            end
    end
    
    fprintf('EMG 데이터 복사 및 채널 필터링 적용 완료\n')
    
    % 후처리된 EMG 데이터 저장
    out_dir = fullfile(data_dir, 'emg');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    save(fullfile(out_dir, 'emg_proc.mat'), 'emg_proc', '-v7.3')
    fprintf('후처리된 EMG 데이터가 emg_proc.mat에 저장되었습니다\n')
end
