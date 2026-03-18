%% EE 데이터 확인
close all; clear

run('setup.m')
data_dir = getenv('DATA_DIR');
report_dir = fullfile(data_dir, 'report');

mon_pos = get(0, 'MonitorPositions');

% 데이터 로드
load(fullfile(data_dir, 'export', 'enc_rs.mat'), 'rs')

interval_stand = readtable('k5_arrange.xlsx', 'Sheet', 'stand');
interval_walk = readtable('k5_arrange.xlsx', 'Sheet', 'walk');

% standing ee report dir
standing_dir = fullfile(report_dir, 'standing');
if ~exist(standing_dir, 'dir'), mkdir(standing_dir); end

% subject report dir
for i = rs.sub_pass+1:rs.n_sub
    sub_name = rs.sub_info.ID(i);
    sub_rep = fullfile(report_dir, sub_name);
    if ~exist(sub_rep, 'dir'), mkdir(sub_rep); end
end

% disc/cont ee landscape dir
disc_rep = fullfile(report_dir, 'disc');
if ~exist(disc_rep, 'dir'), mkdir(disc_rep); end
cont_rep = fullfile(report_dir, 'cont');
if ~exist(cont_rep, 'dir'), mkdir(cont_rep); end

%% Standing 결과, Bar graph 생성
% natrual, day 1-4 의 standing 중 ee 비교

close all
c_dist = distinguishable_colors(5);

for i = rs.sub_pass+1:rs.n_sub
    sub_name = rs.sub_info.ID(i);
    sub_rs = rs.(sub_name);
    sub_w = str2double(rs.sub_info.weight(i));
    sub_idx = sub_rs.idx_info;
    sub_stand = interval_stand(interval_stand.ID == sub_name, :);
    sub_walk = interval_walk(interval_walk.ID == sub_name, :);
    sub_rep = fullfile(report_dir, sub_name);

    fd = fieldnames(sub_rs);
    walks = fd(cellfun(@(x) ~isempty(regexp(x, '^walk\d+$', 'once')), fd));

    x_idx = 1:length(walks);
    y_ee = nan(length(walks), 1);
    c_bar = nan(length(walks), 3);

    for j = 1:length(walks)
        walk = walks{j};
        walk_rs = sub_rs.(walk);
        w_idx = str2double(regexp(walk, '\d+', 'match'));

        idx_inc = [sub_idx.non_exo; sub_idx.train; sub_idx.disc; sub_idx.transparent];
        idx_exc = [sub_idx.eval_fail; sub_idx.stand_fail];
        if ~ismember(w_idx, idx_inc) || ismember(w_idx, idx_exc), continue, end

        y_ee(j) = walk_rs.ee_stand(1) / sub_w;

        switch true
            case ismember(w_idx, sub_idx.non_exo)
                c_bar(j, :) = c_dist(1, :);
            case ismember(w_idx, sub_idx.day_1)
                c_bar(j, :) = c_dist(2, :);
            case ismember(w_idx, sub_idx.day_2)
                c_bar(j, :) = c_dist(3, :);
            case ismember(w_idx, sub_idx.day_3)
                c_bar(j, :) = c_dist(4, :);
            case ismember(w_idx, sub_idx.day_4)
                c_bar(j, :) = c_dist(5, :);
        end
    end

    fh = figure('Visible', 'off');
    bh = bar(x_idx, y_ee, 'FaceColor', 'flat');
    ylim([0, 3]), box off
    xlabel('Trials (#)'), ylabel('EE (W)'), title(sub_name)

    for j = 1:length(walks)
        bh.CData(j, :) = c_bar(j, :);
    end

    % report 에 저장
    rep_png = fullfile(standing_dir, sprintf('%s.png', sub_name));
    saveas(fh, rep_png);

    close(fh)

    cprintf('key', '[Standing EE] %s done!\n', sub_name)
end

%% 이산 시도 결과, Figure 생성
% 1) K5 로 수집한 각 시도별 EE 데이터
% 2) stand 계산 시 잡은 구간과 결과값
% 3) walk ee 계산 시 잡은 구간과 결과값

