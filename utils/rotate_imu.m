function rot_imu = rotate_imu(q_imu, rot_seq, eul_deg)

rotm = eul2rotm(pi/180 * eul_deg, rot_seq)';
imu_names = fieldnames(q_imu);
rot_imu = struct();

for i = 1:numel(imu_names)
    name = imu_names{i};
    q = q_imu.(name);
    rot_imu.(name) = struct();
    
    ms_list = fieldnames(q);
    for j = 1:numel(ms_list)
        ms_name = ms_list{j};
        v = q.(ms_name);
        u = (rotm * [v.x(:), v.y(:), v.z(:)]')';
        sz = size(v.x);
        rot_v = struct('x', reshape(u(:, 1), sz(1), sz(2)), ...
            'y', reshape(u(:, 2), sz(1), sz(2)), ...
            'z', reshape(u(:, 3), sz(1), sz(2)));
        
        rot_imu.(name).(ms_name) = rot_v;
    end
end

end
