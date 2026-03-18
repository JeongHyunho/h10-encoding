function h10_dyn(n_step, subject)

% default argument
if nargin < 1
    n_step = 50;    % whether or not to calibarate force plates
end

% initiate vicon
vicon = ViconNexus();

% check validity of device names
deviceNames = vicon.GetDeviceNames();
rightFP = 'Bertec_Right';
leftFP = 'Bertec_Left';
fpCheck = find(strcmp({rightFP, leftFP}, deviceNames));
if numel(fpCheck) ~= 2
    error(['Invalid plate: ', strjoin(deviceNames, ' ')])
end

% set modeled marker (asis, sacrum)
if ~contains(subject, 'Natural', 'IgnoreCase', true)
    set_modeled_markers(vicon, subject)
end

% add left/right foot strike/off events
leftID = vicon.GetDeviceIDFromName(leftFP);
rightID = vicon.GetDeviceIDFromName(rightFP);

vicon.ClearAllEvents();
L_mFz = add_events(vicon, n_step, subject, leftID, 'Left');
R_mFz = add_events(vicon, n_step, subject, rightID, 'Right');

% Set subject weight, height
weight = (L_mFz + R_mFz) / 9.81;
try
    vicon.CreateSubjectParam(subject, 'WEIGHT', weight, 'kg', 0.0, true)
catch
    vicon.SetSubjectParam(subject, 'WEIGHT', weight)
end

data_dir = fullfile(getenv('USERPROFILE'), 'Dropbox', '연구관련(6년)', '실험관련', 'H10 연속 프로토콜 12월', '데이터');
opts = detectImportOptions(fullfile(data_dir, 'sub_info.csv'));
opts = setvartype(opts, opts.VariableNames, "string");
sub_T = readtable(fullfile(data_dir, 'sub_info.csv'), opts);
height = 1000 * double(sub_T.height(sub_T.ID == subject(1:4)));
try
    vicon.CreateSubjectParam(subject, 'HEIGHT', height, 'mm', 0.0, true)
catch
    vicon.SetSubjectParam(subject, 'HEIGHT', height)
end
end


