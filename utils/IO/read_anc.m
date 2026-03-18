function q = read_anc(fnamein,transform)
%
% Reads anc file and converts digital force plate data to forces/moments
%
% Typically the FORCEPLA.CAL file is referred to for the forceplate calibration.  In the current code below
% we hardcoded the values from the relevant FORCEPLA.CAL file (for the Delaware dual-belt treadmill).
% The general file format for FORCEPLA.CAL is:
%
% <forceplate number>
% <scale> <length(cm)> <width(cm)>
% <6 x 6 calibration matrix AKA inverse sensitivity matrix>
% <true origin with respect to geometric center (cm)>
% <geometric center with respect to LCS origin (cm)>
% <3 x 3 orientation matrix>
% [repeat for next forceplate...]
%
% Note: gain = 1/scale
%
% It took me a while to figure out the conversion from anc to forces/moments, but basically the digital values (at least
% for this force plate setup) seemed to range between -2048 and 2047.  So you take a digital value, divide by this 2048 (or
% 2047.5 as c3dserver does it) range to get a normalized value, multiply by voltage range (10 V), divide by rain, and
% multiply by diagonal from calibration matrix.  Look through the code below for more info.
%
% Note: The c3dserver approach to computing forces from digital readings seems to be:
%       (10 / 2047.5) / gain * calibrationMatrixScale * (digitalValue + 1)
%       but this seems to give different results from what you get when you export forces from EVaRT and the code
%       below I think gives results closer to the latter...
%
%       For EMG, the c3dserver seems to take (digitalValue + 1)/4095

% Digital range is -2048 to +2047
% Voltage range is +/- 10V
analogScale = 10 / 2048;

% TODO: figure this out from anc file
q.analog_rate = 600;

% TODO: Read this from forcepla.cal instead of hardcoding it
FPinfo(1).calibrationDiagonals = [800 800 1500 375 1200 600];
FPinfo(1).FPcenterToFPorigin_FP = [-0.24 0.8175 0]';
FPinfo(1).LabToFPcenter_lab = [0.496 -0.288 -0.0075]';
FPinfo(1).orientationMatrix = [0 -1 0; -1 0 0; 0 0 -1];
FPinfo(1).gain = 2;

FPinfo(2).calibrationDiagonals = [800 800 1500 375 1200 600];
FPinfo(2).FPcenterToFPorigin_FP = [0.24 0.8175 0]';
FPinfo(2).LabToFPcenter_lab = [0.496 0.2265 -0.0075]';
FPinfo(2).orientationMatrix = [0 -1 0; -1 0 0; 0 0 -1];
FPinfo(2).gain = 2;

% -------------------------------------------------------------------

if nargin < 2
	transform = eye(3);
end

fin = fopen(fnamein, 'r');	
if fin == -1								
	error(['unable to open ', fnamein])		
end

nextline = fgetl(fin);
if ~strcmp(nextline, sprintf('File_Type:\tAnalog R/C ASCII\tGeneration#:\t1'))
	disp('Failed to match line 1');
	return;
end

nextline = fgetl(fin);
if ~strcmp(nextline, sprintf('Board_Type:\tNational PCI-MIO-64E-1\tPolarity:\tBipolar'))
	disp('Failed to match line 2');
	return;
end

nextline = fgetl(fin);
[name, trial, duration, channels] = strread(nextline, 'Trial_Name: %s Trial#: %d Duration(Sec.): %f #Channels: %d');

q.labels = cell(1, channels);

while true
	nextline = fgetl(fin);

	[tok, rest] = strtok(nextline);
	if strcmp(tok, 'Name')
		for i=1:channels
			[q.labels{i}, rest] = strtok(rest);
		end
	elseif strcmp(tok, 'Rate')
		q.rates = sscanf(rest, '%f');
	elseif strcmp(tok, 'Range')
		q.rates = sscanf(rest, '%f');		
		break;
	end
end

numcolumns = channels+1; % including time channel

% READ
data = fscanf(fin, '%f');

if mod(length(data),numcolumns) ~= 0
	disp('Data count not multiple of #channels');
	return;
end

numrows=length(data)/numcolumns;

data = reshape(data, numcolumns, numrows)';
q.time = data(:,1);

for fp=1:2
	% Extract digital readings for F and M
	q.data(fp).digitalF = data(:,6*(fp-1)+(2:4));
	q.data(fp).digitalM = data(:,6*(fp-1)+(5:7));

	% Convert 'reaction' forces and moments to 'action' forces and moments
	q.data(fp).F = -1 * q.data(fp).digitalF;
	q.data(fp).M = -1 * q.data(fp).digitalM;

	% Convert units (voltages to Newtons, Newtons-m)
	q.data(fp).F = (analogScale / FPinfo(fp).gain) * (q.data(fp).F * diag(FPinfo(fp).calibrationDiagonals(1:3)));
	q.data(fp).M = (analogScale / FPinfo(fp).gain) * (q.data(fp).M * diag(FPinfo(fp).calibrationDiagonals(4:6)));

	% Transform FP -> Lab -> Model
	q.data(fp).F = q.data(fp).F * FPinfo(fp).orientationMatrix' * transform';
	q.data(fp).M = q.data(fp).M * FPinfo(fp).orientationMatrix' * transform';

	% Translate
	FPcenterToFPorigin_lab =  FPinfo(fp).orientationMatrix * FPinfo(fp).FPcenterToFPorigin_FP;
	% not sure why we subtract the second vector instead of add, but seems to give answer consistent with EVaRT
	q.data(fp).FPorigin_model = transform * (FPinfo(fp).LabToFPcenter_lab - FPcenterToFPorigin_lab);
end

q.emg.labels = q.labels(13:end); % labels don't include time
q.emg.data = data(:,14:end);
