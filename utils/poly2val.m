function val = poly2val(A, x, y)
%POLY2VAL  2차원 선형 또는 다항식 표면(surface) 평가
%
%   val = POLY2VAL(A, x, y)
%
%   계수 행렬 A의 크기에 따라 선형 또는 2차 다항식 표면을 평가한다.
%     - A가 1x3 또는 3x1이면: z = b1*x + b2*y + b0  (1차 선형)
%     - A가 3x3이면: z = [x, y, 1] * A * [x, y, 1]' (2차 다항식)
%   x, y는 동일 크기의 행렬이 가능하며, 출력 val은 입력과 같은 크기.
%
%   입력:
%     A — 계수 행렬 [1x3, 3x1, 또는 3x3]
%     x — 첫 번째 변수 (스칼라, 벡터, 또는 행렬) [double]
%     y — 두 번째 변수 (x와 동일 크기) [double]
%
%   출력:
%     val — 표면 평가값 [size(x)와 동일]
%
%   알고리즘:
%     V = [x(:), y(:), 1] 벡터화 후:
%       선형(1x3/3x1): val = V * A(:)
%       2차(3x3):      val = sum((V * A) .* V, 2)
%     결과를 입력 x의 shape으로 reshape.
%
%   참고: fitKoller21

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
