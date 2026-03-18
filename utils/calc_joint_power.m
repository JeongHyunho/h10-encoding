function p = calc_joint_power(q, t, freq, cut_freq)

if nargin < 4
    cut_freq = 6;
end

fields = fieldnames(q);
p = struct();
[b, a] = butter(6, cut_freq/(freq/2));

for i = 1:length(fields)
    name = fields{i};
    q_vel = pi / 180 * diff(q.(name)) * freq;

    tor = t.([name, '_moment']);
    power = q_vel .* tor(1:end-1);
    power_s = filtfilt(b, a, power);

    p.(name) = power_s;
end

end
