function [outlier_indices, correctedSeries] = find_outliers(timeSeries, threshold)
    % 이동 중앙값 계산
    windowSize = 5; % 윈도우 크기 (필요에 따라 조정 가능)
    medianFiltered = movmedian(timeSeries, windowSize);

    % 이상치 탐지
    outliers = abs(timeSeries - medianFiltered) > threshold;

    % 이상치의 인덱스 반환
    outlier_indices = find(outliers);

    % 원본 시계열 데이터 복사
    correctedSeries = timeSeries;

    % 이상치 값 교체
    for i = reshape(outlier_indices, [1 length(outlier_indices)])
        if i == 1 % 첫 번째 인덱스는 다음 값으로 대체
            correctedSeries(i) = timeSeries(i+1);
        elseif i == length(timeSeries) % 마지막 인덱스는 이전 값으로 대체
            correctedSeries(i) = timeSeries(i-1);
        else
            % 이상치를 양옆 값의 평균으로 대체
            correctedSeries(i) = (timeSeries(i-1) + timeSeries(i+1)) / 2;
        end
    end
end
