function [isValid, reason] = is_valid_mvc(dataVector, varargin)
%IS_VALID_MVC Checks if an EMG data vector for an MVC trial is valid.
%
%   [isValid, reason] = IS_VALID_MVC(dataVector) analyzes the provided 
%   dataVector to determine if it represents a successful MVC trial. 
%   The function returns true if the signal is valid, and false otherwise,
%   along with a reason code.
%
%   A valid signal is expected to have a clear, sustained, envelope-like
%   shape, rising from a baseline, holding a contraction, and relaxing.
%
%   The function uses two main checks:
%   1. Peak Significance: The peak signal must be significantly higher
%      than the baseline noise.
%   2. Sustained Duration: The signal must remain above a certain
%      threshold for a minimum duration, filtering out random spikes.
%
%   [isValid, reason] = IS_VALID_MVC(dataVector, 'PARAM_NAME', value, ...) 
%   allows for overriding the default thresholds.
%
%   Parameters:
%       'BaselineEndPercent' (default: 0.2): Fraction of the initial data
%           to be considered as baseline noise (e.g., 0.2 = first 20%).
%       'PeakStdMultiple' (default: 1): The signal's peak must be at least
%           this many standard deviations above the baseline mean.
%       'SustainedDurationPercent' (default: 0.1): The signal must be
%           above the high-activity threshold for at least this fraction
%           of its total duration (e.g., 0.1 = 10% of the time).
%       'SustainedThresholdPercent' (default: 0.5): The threshold for
%           defining "high-activity", as a fraction of the peak amplitude
%           (e.g., 0.5 = 50% of the peak).
%       'MinPeakValue' (default: 1e-5): An absolute minimum peak value to
%           reject signals that are essentially zero.

    % --- 1. Configuration & Default Thresholds ---
    p = inputParser;
    addRequired(p, 'dataVector', @isnumeric);
    addParameter(p, 'BaselineEndPercent', 0.2, @isnumeric);
    addParameter(p, 'PeakStdMultiple', 1, @isnumeric);
    addParameter(p, 'SustainedDurationPercent', 0.1, @isnumeric);
    addParameter(p, 'SustainedThresholdPercent', 0.5, @isnumeric);
    addParameter(p, 'MinPeakValue', 1e-5, @isnumeric);
    parse(p, dataVector, varargin{:});

    THRESHOLDS = p.Results;
    
    % --- Initial state ---
    isValid = true;
    reason = 'VALID';

    % --- 2. Input Validation ---
    if isempty(dataVector) || ~isvector(dataVector) || length(dataVector) < 20
        isValid = false;
        reason = 'INVALID_INPUT';
        return;
    end
    
    % Ensure data is a column vector
    dataVector = dataVector(:);

    % --- 3. Calculations ---
    % Define baseline period (initial part of the signal)
    baseline_end_index = round(length(dataVector) * THRESHOLDS.BaselineEndPercent);
    baseline_data = dataVector(1:baseline_end_index);
    
    % Signal properties
    peak_amplitude = max(dataVector);
    baseline_mean = mean(baseline_data);
    baseline_std = std(baseline_data);

    % --- 4. Perform Checks ---
    % CHECK 1: Trivial Signal Check (is it just a flat line?)
    % The peak must be significantly above the baseline noise.
    if peak_amplitude < (baseline_mean + THRESHOLDS.PeakStdMultiple * baseline_std) || peak_amplitude < THRESHOLDS.MinPeakValue
        isValid = false;
        reason = 'INSUFFICIENT_PEAK';
        return;
    end

    % CHECK 2: Sustained Contraction Check (is it an envelope or just a spike?)
    % The signal must stay high for a certain duration.
    high_activity_threshold = peak_amplitude * THRESHOLDS.SustainedThresholdPercent;
    sustained_points_count = sum(dataVector > high_activity_threshold);
    min_sustained_duration_points = length(dataVector) * THRESHOLDS.SustainedDurationPercent;

    if sustained_points_count < min_sustained_duration_points
        isValid = false;
        reason = 'INSUFFICIENT_DURATION';
        return;
    end
end
