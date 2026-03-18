%% h10 결과 정리
% 결과 리뷰 플롯 생성/저장
close all; clear
mp = mfilename('fullpath');
if contains(mp, 'AppData'),  mp = matlab.desktop.editor.getActiveFilename; end
cd(fileparts(mp));

run('setup.m')
data_dir = getenv('DATA_DIR');

load(fullfile(data_dir, 'export', 'enc_rs.mat'), 'rs')
param = rs.param;
sub_info = rs.sub_info;
sub_pass = rs.sub_pass;

n_sub = height(sub_info);
n = 301;
ph = linspace(0, 100, n);

%% review h10 data
close all

for i = 1+sub_pass:n_sub
    sub_name = sub_info.ID(i);
    idx_info = rs.(sub_name).idx_info;
    sub_rs = rs.(sub_name);
    sub_w = sub_rs.weight;

    rep_dir = fullfile(data_dir, 'h10', 'report', sub_name);
    if ~exist(rep_dir, 'dir'), mkdir(rep_dir), end

    % steady
    fd = fieldnames(sub_rs);
    fd_w = contains(fd, 'walk');
    walks = fd(fd_w);
    for j = 1:numel(walks)
        walk = walks{j};
        reg_out = regexp(walk, '\d+$', 'match');
        walk_idx = str2double(reg_out{1});

        walk_rs = sub_rs.(walk);
        if ~ismember('h10', fieldnames(walk_rs)), continue, end
        h10_rs = walk_rs.h10;

        st_t = mean(h10_rs.time, 2);
        if ismember(walk_idx, [idx_info.train; idx_info.disc; idx_info.non_exo; idx_info.transparent])
            w_type = 'disc';
            st_idx = st_t  >= st_t(end)-90 & st_t  <= st_t(end)-30;
        else
            w_type = 'cont';
            st_idx = true(size(h10_rs.time, 1), 1);
        end

        c_lines = parula(sum(st_idx));
        [~, c_idx] = sort(st_t(st_idx));
        c_lines = c_lines(c_idx, :);

        fh = figure('Name', sub_name, 'Position', [100, 100, 500, 1200], 'Visible', 'off');
        hold on
        for k = ["inc_deg", "jvel_deg", "tau_ref", "tau_act"]
            data_ = h10_rs.(k);
            data_ = data_(st_idx, :);
            % data_m = mean(data_, 1, 'omitmissing');
            % data_s = std(data_, [], 1, 'omitmissing');

            idx = find(ismember(["inc_deg", "jvel_deg", "tau_ref", "tau_act"], k));
            subplot(4, 1, idx)

            if ismember(k, ["tau_ref", "tau_act"]) data_ = data_ / sub_w; end

            % fill([ph, fliplr(ph)], [data_m - data_s; flipud(data_m + data_s)], [0.7 0.85 1], ...
            %     'EdgeColor', 'none', 'FaceAlpha', 0.35); hold on
            % plot(ph, data_m, 'k', "LineWidth", 1.0);

            for l = 1:size(data_, 1)
                plot(ph, data_(l, :), "Color", c_lines(l, :), "LineWidth", 1.0); hold on
            end

            switch idx
                case 1      % inc_deg
                    title(sprintf("%s-%s", sub_name, w_type))
                    ylim([-40, 60])
                    ylabel("Angle deg")
                case 2      % tau_ref
                    ylim([-200 400])
                    ylabel("Joint vel deg")
                case 3      % tau_ref
                    ylim([-0.2 0.2])
                    ylabel("\tau_{ref}")
                case 4      % tau_act
                    ylim([-0.2 0.2])
                    ylabel("\tau_{act}")
                    xlabel("phase (%)")
            end
        end

        saveas(fh, fullfile(data_dir, 'h10', 'report', sub_name, sprintf('%s-%s-%s.jpg', sub_name, walk, w_type)))
        close(fh)
    end
end

%% Review 3 by 3 cases
close all

flx_c = distinguishable_colors(3);

for fd = ["fric_pow_c", "fric_pow_v", "pow"]%["inc_deg", "jvel_deg", "tau_act", "fric_pow"]
    rep_dir = fullfile(data_dir, 'h10', 'report', fd);
    if ~exist(rep_dir, 'dir'), mkdir(rep_dir), end

    switch fd
        case "inc_deg"
            ylim_ = [-30, 70];
        case "jvel_deg"
            ylim_ = [-300, 500];
        case "tau_act"
            ylim_ = [-0.2, 0.2];
        case "fric_pow_c"
            ylim_ = [0, 1];
        case "fric_pow_v"
            ylim_ = [0, 1];
        case "pow"
            ylim_ = [-0.2, 1.1];
    end

    for i = 1+rs.sub_pass:rs.n_sub
        sub_name = sub_info.ID(i);
        sub_rs = rs.(sub_name);
        idx_info = sub_rs.idx_info;
        sub_rs = rs.(sub_name);

        fh = figure('Name', sub_name, 'Position', [100, 100, 900, 600], 'Visible', 'off');
        for walk_idx = idx_info.disc'
            walk = sprintf("walk%d", walk_idx);
            walk_rs = sub_rs.(walk);
            if ~ismember("h10", fieldnames(walk_rs)), continue, end
            if ~ismember("p", fieldnames(walk_rs)), continue, end
            h10_rs = sub_rs.(walk).h10;

            h10_t = mean(h10_rs.time, 2);
            if max(h10_t) < 120
                t_ss = true(size(h10_t));
            else
                t_end = h10_t(end);
                t_ss = t_end-120 < h10_t & h10_t < t_end-30;
            end
            data_ = h10_rs.(fd);
            data_m = mean(data_(t_ss, :), 1, 'omitmissing');
            data_s = std(data_(t_ss, :), [], 1, 'omitmissing');

            p = round(walk_rs.p, 2);
            r_idx = find(ismember([0.04, 0.11, 0.18], p(1)));
            c_idx = find(ismember([0.04, 0.11, 0.18], p(2)));
            if isempty(r_idx) | isempty(c_idx), continue, end

            subplot(3, 3, 3 * (r_idx-1) + c_idx)
            fill([ph, fliplr(ph)], [data_m - data_s, fliplr(data_m + data_s)], [0.7 0.85 1], ...
                'EdgeColor', 'none', 'FaceAlpha', 0.35); hold on
            plot(ph, data_m, 'Color', flx_c(r_idx, :), "LineWidth", c_idx);
            ax = gca;
            if ax.XLabel.String == ""
                xlabel(sprintf("walk%d, (%.2f, %.2f)", walk_idx, p(1), p(2)))
            else
                xlabel(sprintf("%s\nwalk%d, (%.2f, %.2f)", ax.XLabel.String, walk_idx, p(1), p(2)))
            end
            ylim(ylim_)

            switch 3*(r_idx-1) + c_idx
                case 1
                    title('\tau_{ext}=0.04')
                    ylabel('\tau_{flx}=0.04')
                case 2
                    title('\tau_{ext}=0.11')
                case 3
                    title('\tau_{ext}=0.18')
                case 4
                    ylabel('\tau_{flx}=0.11')
                case 5
                case 6
                case 7
                    ylabel('\tau_{flx}=0.18')
                case 8
                case 9
            end
        end

        saveas(fh, fullfile(data_dir, 'h10', 'report', fd, sprintf('%s.jpg', sub_name)))
        close(fh)
    end
end

