function val = poly2val(A, x, y)
% 2차원 linear or polynomial surface evaluation 실시 
% linear: z = A * [x, y, 1]
% polynomial: z = [x, y, 1] * A * [x, y, 1]'
% val = reshape(z, size(x))

[row, col] = size(A);
V = [x(:), y(:), ones(numel(x), 1)];

if (row == 1 && col == 3) || (row == 3 && col == 1)
    val = V * reshape(A, 3, 1);
elseif row == 3 && col == 3
    val = sum((V * A) .* V, 2);
else
    error('unexpected A: row(%d), col(%d)', row, col)
end

val = reshape(val, size(x));
