function q = read_trcFile(fname)

fin = fopen(fname, 'r');	
if fin == -1								
	error(['unable to open ', fname])		
end

nextline = fgetl(fin);
nextline = fgetl(fin);
nextline = fgetl(fin);

values = sscanf(nextline, '%f %f %f %f');
numframes = values(3);
q.nummarkers = values(4);
numcolumns=3*q.nummarkers+2;

nextline = fgetl(fin);
q.labels = cell(1, q.nummarkers+2);
[q.labels{1}, nextline] = strtok(nextline); % should be Frame#
[q.labels{2}, nextline] = strtok(nextline); % should be Time
for i=1:q.nummarkers
	[markername, nextline] = strtok(nextline);
    q.labels{2+i} = markername;
end

nextline = fgetl(fin);
% READ

data = fscanf(fin, '%f', [numcolumns, numframes])';
assert(data(end) ~= 0, 'Empty data exists!')
q.frame = data(:, 1);
q.time = data(:, 2);
for i = 1:numel(q.labels)-2
    label = strrep(q.labels{i+2}, '.', '_');
    if ~isempty(regexp(label, '*', 'once')), continue, end
    q.(label) = struct('x', data(:, 3*i), ...
        'y', data(:, 3*i+1), ...
        'z', data(:, 3*i+2));
end
