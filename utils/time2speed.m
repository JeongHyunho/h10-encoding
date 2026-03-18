function v = time2speed(tseries, time_rng, speed_rng)
% linear map from time to speed
v = (speed_rng(2) - speed_rng(1)) * (tseries - time_rng(1)) / (time_rng(2) - time_rng(1)) + speed_rng(1);
v(tseries > max(time_rng)) = max(speed_rng);
v(tseries < min(time_rng)) = min(speed_rng);
end
