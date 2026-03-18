function [frc, vel] = comIntegrate(fs, hs, rl, fvel, m, freq)

nStrides = length(hs);
dt = 1 / freq;

frc = cell(nStrides-1, 3);
vel = cell(nStrides-1, 3);

if strcmpi(rl, 'Left') || strcmpi(rl, 'L')
    ipsPlate = [fs.ground_force2_vx, fs.ground_force2_vy, fs.ground_force2_vz];
    contPlate = [fs.ground_force1_vx, fs.ground_force1_vy, fs.ground_force1_vz];
elseif strcmpi(rl, 'Right') || strcmpi(rl, 'R')
    ipsPlate = [fs.ground_force1_vx, fs.ground_force1_vy, fs.ground_force1_vz];
    contPlate = [fs.ground_force2_vx, fs.ground_force2_vy, fs.ground_force2_vz];
else
    assert(true, 'unexpected argument for right/left: %s', rl)
end

for i = 1:nStrides-1
    fIps = ipsPlate(hs(i):hs(i+1), :);
    fCont = contPlate(hs(i):hs(i+1), :);

    acc =(fIps+fCont) / m - [0, 9.81, 0];
    dv = cumsum(acc - mean(acc, 1), 1) * dt;
    v = [fvel, 0, 0] + dv - mean(dv, 1);

    frc{i, 1} = fIps(:, 1);
    frc{i, 2} = fIps(:, 2);
    frc{i, 3} = fIps(:, 3);
    vel{i, 1} = v(:, 1);
    vel{i, 2} = v(:, 2);
    vel{i, 3} = v(:, 3);
end
