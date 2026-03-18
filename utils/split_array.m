function sub_arrays = split_array(array, indices)
%   Examples:
%       array = [1, 2, 3, 4, 5];
%       indices = [2, 4];
%       sub_arrays = split_array(array, indices);       % {[1, 2], [3, 4], [4]}

if isscalar(indices)
    array_len = numel(array);
    sub_array_len = floor(array_len / indices);
    remainder = mod(array_len, indices);
    sub_arrays = cell(1, indices);
    
    srt_idx = 1;
    for i = 1:indices
        end_idx = srt_idx + sub_array_len - 1;
        if i <= remainder
            end_idx = end_idx + 1;
        end
        sub_arrays{i} = array(srt_idx:end_idx);
        srt_idx = end_idx + 1;
    end
else
        indices = unique(indices(:));
        split_pts = [0; indices; numel(array)];
        sub_array_len = numel(indices) + 1;
        sub_arrays = cell(1, sub_array_len);
        
        for i = 1:sub_array_len
            srt_idx = split_pts(i) + 1;
            end_idx = split_pts(i+1);
            sub_arrays{i} = array(srt_idx:end_idx);
        end
end
