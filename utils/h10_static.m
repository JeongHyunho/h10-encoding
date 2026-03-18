function h10_static

vicon = ViconNexus();
sub_list = vicon.GetSubjectNames();
subject = sub_list{1};

info = split(vicon.GetTrialName, '\');
day = strrep(info{end-1}, '-', '_');

[X1, Y1, Z1, ~] = vicon.GetTrajectory(subject, 'r.f.pelvis');
[X2, Y2, Z2, ~] = vicon.GetTrajectory(subject, 'r.b.pelvis');
[X3, Y3, Z3, ~] = vicon.GetTrajectory(subject, 'l.f.pelvis');
[X4, Y4, Z4, ~] = vicon.GetTrajectory(subject, 'l.b.pelvis');

p1 = mean([X1', Y1', Z1']);
p2 = mean([X2', Y2', Z2']);
p3 = mean([X3', Y3', Z3']);
p4 = mean([X4', Y4', Z4']);

[X5, Y5, Z5, ~] = vicon.GetTrajectory(subject, 'r.asis');
[X6, Y6, Z6, ~] = vicon.GetTrajectory(subject, 'l.asis');
[X7, Y7, Z7, ~] = vicon.GetTrajectory(subject, 'sacrum');

p5 = mean([X5', Y5', Z5']);
p6 = mean([X6', Y6', Z6']);
p7 = mean([X7', Y7', Z7']);


if exist('h10_static.mat', 'file')
    load('h10_static.mat', 'static')
else
    static = struct();
end

static.(subject).(day) = struct('p1', p1, 'p2', p2, 'p3', p3, 'p4', p4, 'p5', p5, 'p6', p6, 'p7', p7);
save('h10_static.mat', 'static')

% check validity of device names
deviceNames = vicon.GetDeviceNames();
rightFP = 'Bertec_Right';
leftFP = 'Bertec_Left';
fpCheck = find(strcmp({rightFP, leftFP}, deviceNames));
if numel(fpCheck) ~= 2
    error(['Invalid plate: ', strjoin(deviceNames, ' ')])
end
leftID = vicon.GetDeviceIDFromName(leftFP);
rightID = vicon.GetDeviceIDFromName(rightFP);

% get Fz
L_mFz = getMeanFz(vicon, leftID);
R_mFz = getMeanFz(vicon, rightID);

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

function mFz = getMeanFz(vicon, deviceID)
[~, ~, deviceRate, ~, ~, ~] = vicon.GetDeviceDetails(deviceID);
rate = vicon.GetFrameRate();
samplePerFrame = 1;
if deviceRate > rate
    samplePerFrame = round(deviceRate / rate);
end

% DeviceOutput = 'Force', channels 'Fx', 'Fy' and 'Fz'
outputID = vicon.GetDeviceOutputIDFromName(deviceID, 'Force');
fzData = vicon.GetDeviceChannelGlobal(deviceID, outputID, 3);
mFz = - mean(fzData);
end