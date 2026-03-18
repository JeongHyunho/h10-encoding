gencoords={'time','pelvis_tx','pelvis_ty','pelvis_tz','pelvis_list','pelvis_rotation','pelvis_tilt','hip_flexion_r','hip_adduction_r','hip_rotation_r','knee_angle_r','ankle_angle_r','subtalar_angle_r','mtp_angle_r','hip_flexion_l','hip_adduction_l','hip_rotation_l','knee_angle_l','ankle_angle_l','subtalar_angle_l','mtp_angle_l','lumbar_extension','lumbar_bending','lumbar_rotation', 'ground_force_vx', 'ground_force_vy', 'ground_force_vz', 'ground_force_px', 'ground_force_py', 'ground_force_pz', 'ground_force_vx', 'ground_force_vy', 'ground_force_vz', 'ground_force_px', 'ground_force_py', 'ground_force_pz', 'ground_torque_x', 'ground_torque_y', 'ground_torque_z', 'ground_torque_x', 'ground_torque_y', 'ground_torque_z' };

tstart=0;
tend=15;
rate=60;
T=round((((rate*tstart):(rate*tend))/rate)*1000)/1000;

q.labels=gencoords;
q.data=zeros(length(T),length(gencoords));
q.data(:,1)=T';

write_motionFile(q,'delaware3_zeros.mot');
