function emg_channel_manual_labeler()
%==========================================================================
% EMG 채널 수동 라벨러 (GUI)
%
% ⦿ 기능:
%   - `emg_channel_success.csv`를 한 줄씩 불러와 채널별 합/불을 사람이 수동으로 지정
%   - 기존 자동 결과가 있으면 기본값으로 표시하고, 수정 후 같은 CSV에 바로 저장
%   - 참고용 미리보기: report_emg_raw 폴더의 해당 walk dyn 이미지 순회 표시
%
% 사용법:
%   emg_channel_manual_labeler
%
% 주의:
%   - 이미지가 없을 수도 있습니다(미리 생성되지 않은 경우). 그때는 체크박스만 사용 가능
%==========================================================================

% 환경 설정
mfile_dir = fileparts(mfilename('fullpath'));
cd(mfile_dir)
% 중첩 함수가 있는 정적 워크스페이스에서 스크립트를 run하면 오류가 나므로 base에서 실행
evalin('base', 'run(''../setup.m'')');
data_dir = getenv('DATA_DIR');

csv_file = fullfile(mfile_dir, '../emg_channel_success.csv');
if ~exist(csv_file, 'file')
    error('CSV 파일이 존재하지 않습니다: %s', csv_file)
end

T = readtable(csv_file, 'TextType', 'string');

% 보고서 이미지 폴더
report_dir = fullfile(data_dir, 'emg', 'report_emg_raw');
if ~exist(report_dir, 'dir')
    warning('보고서 이미지 폴더가 없습니다: %s', report_dir)
end

% UI 생성
ui = struct();
 ui.f = figure('Name', 'EMG 채널 수동 라벨러', 'Position', [-1919 49 1920 954], 'NumberTitle', 'off', 'Color', 'w', 'KeyPressFcn', @onKeyPress);
 ui.fs = 14;  % 기본 글자 크기
 ui.ax = axes('Parent', ui.f, 'Position', [0.06 0.15 0.66 0.8], 'FontSize', ui.fs);
axis(ui.ax, 'off')

% 이미지 선택 (단일 선택 보장)
ui.img_panel = uipanel('Parent', ui.f, 'Title', '이미지 선택', 'Units', 'normalized', 'Position', [0.45 0.06 0.2 0.07]);
ui.img_group = uibuttongroup('Parent', ui.img_panel, 'Units','normalized', 'Position', [0 0 1 1], 'SelectionChangedFcn', @onImgGroupChanged);

