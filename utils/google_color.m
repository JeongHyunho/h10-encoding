function c = google_color(code)
assert(isstring(code) || ischar(code))

switch lower(code)
    case {'b', 'blue'}
        c = [66, 133, 244] / 255;
    case {'r', 'red'}
            c = [234, 67, 53] / 255;
    case {'y', 'yellow'}
        c = [251, 188, 5] / 255;
    case {'g', 'green'}
        c = [52, 168, 83] / 255;
    otherwise
        error('wrong code: %s', code)
end
