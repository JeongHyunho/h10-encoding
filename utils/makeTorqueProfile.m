function [torque, ext_t, flx_t] = makeTorqueProfile( ...
        ph, ...
        extPeak, extStart, extDur, ...
        flxPeak, flxStart, flxDur, ...
        d)
%MAKETORQUEPROFILE  flexion/extension 토크 펄스를 합성한 힙 토크 프로파일
%
%   [torque, ext_t, flx_t] = makeTorqueProfile(ph, ...
%                    extPeak, extStart, extDur, ...
%                    flxPeak, flxStart, flxDur, d)
%
% 입력 인수
%   ph        : 위상(%) 벡터 0–100 (default = 0:0.1:100)
%   extPeak   : 신전  토크 피크 값 (Nm/kg, 음수 권장)
%   extStart  : 신전  펄스 시작 phase (%)
%   extDur    : 신전  펄스 길이(폭)  (%)
%   flxPeak   : 굴곡  토크 피크 값 (Nm/kg, 양수 권장)
%   flxStart  : 굴곡  펄스 시작 phase (%)
%   flxDur    : 굴곡  펄스 길이(폭)  (%)
%   d         : 펄스 모양 지수(부드러움), default = 0.5
%
% 출력
%   torque    : 신전·굴곡 펄스를 합친 최종 토크 [same size as ph]
%   ext_t     : 신전  펄스만
%   flx_t     : 굴곡  펄스만
%
% 특징
%   • raised-cosine^d 창을 사용 → 파라미터 한두 개만 바꿔 다양한 시나리오 생성
%   • 펄스 중심 = start + dur/2
%   • 다음 주기의 신전 펄스(ext_t_nx)까지 포함해 0 % 부근 연속성 확보
%
% 예시
%   ph = 0:0.05:100;
%   tq = makeTorqueProfile(ph, -0.1,  5, 40,  0.2, 60, 40, 0.5);
%   plot(ph, tq), xlabel('Gait phase (%)'), ylabel('Hip torque (Nm/kg)')

% -------------------------------------------------------------------------
    if nargin < 1 || isempty(ph),       ph = 0:0.1:100;          end
    if nargin < 8 || isempty(d),        d  = 0.5;                end

    % --- 내부 창 함수 -----------------------------------------------------
    rec_w = @(x, wd) (abs(x) <= wd/2);                 % 직사각형 창
    rc_fn = @(x, wd, p) rec_w(x, wd) .* ...
             (0.5 * cos(2*pi/wd * x) + 0.5) .^ p;     % raised-cosine^p
    % ---------------------------------------------------------------------

    % 신전(Ext) · 굴곡(Flx) 펄스
    extCenter = extStart + extDur/2;
    flxCenter = flxStart + flxDur/2;

    ext_t    = extPeak * rc_fn(ph - extCenter       , extDur, d);
    ext_t_nx = extPeak * rc_fn(ph - extCenter + 100 , extDur, d); % 다음 주기
    flx_t    = flxPeak * rc_fn(ph - flxCenter       , flxDur, d);

    torque = ext_t + ext_t_nx + flx_t;
end
