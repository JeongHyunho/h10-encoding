function [cleanData, idxKeep, idxOut] = removePhaseOutliers(data, k)
%REMOVEPHASEOUTLIERS  Discard atypical phase-normalized curves (no plotting)
%
%   [cleanData, idxKeep, idxOut] = removePhaseOutliers(data, k)
%
%   INPUT
%     data : m-by-n matrix  
%            (m curves × n phase samples, n ≈ 100)
%     k    : threshold scale (optional, default = 3)
%            → curve i is rejected if
%                RMSE_i > median(RMSE) + k·MAD(RMSE)
%
%   OUTPUT
%     cleanData : matrix containing only retained curves
%     idxKeep   : logical index of kept rows  (m×1)
%     idxOut    : logical index of removed rows (m×1)
%
%   METHOD
%     • Compute robust reference curve (median across rows).
%     • For each curve, compute RMSE w.r.t. reference.
%     • Reject curves whose RMSE exceeds the robust threshold.
%
%   EXAMPLE
%     [Dclean, keepIdx, outIdx] = removePhaseOutliers(D);  % D=m×n
%     fprintf('kept %d / %d curves (removed %d)\n', ...
%             nnz(keepIdx), size(D,1), nnz(outIdx));
%
%--------------------------------------------------------------------------

    arguments
        data double
        k    double = 3
    end

    %-- 1) 기준 곡선: 중앙값
    refCurve = median(data, 1, 'omitnan');        % 1×n

    %-- 2) 각 곡선과의 RMSE
    rmse = sqrt(mean((data - refCurve).^2, 2, 'omitnan'));  % m×1

    %-- 3) robust threshold: median + k·MAD
    medRMSE = median(rmse, 'omitnan');
    madRMSE = 1.4826 * median(abs(rmse - medRMSE), 'omitnan');
    thresh  = medRMSE + k * madRMSE;

    idxOut  = rmse > thresh;
    idxKeep = ~idxOut;
    cleanData = data(idxKeep, :);
end
