function q = read_motFile(fname, device_rate, cut_freq)

if nargin < 2
    cut_freq = nan;
else
    [b, a] = butter(6, cut_freq/(device_rate/2));
end

% check number and type of argument
assert(ischar(fname) || isstring(fname), ...
    'Input must be a string representing a filename')

% open the file
fin = fopen(fname, 'r');	
assert(fin ~= -1, ['unable to open ', fname])

% initialize variables
infos = {};
q = struct('infos', []);

% process file infos before header
line = fgetl(fin);
i = 1;
while ~strcmp(line, 'endheader')
    infos{i} = line;
    line = fgetl(fin);
    i = i + 1;
end
q.infos = infos;

% read header and data
header = strsplit(fgetl(fin));
data = reshape(fscanf(fin, '%f'), length(header), [])';
fclose(fin);

for i = 1:length(header)
    if isnan(cut_freq) || ismember(header{i}, {'time'})
        d_ = data(:, i);
    else
        d_ = filtfilt(b, a, data(:, i));
    end
    q.(header{i}) = d_;
end
