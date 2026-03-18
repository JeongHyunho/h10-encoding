function K = stance_keep(hs, to, n)
n_st = numel(hs);
K = false(n, n_st-1);

for i = 1:n_st-1
    hs_ = hs(i); nhs_ = hs(i+1);

    rg = hs_ < to & to < nhs_;
    if sum(rg) ~= 1, continue, end

    to_ = to(rg);
    to_idx = round((to_ - hs_) / (nhs_ - hs_) * (n-1)) + 1;
    K(1:to_idx-1, i) = true;
end
end
