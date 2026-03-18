function add_fp_labels(n_step)

% default argument
if nargin < 1
    n_step = 50;    % whether or not to calibarate force plates
end

% initiate vicon
vicon = ViconNexus();

% check validity of subject name
S = vicon.GetSubjectNames();
assert(numel(S) == 1, 'Invalid subject: %s', strjoin(S, ' '))
subject = S{1};

% check validity of device names
deviceNames = vicon.GetDeviceNames();
rightFP = 'Bertec_Right';
leftFP = 'Bertec_Left';
fpCheck = find(strcmp({rightFP, leftFP}, deviceNames));
if numel(fpCheck) ~= 2
    error(['Invalid plate: ', strjoin(deviceNames, ' ')])
end

% add left/right foot strike/off events
leftID = vicon.GetDeviceIDFromName(leftFP);
rightID = vicon.GetDeviceIDFromName(rightFP);

vicon.ClearAllEvents();
add_events(vicon, n_step, subject, leftID, 'Left')
add_events(vicon, n_step, subject, rightID, 'Right')

end


function add_events(vicon, n_step, subject, deviceID, context)
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

end
