%%% EMG Plot (Disc) - After Normalization
% 이 스크립트는 정규화된 EMG 데이터를 시각화하여 품질을 검증합니다.
% 정규화 전후를 비교하여 disc, non_exo, transparent, cont 조건의 EMG 신호를 plot합니다.

function emg_plot_disc(idx_info, emg_rs, emg_norm)
% 환경 설정
mfile_dir = fileparts(mfilename('fullpath'));
if contains(mfile_dir,'Editor')
    mfile_dir = fileparts(matlab.desktop.editor.getActiveFilename);
end
cd(mfile_dir)

run('../../setup.m')
data_dir = getenv('DATA_DIR');

muscle_names = {'VM', 'VM1', 'VM2', 'VL', 'RF', 'RF1', 'RF2', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};

% 병렬 처리 설정
p = gcp('nocreate');
if isempty(p), p = parpool("Processes", 6); end

subjects = fieldnames(emg_rs);
% parfor 브로드캐스트 부담을 줄이기 위해 피험자 단위로 슬라이스한 셀 배열 준비
n_sub = numel(subjects);
sub_emg_rs_list = cell(n_sub, 1);
sub_emg_norm_list = cell(n_sub, 1);
sub_idx_info_list = cell(n_sub, 1);
for s_i = 1:n_sub
    subn = subjects{s_i};
    if isfield(emg_rs, subn)
        sub_emg_rs_list{s_i} = emg_rs.(subn);
    else
        sub_emg_rs_list{s_i} = struct();
    end
    if isfield(emg_norm, subn)
        sub_emg_norm_list{s_i} = emg_norm.(subn);
    else
        sub_emg_norm_list{s_i} = struct();
    end
    if isfield(idx_info, subn)
        sub_idx_info_list{s_i} = idx_info.(subn);
    else
        sub_idx_info_list{s_i} = struct();
    end
end

