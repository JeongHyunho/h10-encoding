function y = polynomial(c, x)
y = c(1) * ones(size(x));
for i =2:length(c)
    y = y + c(i) * x.^(i-1);
end
end
