function [q, t0_out] = load_APDM(h5_path, apdm_rate, cut_freq, t0_in)

if nargin < 4
    t0_in = nan;
end

deviceID = {'11377', '11513', '12015', '12395', '11510', '12409'};
[b, a] = butter(4, cut_freq/(apdm_rate/2));
q = struct();

for i = 1:length(deviceID)
    id = deviceID{i};
    try
        name = h5readatt(h5_path, ['/Sensors/', id, '/Configuration'], 'Label 0');
    catch ME
        if strcmp(ME.identifier,  'MATLAB:imagesci:hdf5lib:libraryError')
            % id of a device not included
            continue
        else
            rethrow(ME)
        end
    end
    name = name(isletter(name));
    name = lower(name);

    local_acc_ = h5read(h5_path, ['/Sensors/', id, '/Accelerometer'])';
    raw_acc_ = filtfilt(b, a, local_acc_);
    gyro_ = filtfilt(b, a, h5read(h5_path, ['/Sensors/', id, '/Gyroscope'])');
    quat_ = h5read(h5_path, ['/Processed/', id, '/Orientation'])';
    acc_ = filtfilt(b, a, quatrotate(quat_, quatrotate(quatinv(quat_), local_acc_) - [0, 0, 9.81]));

    q.(name).rawacc = struct('x', raw_acc_(:, 1), 'y', raw_acc_(:, 2), 'z', raw_acc_(:, 3));
    q.(name).acc = struct('x', acc_(:, 1), 'y', acc_(:, 2), 'z', acc_(:, 3));
    q.(name).gyro = struct('x', gyro_(:, 1), 'y', gyro_(:, 2), 'z', gyro_(:, 3));

    if i == 1
        time_ = h5read(h5_path, ['/Sensors/', id, '/Time']);
        if isnan(t0_in)
            q.time = 1e-6 * double(time_ - time_(1));
            t0_out = time_(1);
        else
            q.time = 1e-6 * double(time_ - t0_in);
            t0_out = t0_in;
        end
    end
end
end