close all

for i = rs.sub_pass+1:rs.n_sub
    sub_name = rs.sub_info.ID(i);
    sub_rs = rs.(sub_name);
    sub_idx = sub_rs.idx_info;
    sub_stand = interval_stand(interval_stand.ID == sub_name, :);
    sub_walk = interval_walk(interval_walk.ID == sub_name, :);
    sub_rep = fullfile(report_dir, sub_name);

    fd = fieldnames(sub_rs);
    walks = fd(cellfun(@(x) ~isempty(regexp(x, '^walk\d+$', 'once')), fd));

    for j = 1:length(walks)
        walk = walks{j};
        walk_rs = sub_rs.(walk);
        w_idx = str2double(regexp(walk, '\d+', 'match'));
        % natural, discrete only
        % TODO: check train case
        if ~ismember(w_idx, [sub_idx.non_exo; sub_idx.disc; sub_idx.transparent]), continue, end
        if ~ismember('eet', fieldnames(walk_rs)), continue, end

        fh = figure('Visible', 'off');
        eet_x = walk_rs.eet(:, 1);
        eet_y = walk_rs.eet(:, 2);
        plot(eet_x, eet_y, '-k'); hold on, box off
        y_limit = ylim;
        title(sprintf('%s %s', sub_name, walk)), xlabel('time (s)'), ylabel('EE (W)')

        % stand ee 계산 표시
        if ~ismember(w_idx, sub_idx.stand_fail)
            ee_st = walk_rs.ee_stand(1);
            st_int = sub_stand.(walk);

            if ~iscell(st_int) || isempty(st_int{1})
                x_rg = eet_x(eet_x <= 60);
            else
                st_int = str2num(st_int{1});
                x_rg = eet_x(and(eet_x >= st_int(1), eet_x <= st_int(2)));
            end
            rec = rectangle('Position', [x_rg(1), y_limit(1), x_rg(end) - x_rg(1), y_limit(2) - y_limit(1)], ...
                'FaceColor', [0.8, 0.8, 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
            uistack(rec, 'bottom')
            plot([x_rg(1), x_rg(end)], [ee_st, ee_st], '--r')
        end

        % walk ee 계산 표시
        if ~ismember(w_idx, sub_idx.eval_fail)
            ee_y = walk_rs.ee_walk(1);
            w_int = sub_walk.(walk);

            if ~iscell(w_int) || isempty(w_int{1})
                x_rg = eet_x(eet_x > eet_x(end) - 120);
                rec = rectangle('Position', [x_rg(1), y_limit(1), x_rg(end) - x_rg(1), y_limit(2) - y_limit(1)], ...
                    'FaceColor', [0.8, 0.8, 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
                uistack(rec, 'bottom')
                plot([x_rg(1), x_rg(end)], [ee_y, ee_y], '--r')
            else
                w_int = str2num(w_int{1});
                for int = w_int'
                    int(int <= 0) = int(int <= 0) + eet_x(end);
                    x_rg = eet_x(and(eet_x >= int(1), eet_x <= int(2)));
                    rec = rectangle('Position', [x_rg(1), y_limit(1), x_rg(end) - x_rg(1), y_limit(2) - y_limit(1)], ...
                        'FaceColor', [0.8, 0.8, 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
                    uistack(rec, 'bottom')
                    plot([x_rg(1), x_rg(end)], [ee_y, ee_y], '--r')
                end
            end
        end

        % report 에 저장
        rep_png = fullfile(sub_rep, sprintf('k5_%s_disc_%s.png', sub_name, walk));
        saveas(fh, rep_png);

        close(fh)
    end

    cprintf('key', '[Natural/Discrete EE] %s done!\n', sub_name)
end


%% 연속 시도 결과, Figure 생성
% 1) K5 로 수집한 각 시도별 EE 데이터
% 2) koller ee_est 와 수집 ee 비교

close all

for i = rs.sub_pass+1:rs.n_sub
    sub_name = rs.sub_info.ID(i);
    sub_rs = rs.(sub_name);
    sub_idx = sub_rs.idx_info;
    sub_rep = fullfile(report_dir, sub_name);

    fd = fieldnames(sub_rs);
    walks = fd(cellfun(@(x) ~isempty(regexp(x, '^walk\d+$', 'once')), fd));

    for j = 1:length(walks)
        walk = walks{j};
        walk_rs = sub_rs.(walk);
        w_idx = str2double(regexp(walk, '\d+', 'match'));
        % continuous only
        if ~ismember(w_idx, [sub_idx.cont]), continue, end
        if ~ismember('eet', fieldnames(walk_rs)), continue, end

        fh = figure('Visible', 'off');
        eet_x = walk_rs.eet(:, 1);
        eet_y = walk_rs.eet(:, 2);
        plot(eet_x, eet_y, '-k'); hold on, box off
        y_limit = ylim;
        title(sprintf('%s %s', sub_name, walk)), xlabel('time (s)'), ylabel('EE (W)')

        % eet 표시
        plot(eet_x, walk_rs.ee_est, '-r')

        % report 에 저장
        rep_png = fullfile(sub_rep, sprintf('k5_%s_cont_%s.png', sub_name, walk));
        saveas(fh, rep_png);

        close(fh)
    end

    cprintf('key', '[Continuous EE] %s done!\n', sub_name)
end

%% 이산 EE landscape
% 이산 프로토콜의 EE 를 2D 곡면으로 피팅

for i = rs.sub_pass+1:rs.n_sub
    sub_name = rs.sub_info.ID(i);
    sub_rs = rs.(sub_name);
    sub_w = str2double(rs.sub_info.weight(i));
    sub_idx = sub_rs.idx_info;
    sub_rep = fullfile(report_dir, sub_name);

    fh = figure('Visible', 'off'); hold on
    w_perc = ((sub_rs.disc_ee - sub_rs.disc_st) ./  (sub_rs.nat_ee - sub_rs.disc_st) - 1) * 100;
    trs_perc = ((sub_rs.disc_trs - sub_rs.disc_st) ./  (sub_rs.nat_ee - sub_rs.disc_st) - 1) * 100;

    scatter3(sub_rs.disc_p(:, 1), sub_rs.disc_p(:, 2), w_perc, 100, w_perc, 'filled');
    cb = colorbar; clim([-30, 30])
    title(sprintf('Disc %s (%.2f Kg)', sub_name, sub_w))

    % colorbar 에 transparent ee 표시
    if ~isnan(trs_perc)
        cb.Label.String = 'Assist Effect (%)';
        [B, I] = sort([cb.Ticks, trs_perc]);
        tick_labels = [cb.TickLabels; '\bf\color{red}◀'];
        cb.Ticks = B;
        cb.TickLabels = tick_labels(I);
    end

    % 2D surface 회귀
    ft = fittype('poly22');
    [fit_rs, gof] = fit(sub_rs.disc_p, w_perc, ft);
    fprintf("Disc, %s, R2=%.2f\n", sub_name, gof.rsquare);
    Z = feval(fit_rs, rs.pg_x, rs.pg_y);
    surf(rs.pg_x, rs.pg_y, Z, 'FaceAlpha', 0.5, 'EdgeColor', 'none'); % 회귀된 surface 위에 표시

    % 등고선
    F = scatteredInterpolant(rs.pg_x(:), rs.pg_y(:), Z(:),'natural','none');
    Zq = F(rs.pg_x, rs.pg_y);
    zmax = max(Zq, [], 'all');
    [C, ~] = contour(rs.pg_x, rs.pg_y, Zq, 10, 'white', 'LineWidth', 1.5, 'ZLocation', zmax - 0.1);
    ht = clabel(C, 'FontSize', 10, 'Color', 'k');

    for j = 1:length(ht)
        if isprop(ht(j), 'String')
            ht(j).String = sprintf('%.1f %%', str2double(ht(j).String));
            ht(j).Position(3) =  zmax;
        else
            ht(j).ZData = zmax;
            ht(j).Marker = 'x';
        end
    end

    view(0, 90);
    xlabel('TMax_{Swing} (Nm/Kg)'); xticks(0.04:0.07:0.18); xlim([0.02, 0.2])
    ylabel('TMax_{Stance} (Nm/Kg)'); yticks(0.04:0.07:0.18); ylim([0.02, 0.2])

    % report 에 저장
    rep_png = fullfile(disc_rep, sprintf('ee_disc_%s.png', sub_name));
    saveas(fh, rep_png);

    close(fh)
end

%% 연속 EE landscape

for i = rs.sub_pass+1:rs.n_sub
    sub_name = rs.sub_info.ID(i);
    sub_param = rs.param(i, :);
    sub_rs = rs.(sub_name);
    sub_w = str2double(rs.sub_info.weight(i));
    sub_idx = sub_rs.idx_info;
    sub_rep = fullfile(report_dir, sub_name);

    % cont ee 값 불러오기, 순서 정렬
    cont = setdiff(sub_idx.cont, sub_idx.eval_fail);
    ee_cont = nan(length(cont), size(rs.pg_x, 1), size(rs.pg_x, 2));
    cont_info = strings(length(cont), 1);
    for j = 1:length(cont)
        walk = sprintf("walk%d", cont(j));
        walk_rs = sub_rs.(walk);
        if ismember("pg_ee", fieldnames(walk_rs))
            ee_cont(j, :, :) = walk_rs.pg_ee;
        end
        cont_info(j) = sub_param.(walk);
    end

    [~, idx] = ismember(cont_info, ["5m", "10m", "15m"]);
    [~, sort_idx] = sort(idx);
    cont_info = cont_info(sort_idx);
    ee_cont = ee_cont(sort_idx, :, :);

    fh = figure('Position', [mon_pos(2,1), mon_pos(2,2), 800, 1600], 'Visible', 'off'); hold on
    w_perc = ((ee_cont - sub_rs.disc_st) ./  (sub_rs.nat_ee - sub_rs.disc_st) - 1) * 100;

    for j = 1:length(cont)
        subplot(length(cont), 1, j)

        surf(rs.pg_x, rs.pg_y, squeeze(w_perc(j, :, :)), 'EdgeColor', 'none')
        title(cont_info(j))
        clim([-30, 30]), zlim([-40, 40])
    end

    view(-30, 30);
    xticks(0.04:0.07:0.18); xlim([0.02, 0.2])
    yticks(0.04:0.07:0.18); ylim([0.02, 0.2])
    zticks(-40:20:40); 

    % report 에 저장
    rep_png = fullfile(cont_rep, sprintf('ee_cont_%s.png', sub_name));
    saveas(fh, rep_png);

    close(fh)
end

%% Standing EE 비교
% exo vs. no_exo 의 standing ee 차이

st_exo_array = [];
st_ne_array = [];

for i = rs.sub_pass+1:rs.n_sub
    sub_name = rs.sub_info.ID(i);
    sub_rs = rs.(sub_name);
    sub_w = str2double(rs.sub_info.weight(i));
    sub_idx = sub_rs.idx_info;

    for j = [sub_idx.disc; sub_idx.transparent; sub_idx.train]'
    % for j = [sub_idx.day_1(2); sub_idx.day_2(2); sub_idx.day_3(2)]'
        exc_idx = [sub_idx.non_exo; sub_idx.cont; sub_idx.eval_fail; sub_idx.stand_fail];
        if isempty(j) || ismember(j, exc_idx), continue, end
        walk = sprintf("walk%d", j);
        w_rs = sub_rs.(walk);
        st_exo_array = [st_exo_array; w_rs.ee_stand(1) / sub_w];

        if ismember("nat_st", fieldnames(w_rs))
            st_ne_array = [st_ne_array; w_rs.nat_st / sub_w];
        else
            st_ne_array = [st_ne_array; sub_rs.nat_st / sub_w];
        end
    end
end

[~, p] = ttest(st_exo_array, st_ne_array);
fprintf("Standing EE: (Exo) %.2f ± %.2f vs. (No exo) %.2f ± %.2f (p %.4f)\n", ...
    mean(st_exo_array), std(st_exo_array), ...
    mean(st_ne_array), std(st_ne_array), ...
    p)