% CSV 항목 드롭다운
row_labels = arrayfun(@(i) sprintf('%s - %s', T.sub_name(i), T.walk(i)), (1:height(T))', 'UniformOutput', false);
 uicontrol(ui.f, 'Style', 'text', 'String', 'CSV 항목 선택:', 'Units', 'normalized', 'Position', [0.043 0.92 0.12 0.05], 'BackgroundColor','w', 'FontSize', ui.fs);
 ui.popup_rows = uicontrol(ui.f, 'Style', 'popupmenu', 'String', row_labels, 'Value', 1, 'Units', 'normalized', 'Position', [0.069 0.88 0.135 0.045], 'Callback', @onSelectRow, 'FontSize', ui.fs);
 % 드롭다운 이동 화살표(위/아래)
 ui.btn_row_prev = uicontrol(ui.f, 'Style', 'pushbutton', 'String', '▲', 'Units','normalized', 'Position', [0.0672 0.82 0.035 0.045], 'Callback', @onRowPrev, 'FontSize', ui.fs);
 ui.btn_row_next = uicontrol(ui.f, 'Style', 'pushbutton', 'String', '▼', 'Units','normalized', 'Position', [0.1061 0.82 0.035 0.045], 'Callback', @onRowNext, 'FontSize', ui.fs);

 uicontrol(ui.f, 'Style', 'text', 'String', '피험자:', 'Units', 'normalized', 'Position', [0.56 0.93 0.06 0.05], 'BackgroundColor','w', 'FontSize', ui.fs);
 ui.txt_sub = uicontrol(ui.f, 'Style', 'text', 'String', '', 'Units', 'normalized', 'Position', [0.62 0.93 0.18 0.05], 'BackgroundColor','w', 'HorizontalAlignment', 'left', 'FontSize', ui.fs);

 uicontrol(ui.f, 'Style', 'text', 'String', '보행:', 'Units', 'normalized', 'Position', [0.56 0.88 0.06 0.05], 'BackgroundColor','w', 'FontSize', ui.fs);
 ui.txt_walk = uicontrol(ui.f, 'Style', 'text', 'String', '', 'Units', 'normalized', 'Position', [0.62 0.88 0.18 0.05], 'BackgroundColor','w', 'HorizontalAlignment', 'left', 'FontSize', ui.fs);

% 채널 체크박스 (ch1~ch10)
ui.chk = gobjects(1,10);
for k = 1:10
    y = 0.725 - (k-1)*0.0755;
     uicontrol(ui.f, 'Style', 'text', 'String', sprintf('ch%d', k), 'Units', 'normalized', 'Position', [0.594 0.108+y 0.05 0.05], 'BackgroundColor','w', 'FontSize', ui.fs+2, 'HorizontalAlignment','left');
     ui.chk(k) = uicontrol(ui.f, 'Style', 'checkbox', 'Value', 1, 'Units', 'normalized', 'Position', [0.63 0.113+y 0.05 0.06], 'BackgroundColor','w', 'Callback', @(h,~) onToggleChannel(h, k), 'FontSize', ui.fs+2);
end

% 이미지 순회 버튼
 ui.btn_prev = uicontrol(ui.f, 'Style', 'pushbutton', 'String', '이전 이미지', 'Units','normalized', 'Position', [0.06 0.06 0.18 0.06], 'Callback', @onPrev, 'FontSize', ui.fs);
 ui.btn_next = uicontrol(ui.f, 'Style', 'pushbutton', 'String', '다음 이미지', 'Units','normalized', 'Position', [0.26 0.06 0.18 0.06], 'Callback', @onNext, 'FontSize', ui.fs);

% 제어 버튼 (건너뛰기 버튼 제거)

% 상태
 state.row = 1;
 state.img_idx = 1;
 state.img_list = {};
 state.back_stack = {};   % {struct('row',row,'img_idx',idx), ...}
 state.forward_stack = {};
 state.initialized = false;
guidata(ui.f, struct('ui',ui, 'T',T, 'csv_file',csv_file, 'report_dir',report_dir, 'state',state));

% 첫 행 로드 (초기 이미지 인덱스를 명시적으로 전달)
loadRow(ui.f, 1);
gd0 = guidata(ui.f); gd0.state.initialized = true; guidata(ui.f, gd0);
updateNavButtons(ui.f);

% --- 콜백/헬퍼 ---
    function loadRow(hFig, initial_img_idx)
        gd = guidata(hFig);
        T = gd.T; ui = gd.ui; state = gd.state; report_dir = gd.report_dir;
        if nargin < 2 || isempty(initial_img_idx)
            initial_img_idx = 1;
        end
        if state.row > height(T)
            msgbox('모든 행을 처리했습니다.', '완료');
            return
        end
        % 드롭다운 현재 선택을 row에 맞추기
        if isfield(ui, 'popup_rows') && ishghandle(ui.popup_rows)
            set(ui.popup_rows, 'Value', state.row);
        end
        sub = T.sub_name(state.row);
        walk = T.walk(state.row);
        set(ui.txt_sub, 'String', sub);
        set(ui.txt_walk, 'String', walk);
        
        % 체크박스 값 초기화 (CSV 현재값 반영)
        for k = 1:10
            var = sprintf('ch%d', k);
            if ismember(var, T.Properties.VariableNames)
                val = T.(var)(state.row);
                if ismissing(val) || isempty(val)
                    val = 1; % 기본값
                end
                set(ui.chk(k), 'Value', double(val)>0);
            else
                set(ui.chk(k), 'Value', 1);
            end
        end
        
        % 이미지 목록 구성: <sub>_<walk>_*dyn*.png
        img_pattern = sprintf('%s_%s_*dyn*.png', sub, walk);
        if exist(report_dir, 'dir')
            d = dir(fullfile(report_dir, img_pattern));
        else
            d = [];
        end
        if isempty(d)
            gd.state.img_list = {};
            gd.state.img_idx = 0;
            cla(ui.ax); axis(ui.ax,'off');
            text(ui.ax, 0.5, 0.5, '이미지 없음', 'HorizontalAlignment','center');
        else
            gd.state.img_list = arrayfun(@(x) fullfile(x.folder, x.name), d, 'UniformOutput', false);
            % 초기 인덱스를 먼저 반영하고 상태 저장 후, UI 구성/표시 순으로 호출
            gd.state.img_idx = max(1, min(initial_img_idx, numel(gd.state.img_list)));
            guidata(hFig, gd);
            buildImageSelectors(hFig);
            showImage(hFig);
            gd = guidata(hFig); % 최신 상태 재획득
        end
        guidata(hFig, gd);
        drawnow;
    end

    function showImage(hFig)
        gd = guidata(hFig); ui = gd.ui; state = gd.state;
        if isempty(state.img_list)
            cla(ui.ax); axis(ui.ax,'off');
            text(ui.ax, 0.5, 0.5, '이미지 없음', 'HorizontalAlignment','center');
            return
        end
        idx = max(1, min(state.img_idx, numel(state.img_list)));
        img = imread(state.img_list{idx});
        axes(ui.ax); cla(ui.ax);
        image(ui.ax, img); axis(ui.ax,'image'); axis(ui.ax,'off');
        [~, baseName, extName] = fileparts(state.img_list{idx});
        shortName = [baseName extName];
        % 제목 색상: 이미지가 2개 이상이면 파란색으로 강조하여 다음 이미지 존재를 인지시키기
        nTotal = numel(state.img_list);
        t = title(ui.ax, sprintf('(%d/%d) %s', idx, nTotal, shortName), 'Interpreter','none','FontSize',18);
        if nTotal > 1
            set(t, 'Color', [0 0 1]); % 파란색
        else
            set(t, 'Color', 'k');     % 기본 검정
        end
        % 라디오 선택과 동기화
        syncImageRadio(hFig);
        drawnow;
    end

    function onPrev(hObj, ~)
        gd = guidata(hObj);
        % history 우선
        if ~isempty(gd.state.back_stack)
            % 현재 선택을 forward 스택에 push
            cur = struct('row', gd.state.row, 'img_idx', gd.state.img_idx);
            gd.state.forward_stack{end+1} = cur;
            % back에서 pop하여 이동
            sel = gd.state.back_stack{end};
            gd.state.back_stack(end) = [];
            guidata(hObj, gd);
            gotoSelection(gd.ui.f, sel.row, sel.img_idx, true);
            return
        end
        % 히스토리 없음: 동작 안 함
        updateNavButtons(gd.ui.f);
    end

    function onNext(hObj, ~)
        gd = guidata(hObj);
        % forward 스택 우선
        if ~isempty(gd.state.forward_stack)
            % 현재 선택을 back 스택에 push
            cur = struct('row', gd.state.row, 'img_idx', gd.state.img_idx);
            gd.state.back_stack{end+1} = cur;
            sel = gd.state.forward_stack{end};
            gd.state.forward_stack(end) = [];
            guidata(hObj, gd);
            gotoSelection(gd.ui.f, sel.row, sel.img_idx, true);
            return
        end
        % 히스토리 없음: 동작 안 함
        updateNavButtons(gd.ui.f);
    end

    % 채널 체크 변경 시 자동 저장
    function onToggleChannel(hObj, idx)
        gd = guidata(hObj);
        T = gd.T; r = gd.state.row; csv_file = gd.csv_file;
        var = sprintf('ch%d', idx);
        if ismember(var, T.Properties.VariableNames)
            T.(var)(r) = double(get(hObj, 'Value') > 0);
            writetable(T, csv_file);
            gd.T = T;
            guidata(hObj, gd);
        end
    end

    % 드롭다운 한 항목 위로 이동
    function onRowPrev(hObj, ~)
        gd = guidata(hObj);
        new_row = max(1, gd.state.row - 1);
        gotoSelection(gd.ui.f, new_row, 1, false);
    end

    % 드롭다운 한 항목 아래로 이동
    function onRowNext(hObj, ~)
        gd = guidata(hObj);
        new_row = min(height(gd.T), gd.state.row + 1);
        gotoSelection(gd.ui.f, new_row, 1, false);
    end

    % 키보드 화살표(좌/상=이전, 우/하=다음) 처리
    function onKeyPress(hObj, evt)
        if isempty(evt.Key), return; end
        switch evt.Key
            case {'uparrow', 'leftarrow'}
                onRowPrev(hObj, []);
            case {'downarrow', 'rightarrow'}
                onRowNext(hObj, []);
            otherwise
                % pass
        end
    end

    function onSelectRow(hObj, ~)
        gd = guidata(hObj);
        sel_row = get(hObj, 'Value');
        gotoSelection(gd.ui.f, sel_row, 1, false);
    end

    function buildImageSelectors(hFig)
        gd = guidata(hFig); ui = gd.ui; state = gd.state;
        delete(allchild(ui.img_group));
        n = numel(state.img_list);
        if n < 1, return; end
        margin = 0.02;                 % 좌우 여백 (패널 정규화 단위)
        availW = 1 - margin*(n+1);     % 전체 사용 가능 폭
        w = max(0.12, availW / n);     % 최소 폭 보장(라벨 잘림 방지)
        for k = 1:n
            xpos = margin + (k-1)*(w + margin);
            [~, baseN, extN] = fileparts(state.img_list{k});
            % 파일명에서 실제 dyn 인덱스 추출 (대소문자/구분자 변형 허용)
            tok = regexpi(baseN, 'dyn[_\-]?(\d+)', 'tokens', 'once');
            if ~isempty(tok) && ~isempty(tok{1})
                label = sprintf('dyn_%s', tok{1});
            else
                % 보조: 뒤쪽 숫자 시퀀스를 사용
                tok2 = regexpi(baseN, '(\d+)$', 'tokens', 'once');
                if ~isempty(tok2)
                    label = sprintf('dyn_%s', tok2{1});
                else
                    label = sprintf('dyn_%d', k);
                end
            end
            rb = uicontrol(ui.img_group, 'Style', 'radiobutton', 'String', label, ...
                'Units','normalized', 'Position', [xpos 0.15 w 0.7], 'BackgroundColor','w', ...
                'UserData', k, 'FontSize', 12, 'TooltipString', [baseN extN], ...
                'Callback', @onImageRadio);
            if k == state.img_idx
                ui.img_group.SelectedObject = rb;
            end
        end
        drawnow;
    end

    % 라디오버튼 개별 콜백(버전 호환성/신뢰성 향상)
    function onImageRadio(hObj, ~)
        gd = guidata(hObj);
        idx = get(hObj, 'UserData');
        if isempty(idx), return; end
        % 현재 선택을 back 스택에 push, forward는 초기화
        if gd.state.initialized
            cur = struct('row', gd.state.row, 'img_idx', gd.state.img_idx);
            gd.state.back_stack{end+1} = cur;
            gd.state.forward_stack = {};
        end
        gd.state.img_idx = idx;
        guidata(hObj, gd);
        showImage(gd.ui.f);
        updateNavButtons(gd.ui.f);
    end

    function onImgGroupChanged(bg, evt)
        gd = guidata(bg);
        obj = evt.NewValue;
        if isempty(obj) || ~isgraphics(obj), return; end
        idx = get(obj, 'UserData');
        if isempty(idx), return; end
        % 현재 선택을 back 스택에 push, forward는 초기화
        if gd.state.initialized
            cur = struct('row', gd.state.row, 'img_idx', gd.state.img_idx);
            gd.state.back_stack{end+1} = cur;
            gd.state.forward_stack = {};
        end
        gd.state.img_idx = idx;
        guidata(bg, gd);
        showImage(gd.ui.f);
        updateNavButtons(gd.ui.f);
    end

    function syncImageRadio(hFig)
        gd = guidata(hFig); ui = gd.ui; state = gd.state;
        objs = allchild(ui.img_group);
        if isempty(objs), return; end
        for k = 1:numel(objs)
            if get(objs(k),'UserData') == state.img_idx
                ui.img_group.SelectedObject = objs(k);
                break;
            end
        end
    end

    function updateNavButtons(hFig)
        gd = guidata(hFig);
        if isfield(gd.ui,'btn_prev') && ishghandle(gd.ui.btn_prev)
            set(gd.ui.btn_prev, 'Enable', tern(~isempty(gd.state.back_stack),'on','off'));
        end
        if isfield(gd.ui,'btn_next') && ishghandle(gd.ui.btn_next)
            set(gd.ui.btn_next, 'Enable', tern(~isempty(gd.state.forward_stack),'on','off'));
        end
    end

    function out = tern(cond, a, b)
        if cond, out = a; else, out = b; end
    end

    % 행/이미지 선택으로 이동 (히스토리 반영)
    function gotoSelection(hFig, row, img_idx, fromHistory)
        gd = guidata(hFig);
        if gd.state.initialized && ~fromHistory
            cur = struct('row', gd.state.row, 'img_idx', gd.state.img_idx);
            gd.state.back_stack{end+1} = cur;
            gd.state.forward_stack = {};
        end
        gd.state.row = row;
        guidata(hFig, gd);
        % 행 변경 시 원하는 초기 이미지 인덱스를 즉시 반영하여 로드
        loadRow(hFig, img_idx);
        syncImageRadio(hFig);
        updateNavButtons(hFig);
    end

end