% 피험자별 처리
% DataQueue 설정: 워커 로그를 메인 콘솔로 전송
q = parallel.pool.DataQueue;
afterEach(q, @(msg) fprintf('%s\n', msg));
parfor s = 1:numel(subjects)
    sub_name = subjects{s};
    sub_idx_info = sub_idx_info_list{s};
    sub_emg_rs = sub_emg_rs_list{s};
    sub_emg_norm = sub_emg_norm_list{s};

    % 피험자별 plot 디렉토리 생성
    send(q, sprintf('[EMG 플롯] %s 처리 시작', sub_name));
    plot_dir = fullfile(data_dir, 'emg', 'plot_disc', sub_name);
    if ~exist(plot_dir, 'dir'), mkdir(plot_dir), end

    walks = fieldnames(sub_emg_rs);
    for w = 1:numel(walks)
        walk_name = walks{w};
        reg_out = regexp(walk_name, '\d+$', 'match');
        walk_idx = str2double(reg_out{1});
        walk_data_rs = sub_emg_rs.(walk_name);
        walk_data_norm = sub_emg_norm.(walk_name);
        % walk 레벨 정규화 계수 로드(배경색 결정용)
        nf_day = struct();
        if isfield(sub_emg_norm.(walk_name), 'norm_factors')
            nf_day = sub_emg_norm.(walk_name).norm_factors;
        end

        % disc, non_exo, transparent 조건 선택
        walk_list = [sub_idx_info.disc; sub_idx_info.non_exo; sub_idx_info.transparent; sub_idx_info.cont];
        if ismember(walk_idx, walk_list)
            % emg_rs의 모든 필드명 중 "dyn"이 포함된 것만 선택
            all_cases = fieldnames(walk_data_rs);
            dyn_cases = all_cases(contains(all_cases, 'dyn'));

            for c = 1:numel(dyn_cases)
                emg_case = dyn_cases{c};

                % emg_rs와 emg_norm에서 해당 case 데이터 가져오기
                if isfield(walk_data_rs, emg_case) && isfield(walk_data_norm, emg_case)
                    emg_dat_rs = walk_data_rs.(emg_case);
                    emg_dat_norm = walk_data_norm.(emg_case);

                    if isstruct(emg_dat_rs) && isstruct(emg_dat_norm)
                        % 실패 채널 정보 로드 (emg_channel_success.csv)
                        csv_file = fullfile(mfile_dir, '../emg_channel_success.csv');
                        failed_muscles = string([]);
                        if exist(csv_file, 'file')
                            T_channels = readtable(csv_file, 'TextType', 'string');
                            row_idx = find(T_channels.sub_name == sub_name & T_channels.walk == string(walk_name), 1);
                            if ~isempty(row_idx)
                                % 세트 추정 (set1/set2)
                                set1_list = {'VM', 'VL', 'RF1', 'RF2', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};
                                set2_list = {'VM1', 'VM2', 'VL', 'RF', 'BF', 'ST', 'TA', 'GL', 'GM', 'SOL'};
                                aux_fields = {'stance_swing','stride_time','iemg','norm_factors','cci','activation'};
                                present_fields_all = fieldnames(emg_dat_rs);
                                present_fields = present_fields_all(~ismember(present_fields_all, aux_fields));
                                cnt1 = sum(ismember(set1_list, present_fields));
                                cnt2 = sum(ismember(set2_list, present_fields));
                                if cnt1 > cnt2
                                    mc_list = set1_list;
                                elseif cnt2 > cnt1
                                    mc_list = set2_list;
                                else
                                    if ismember(sub_name, ["S017","S018"])
                                        mc_list = set1_list;
                                    else
                                        mc_list = set2_list;
                                    end
                                end
                                % 실패(ch==0) 채널 → 근육명 매핑
                                channel_list = T_channels.Properties.VariableNames(contains(T_channels.Properties.VariableNames, 'ch'));
                                for ch_idx = 1:numel(channel_list)
                                    channel = channel_list{ch_idx};
                                    if T_channels.(channel)(row_idx) == 0
                                        ch_num = str2double(regexp(channel, '\d+', 'match', 'once'));
                                        if ch_num <= numel(mc_list)
                                            failed_muscles(end+1) = string(mc_list{ch_num}); %#ok<AGROW>
                                        end
                                    end
                                end
                            end
                        end
                        % 근육 필드만 선별 (보조 필드 제외)
                        all_fields = fieldnames(emg_dat_rs);
                        aux_fields = {'stance_swing','stride_time','iemg','norm_factors','cci','activation'};
                        candidate_fields = setdiff(all_fields, aux_fields);
                        % muscle_names 교집합 후 muscle_names 순서로 정렬
                        [~, idx] = ismember(muscle_names, candidate_fields);
                        idx = idx(idx > 0);
                        muscle_fields = candidate_fields(idx);

                        % 숫자 데이터이고 2차원 행렬이며 muscle_names에 있는 필드만 필터링
                        valid_muscle_fields = {};
                        for f = 1:numel(muscle_fields)
                            field_name = muscle_fields{f};
                            if isfield(emg_dat_rs, field_name)
                                field_data = emg_dat_rs.(field_name);
                                if isnumeric(field_data) && ndims(field_data) == 2 && ismember(field_name, muscle_names)
                                    valid_muscle_fields{end+1} = field_name;
                                end
                            end
                        end

                        n_muscles = numel(valid_muscle_fields);
                        if n_muscles == 0, continue, end

                        % figure 사이즈 동적 조정 (2열 구조)
                        fig_height = 100 * n_muscles; % 각 subplot당 100px 높이
                        fig_width = 1000; % 2열을 위해 너비 증가
                        figure('Visible', 'off', 'Position', [0, 0, fig_width, fig_height]);

                        for m = 1:n_muscles
                            muscle = valid_muscle_fields{m};

                            % 1열: emg_rs 데이터 (정규화 전)
                            data_mat_rs = emg_dat_rs.(muscle)'; % (stride x 301)
                            % 실패 채널 여부 플래그 (배경색 처리용)
                            isFailedChannel = any(failed_muscles == string(muscle));
                            n_stride = size(data_mat_rs, 1);
                            n_point = size(data_mat_rs, 2);

                            % outlier 재처리 없이 로드된 데이터 그대로 사용
                            mean_curve_rs = mean(data_mat_rs, 1, 'omitnan');

                            ax1 = subplot(n_muscles, 2, 2*m-1);
                            hold on;
                            % 모든 trial을 그대로 표시 (연회색)
                            for s_idx = 1:n_stride
                                plot(linspace(0,100,n_point), data_mat_rs(s_idx, :), 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
                            end
                            % 평균 (파란 실선)
                            plot(linspace(0,100,n_point), mean_curve_rs, 'b', 'LineWidth', 2);
                            ylabel(muscle, 'Interpreter', 'none');
                            if m == 1
                                title('Before Processing (emg_rs)', 'Interpreter', 'none');
                            end
                            if m == n_muscles
                                xlabel('Gait Cycle (%)');
                            end
                            grid on;
                            xlim([0 100]);
                            xticks(0:20:100);
                            % 실패 채널이면 배경 패치(좌측) 추가
                            if isFailedChannel
                                yL = get(ax1, 'YLim');
                                bg1 = patch('Parent', ax1, 'XData', [0 100 100 0], 'YData', [yL(1) yL(1) yL(2) yL(2)], ...
                                    'FaceColor', [0.95 0.95 0.95], 'EdgeColor', 'none');
                                uistack(bg1, 'bottom');
                            end
                            hold off;

                            % 2열: emg_norm 데이터 (정규화 후, 원본 필드 교체)
                            if isfield(emg_dat_norm, muscle)
                                data_mat_proc = emg_dat_norm.(muscle)'; % (stride x 301)
                                % 정규화 플롯(2열): outlier 재처리 없이 전부 표시
                                n_stride_proc = size(data_mat_proc, 1);
                                n_point_proc = size(data_mat_proc, 2);
                                mean_curve_proc = mean(data_mat_proc, 1, 'omitnan');

                                ax2 = subplot(n_muscles, 2, 2*m);
                                hold on;
                                % 모든 trial을 그대로 표시 (연회색)
                                for s_idx = 1:n_stride_proc
                                    plot(linspace(0,100,n_point_proc), data_mat_proc(s_idx, :), 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
                                end
                                % 평균 (파란 실선)
                                plot(linspace(0,100,n_point_proc), mean_curve_proc, 'b', 'LineWidth', 2);
                                if m == 1
                                    title('After Normalization (emg_norm)', 'Interpreter', 'none');
                                end
                                if m == n_muscles
                                    xlabel('Gait Cycle (%)');
                                end
                                grid on;
                                xlim([0 100]);
                                xticks(0:20:100);
                                ylim([0 2]); % 정규화 데이터는 [0,2]로 고정
                                % 활성도 통계(총/입각/유각) 텍스트 표기 (좌상단)
                                if isfield(emg_dat_norm, 'activation') && isfield(emg_dat_norm.activation, muscle) && ...
                                        isfield(emg_dat_norm.activation.(muscle), 'stats')
                                    ss_act = emg_dat_norm.activation.(muscle).stats;
                                    total_val = NaN; stance_val = NaN; swing_val = NaN;
                                    if isfield(ss_act, 'total_mean'), total_val = ss_act.total_mean; end
                                    if isfield(ss_act, 'stance_mean'), stance_val = ss_act.stance_mean; end
                                    if isfield(ss_act, 'swing_mean'), swing_val = ss_act.swing_mean; end
                                    txt = sprintf('활성도 T/S/Sw: %.2f / %.2f / %.2f', total_val, stance_val, swing_val);
                                    text(ax2, 0.01, 0.99, txt, 'Units','normalized', 'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 9, 'Color', 'k');
                                end
                                % 배경 패치(우측): norm_factors NaN → 옅은 빨강, 실패 채널 → 연회색
                                isNormNaN = false;
                                if ~isempty(fieldnames(nf_day)) && isfield(nf_day, muscle)
                                    isNormNaN = isnan(nf_day.(muscle));
                                end
                                if isNormNaN || isFailedChannel
                                    bgColor = isNormNaN * [1.0 0.9 0.9] + (~isNormNaN) * [0.95 0.95 0.95];
                                    yL2 = get(ax2, 'YLim');
                                    bg2 = patch('Parent', ax2, 'XData', [0 100 100 0], 'YData', [yL2(1) yL2(1) yL2(2) yL2(2)], ...
                                        'FaceColor', bgColor, 'EdgeColor', 'none');
                                    uistack(bg2, 'bottom');
                                end
                                hold off;
                            else
                                % 데이터가 없으면 빈 플롯
                                subplot(n_muscles, 2, 2*m);
                                text(50, 0.5, '정규화 데이터 없음', 'HorizontalAlignment', 'center');
                                if m == 1
                                    title('After Normalization (emg_norm)', 'Interpreter', 'none');
                                end
                                if m == n_muscles
                                    xlabel('Gait Cycle (%)');
                                end
                                grid on;
                                xlim([0 100]);
                                xticks(0:20:100);
                                ylim([0 2]); % 정규화 데이터는 [0,2]로 고정
                            end
                        end

                        % sgtitle에서 _를 공백으로 대체
                        sg_str = sprintf('%s - %s - %s', sub_name, walk_name, emg_case);
                        sg_str = strrep(sg_str, '_', ' ');
                        sgtitle(sg_str, 'Interpreter', 'none');

                        % 파일명 저장 (saveas 사용 + 색 반전 방지)
                        fname = sprintf('%s_%s_%s.png', sub_name, walk_name, emg_case);
                        set(gcf, 'InvertHardcopy', 'off');
                        saveas(gcf, fullfile(plot_dir, fname));
                        close;

                        % 완료 메시지 출력(DataQueue)
                        send(q, sprintf('[EMG 플롯] 저장 완료: %s - %s - %s', sub_name, walk_name, emg_case));
                    end
                end
            end
        end
    end
    % 피험자 처리 완료 알림
    send(q, sprintf('[EMG 플롯] %s 처리 완료', sub_name));
end

% 병렬 풀 정리
p = gcp('nocreate');
if ~isempty(p), delete(p), end

fprintf('EMG plot generation completed.\n');
end
