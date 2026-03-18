function s_out = apdm_add_phase(s_in, hs_evt)
%APDM struct 에 phase (0~1) 정보를 추가함
%   s_in:  apdm struct input
%   hs_evt: heel strikes indeces
%   s_out: apdm struct output

s_out = s_in;
ph = nan(max(hs_evt(:)), 1);

for i = 1:length(hs_evt)
    hs = hs_evt(i, :);
    ph(hs(1):hs(2)) = linspace(0, 1, hs(2)-hs(1)+1);
end

s_out.ph = ph;
end