function set_modeled_markers(vicon, subject)
info = split(vicon.GetTrialName, '\');
day = strrep(strrep(info{end-1}, '-', '_'), 'dyn', 'static');
load('h10_static.mat', 'static')
assert(ismember(subject, fieldnames(static)), 'no subject in static')
assert(ismember(day, fieldnames(static.(subject))), 'no day in static')
static = static.(subject).(day);

[X1, Y1, Z1, ~] = vicon.GetTrajectory(subject, 'r.f.pelvis');
[X2, Y2, Z2, ~] = vicon.GetTrajectory(subject, 'r.b.pelvis');
[X3, Y3, Z3, ~] = vicon.GetTrajectory(subject, 'l.f.pelvis');
[X4, Y4, Z4, ~] = vicon.GetTrajectory(subject, 'l.b.pelvis');

pk_1 = [X1', Y1', Z1'];
pk_2 = [X2', Y2', Z2'];
pk_3 = [X3', Y3', Z3'];
pk_4 = [X4', Y4', Z4'];

[~, total_frame] = vicon.GetTrialRange();
[start_frame, end_frame] = vicon.GetTrialRegionOfInterest();

c0 = 1/4 * (static.p1 + static.p2 + static.p3 + static.p4);
c0_k = 1/4 * (pk_1 + pk_2 + pk_3 + pk_4);

q0_1 = static.p1 - c0;
q0_2 = static.p2 - c0;
q0_3 = static.p3 - c0;
q0_4 = static.p4 - c0;

qk_1 = pk_1 - c0_k;
qk_2 = pk_2 - c0_k;
qk_3 = pk_3 - c0_k;
qk_4 = pk_4 - c0_k;

qk_5 = zeros(3, total_frame);
qk_6 = zeros(3, total_frame);
qk_7 = zeros(3, total_frame);
v_exists = false(1, total_frame);
for i = start_frame:end_frame
    v_exists(i) = true;
    H = q0_1' * qk_1(i, :) + q0_2' * qk_2(i, :) +  q0_3' * qk_3(i, :)+ q0_4' * qk_4(i, :);
    [U, ~, V] = svd(H);
    R = U * diag([1, 1, det(U*V')]) * V';
    t = c0_k(i, :) - c0*R';

    qk_5(:, i) = R*static.p5' + t';
    qk_6(:, i) = R*static.p6' + t';
    qk_7(:, i) = R*static.p7' + t';
end

try
    vicon.CreateModeledMarker(subject, 'r.asis')
end
try
    vicon.CreateModeledMarker(subject, 'l.asis')
end
try
    vicon.CreateModeledMarker(subject, 'sacrum')
end
vicon.SetModelOutput(subject, 'r.asis', qk_5, v_exists);
vicon.SetModelOutput(subject, 'l.asis', qk_6, v_exists);
vicon.SetModelOutput(subject, 'sacrum', qk_7, v_exists);
end

function mFz = add_events(vicon, n_step, subject, deviceID, context)
[~, ~, deviceRate, ~, ~, ~] = vicon.GetDeviceDetails(deviceID);
rate = vicon.GetFrameRate();
samplePerFrame = 1;
if deviceRate > rate
    samplePerFrame = round(deviceRate / rate);
end

frameCount = vicon.GetFrameCount();
fpData = zeros(1, frameCount * samplePerFrame);
[startFrame, endFrame] = vicon.GetTrialRegionOfInterest();

% DeviceOutput = 'Force', channels 'Fx', 'Fy' and 'Fz'
outputID = vicon.GetDeviceOutputIDFromName(deviceID, 'Force');
for i = 1:frameCount
    read_rng = (i-1)*samplePerFrame+1:i*samplePerFrame;
    fpData(read_rng) = vicon.GetDeviceChannelGlobalForFrame(deviceID, outputID, 3, i);
end

% event detect (heel-strike, toe-off)
[b, a] = butter(6, 10/(deviceRate/2));
fzRaw = -fpData((startFrame-1)*samplePerFrame+1:endFrame*samplePerFrame);
fz = filtfilt(b, a, fzRaw);

fThresholdTop = 60;
fThresholdLow = 20;
hs = find((fz(1:end-1) < fThresholdTop) .* (fz(2:end) > fThresholdTop));
to = find((fz(1:end-1) > fThresholdTop) .* (fz(2:end) < fThresholdTop));
bad = [];

hs(hs - 150 <= 0) = [];
for i = 1:length(hs)
    fs = fz(hs(i)-150:hs(i));
    cross = find((fs(1:end-1) < fThresholdLow) .* (fs(2:end) > fThresholdLow));
    if ~isempty(cross)
        gap = length(fs) - cross(end);
        hs(i) = hs(i) - gap;
    else
        bad = [bad; hs(i)];
        hs(i) = nan;
    end
end
to(to + 150 > length(fz)) = [];
for i = 1:length(to)
    fs = fz(to(i):to(i)+150);
    cross = find((fs(1:end-1) > fThresholdLow) .* (fs(2:end) < fThresholdLow));
    if ~isempty(cross)
        gap = cross(1);
        to(i) = to(i) + gap;
    else
        bad = [bad; to(i)];
        to(i) = nan;
    end
end

% cut events to n_step
if numel(hs) > n_step + 1
    hs = hs(1:n_step+1);
end
if numel(to) > n_step + 1
    to = to(1:n_step+1);
end

% add event label
for i = 1:numel(hs)
    if isnan(hs(i))
        continue
    end
    sampleIdx = startFrame + floor(hs(i)/samplePerFrame);
    offset = (rem(hs(i), samplePerFrame) + 0.5) / deviceRate;
    vicon.CreateAnEvent(subject, context, 'Foot Strike', sampleIdx, offset)
end
for i = 1:numel(to)
    if isnan(to(i))
        continue
    end
    sampleIdx = startFrame + floor(to(i)/samplePerFrame);
    offset = (rem(to(i), samplePerFrame) + 0.5) / deviceRate;
    vicon.CreateAnEvent(subject, context, 'Foot Off', sampleIdx, offset)
end
for i = 1:numel(bad)
    sampleIdx = startFrame + floor(bad(i)/samplePerFrame);
    offset = (rem(to(i), samplePerFrame) + 0.5) / deviceRate;
    vicon.CreateAnEvent(subject, context, 'BAD', sampleIdx, offset)
end

mFz = mean(fz);
end
