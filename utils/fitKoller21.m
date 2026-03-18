function [y0, H, y_est, MSE, Sig] = fitKoller21(xseries, yseries, tseries, msmt, trials, tau)
%FITKOLLER21  2D 1차 ICM(Instantaneous Cost Mapping) 모델 적합
%
%   [y0, H, y_est, MSE, Sig] = FITKOLLER21(xseries, yseries, tseries, msmt, trials, tau)
%
%   지수 wash-in 모델 y = H*x + y0 를 적합한다.
%   x = [flx_torque, ext_torque] 2차원 입력에 대해 시상수 tau 기반으로
%   누적 지수 응답(1st-order IIR)을 구성하고, 최소제곱법으로 계수를 추정한다.
%
%   입력:
%     xseries — 첫 번째 입력 변수 (예: 굴곡 토크 크기) [Nx1, Nm/kg]
%     yseries — 두 번째 입력 변수 (예: 신전 토크 크기) [Nx1, Nm/kg]
%     tseries — 시간 벡터 [Nx1, s]
%     msmt    — 관측된 대사 응답 벡터 [Nx1, W]
%     trials  — 시행(trial) 번호 벡터 [Nx1, integer]
%     tau     — 대사 응답 시상수 [scalar, s]
%
%   출력:
%     y0    — 각 trial의 초기값(절편) [nx1]
%     H     — ICM 계수 [lx, ly, l0] — 기울기 2개 + 공통 절편
%     y_est — 모델 추정값 [Nx1]
%     MSE   — 평균 제곱 오차 [scalar]
%     Sig   — ICM 계수(H)의 공분산 행렬 [3x3]
%
%   알고리즘:
%     각 trial 내에서 이산 시간 간격 h를 이용한 1차 지수 wash-in
%     A 행렬을 구성하고, 정규 방정식 (A'A)^{-1}A'y 로 계수를 추정한다.
%
%   참고: fitKoller21_agg, fitKoller21_CI_bootstrap, k5_to_ee

% 2D & 1st order fit

n = length(unique(trials));
m = length(msmt);
A = zeros(m, n+3);

grp_idx = findgroups(trials);
x_cell = splitapply(@(x) {x}, xseries, grp_idx);
y_cell = splitapply(@(x) {x}, yseries, grp_idx);
t_cell = splitapply(@(x) {x}, tseries, grp_idx);

last_row = 0;
for i = 1:n
    m_i = sum(trials == i);

    for j = 1:m_i
        x = x_cell{i}(j);
        y = y_cell{i}(j);

        if j == 1
            A(last_row+j, i) = 1;       % i==1: [1, 0, ..., 0], i==2: [0, 1, ..., 0]
            continue
        end

        h = t_cell{i}(j) - t_cell{i}(j-1);
        A(last_row+j, i) = (1-h/tau)*A(last_row+j-1,i);
        A(last_row+j, end-2) = (1-h/tau)*A(last_row+j-1,end-2)+h/tau*x;
        A(last_row+j, end-1) = (1-h/tau)*A(last_row+j-1,end-1)+h/tau*y;
        A(last_row+j, end) = (1-h/tau)*A(last_row+j-1,end)+h/tau*1;
    end

    last_row = last_row + m_i;
end

coe = inv(A' * A) * A' * msmt;
y_est = A*coe;

y0 = coe(1:n);
lx = coe(end-2);
ly = coe(end-1);
l0 = coe(end);
H = [lx, ly, l0];

MSE = sum((y_est - msmt).^2) / m;
sel_mat = [repmat(zeros(3, 1), 1, n), eye(3)];
Sig = sel_mat * inv(A' * A) * sel_mat';

end
