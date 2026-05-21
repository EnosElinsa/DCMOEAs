function offspring = deCrossover(p1, p2, p3, CR, F)
% deCrossover - DE/rand/1 + binomial crossover primitive.
% Computes p1 + F*(p2-p3) on dimensions selected by binomial CR.
% Pure crossover step: no polynomial mutation and no boundary clipping
% are applied here — those are the caller's concern.
%
% Inputs:
%   p1, p2, p3 - [N x D] parent matrices
%   CR          - per-bit crossover probability (scalar)
%   F           - differential weight (scalar)
% Output:
%   offspring   - [N x D]

    [N, D] = size(p1);
    site = rand(N, D) < CR;
    offspring       = p1;
    offspring(site) = offspring(site) + F*(p2(site) - p3(site));
end
