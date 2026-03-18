function [t, t_slen, slen_stat] = fp_to_slen(c3d, evt, x_spd, is_discrete)
pts_labels = c3d.parameters.POINT.LABELS.DATA;
idx_rheel = cellfun(@(x) strcmpi(x, 'R.Heel'), pts_labels);
idx_lheel = cellfun(@(x) strcmpi(x, 'L.Heel'), pts_labels);
pts_rheel = squeeze(c3d.data.points(:, idx_rheel, :));
pts_lheel = squeeze(c3d.data.points(:, idx_lheel, :));

t_hs = [evt.rfs; evt.lfs];
idx_rhs = round(c3d.parameters.POINT.RATE.DATA * evt.rfs) + 1;
idx_lhs = round(c3d.parameters.POINT.RATE.DATA * evt.lfs) + 1;
x_hs = [pts_rheel(1, idx_rhs), pts_lheel(1, idx_lhs)]';

[~, I] = sort(t_hs);
t_hs = t_hs(I);
x_hs = x_hs(I);

if ~is_discrete
    x_spd = x_spd([idx_rhs; idx_lhs]);
    x_spd = x_spd(I);
    x_spd = x_spd(2:end);
end

t = t_hs(2:end);
t_slen = 0.001 * diff(x_hs) + x_spd' .* diff(t_hs);
slen_stat = [mean(t_slen), std(t_slen)];
end

%     evt_ctx = c3d.parameters.EVENT.CONTEXTS.DATA;
%     evt_lab = c3d.parameters.EVENT.LABELS.DATA;
%     rhs = cellfun(@(x, y) strcmp(x, 'Right') & strcmp(y, 'Foot Strike'), evt_ctx, evt_lab);
%     lhs = cellfun(@(x, y) strcmp(x, 'Left') & strcmp(y, 'Foot Strike'), evt_ctx, evt_lab);
% 
%     evt_t = 60 * c3d.parameters.EVENT.TIMES.DATA(1, :) + c3d.parameters.EVENT.TIMES.DATA(2, :);
%     evt_t0 = (c3d.header.points.firstFrame - 1) / c3d.header.points.frameRate;
%     idx_evt = round(c3d.parameters.POINT.RATE.DATA * (evt_t - evt_t0)) + 1;
% 
%     pts_labels = c3d.parameters.POINT.LABELS.DATA;
% else
% 
% 
% 
% end
% 
%     idx_rheel = cellfun(@(x) strcmp(x, 'R.Heel'), pts_labels);
%     idx_lheel = cellfun(@(x) strcmp(x, 'L.Heel'), pts_labels);
%     pts_rheel = squeeze(c3d.data.points(:, idx_rheel, :));
%     pts_lheel = squeeze(c3d.data.points(:, idx_lheel, :));
% 
%     t_hs = [evt_t(rhs), evt_t(lhs)];
%     x_hs = [pts_rheel(1, idx_evt(rhs)), pts_lheel(1, idx_evt(lhs))];
% 
%     [~, I] = sort(t_hs);
%     t_hs = t_hs(I);
%     x_hs = x_hs(I);
% 
% t = t_hs - evt_t0;
% t_slen = 0.001 * diff(x_hs) + x_spd * diff(t_hs);
% slen_stat = [mean(t_slen), std(t_slen)];
