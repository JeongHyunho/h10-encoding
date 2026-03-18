function trim_mot_grf(mot_file, num_steps)
EVT_TH = 30;        % threshold of heel-strike/toe-off detections
MIN_LEN = 200;      % minimum length of one stride

% check number and type of arguments
assert(nargin == 2, 'Function requires two input argument')
assert(ischar(mot_file) || isstring(mot_file), ...
    'Input must be a string representing a filename')
assert(isnumeric(num_steps), 'The number of steps must be numeric')

% Open the file, If this returns a -1, we did not open the file
% successfully
fid_in = fopen(mot_file, 'r');
assert(fid_in ~= -1, 'File not found or permission denied')

% Initialize variables
nlines = 0;
infos = {};
max_line = 0;
ncols = 0;
data = [];

% Process file infos before header
line = fgetl(fid_in);
while ~strcmp(line, 'endheader')
    nlines = nlines + 1;
    infos{nlines} = line;
    line = fgetl(fid_in);
end

% Read header and data
header = strsplit(fgetl(fid_in));
data = reshape(fscanf(fid_in, '%f'), length(header), [])';
fclose(fid_in);

% Determine heel-strike and toe-off indices (r/l for right/left)
r_vgrf = data(:, strcmp('ground_force1_vy', header));
l_vgrf = data(:, strcmp('ground_force2_vy', header));

device_rate = round(1/(data(2, 1) - data(1, 1)));
[r_hs, r_to] = detect_evt(r_vgrf, device_rate, EVT_TH, MIN_LEN);
[l_hs, l_to] = detect_evt(l_vgrf, device_rate, EVT_TH, MIN_LEN);
r_hs(r_hs > r_to(end)) = [];
assert(length(r_hs) == num_steps+1, ...
    'Detected steps is more/less than entered: %d!=%d', length(r_hs), num_steps+1)
assert(length(l_hs) == num_steps+1, ...
    'Detected steps is more/less than entered: %d!=%d', length(l_hs), num_steps+1)
assert(all(sum((r_hs(1:end-1)' < r_to(2:end-1)) .* (r_to(2:end-1) < r_hs(2:end)'), 1) == 1), ...
    'Falsely detected toe-off!')
assert(all(sum((l_hs(1:end-1)' < l_to(2:end-1)) .* (l_to(2:end-1) < l_hs(2:end)'), 1) == 1), ...
    'Falsely detected toe-off!')

% Wirte heel-strikes and toe-offs indices
[pname, fname, extname] = fileparts(mot_file);
evt_file = fullfile(pname, [fname, '_evt.mat']);
save(evt_file, 'r_hs', 'r_to', 'l_hs', 'l_to')

% Make force/torque zero during swing phase
if ~(r_hs(1) > r_to(1)), r_to = [1, r_to]; end
if ~(r_hs(end) > r_to(end)), r_hs = [r_hs, numel(r_vgrf)]; end
if ~(l_hs(1) > l_to(1)), l_to = [1, l_to]; end
if ~(l_hs(end) > l_to(end)), l_hs = [l_hs, numel(l_vgrf)]; end

for i = 1:numel(r_to)
    span = r_to(i):r_hs(i);
    data(span, strcmp('ground_force1_vx', header)) = 0;
    data(span, strcmp('ground_force1_vy', header)) = 0;
    data(span, strcmp('ground_force1_vz', header)) = 0;
    data(span, strcmp('ground_torque1_x', header)) = 0;
    data(span, strcmp('ground_torque1_y', header)) = 0;
    data(span, strcmp('ground_torque1_z', header)) = 0;
    data(span, strcmp('ground_force1_px', header)) = 0;
    data(span, strcmp('ground_force1_py', header)) = 0;
    data(span, strcmp('ground_force1_pz', header)) = 0;
end

for i = 1:numel(l_to)
    span = l_to(i):l_hs(i);
    data(span, strcmp('ground_force2_vx', header)) = 0;
    data(span, strcmp('ground_force2_vy', header)) = 0;
    data(span, strcmp('ground_force2_vz', header)) = 0;
    data(span, strcmp('ground_torque2_x', header)) = 0;
    data(span, strcmp('ground_torque2_y', header)) = 0;
    data(span, strcmp('ground_torque2_z', header)) = 0;
    data(span, strcmp('ground_force2_px', header)) = 0;
    data(span, strcmp('ground_force2_py', header)) = 0;
    data(span, strcmp('ground_force2_pz', header)) = 0;
end

% Write trimmed data
infos{1} = fname;
new_file = fullfile(pname, [fname, '_trimmed', extname]);

fid_out = fopen(new_file, 'w');
for i = 1:nlines
    fprintf(fid_out, [infos{i}, '\n']);
end
fprintf(fid_out, 'endheader\n');
fprintf(fid_out, [strjoin(header, '\t'), '\n']);
fprintf(fid_out, [repmat('%.6f\t', 1, length(header)), '\n'], data');
fclose(fid_out);

end


function [hs, to] = detect_evt(fzRaw, deviceRate, fThreshold, minLen)
% Apply low-pass filter of 10Hz
[b, a] = butter(6, 30/(deviceRate/2));
fz = filtfilt(b, a, fzRaw);

% event detect (heel-strike, toe-off)
fThFirst = 150;
hs = find((fz(1:end-1) < fThFirst) .* (fz(2:end) > fThFirst))';
to = find((fz(1:end-1) > fThFirst) .* (fz(2:end) < fThFirst))';

hs(hs - 150 <= 0) = [];
for i = 1:length(hs)
    fs = fz(hs(i)-150:hs(i));
    cross = find((fs(1:end-1) < fThreshold) .* (fs(2:end) > fThreshold));
    gap = length(fs) - cross(end);
    hs(i) = hs(i) - gap;
end
to(to + 150 > length(fz)) = [];
for i = 1:length(to)
    fs = fz(to(i):to(i)+150);
    cross = find((fs(1:end-1) > fThreshold) .* (fs(2:end) < fThreshold));
    gap = cross(1) - 1;
    to(i) = to(i) + gap;
end

% check minimum length btw events
assert(all(diff(hs) >= minLen), 'possibly miss-detected heel-strike!')
assert(all(diff(to) >= minLen), 'possibly miss-detected toe-off!')

end


