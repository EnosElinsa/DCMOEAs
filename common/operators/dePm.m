function offspring = dePm(p1, p2, p3, domain, CR, F, proM, disM)
% dePm - DE/rand/1 crossover + polynomial mutation bundle.
% Composes deCrossover and polynomialMutation to replicate the full
% operatorDE pipeline as a thin wrapper over the two primitives.
%
% Inputs:
%   p1, p2, p3 - [N x D] parent matrices
%   domain     - [2 x D] or [D x 2] bounds (passed through to polynomialMutation)
%   CR         - per-bit crossover probability (scalar)
%   F          - differential weight (scalar)
%   proM       - base mutation probability (divided by D internally)
%   disM       - distribution index for polynomial mutation
% Output:
%   offspring  - [N x D] offspring decision variables

    [~, D] = size(p1);
    crossed   = deCrossover(p1, p2, p3, CR, F);
    offspring = polynomialMutation(crossed, domain, proM/D, disM);
end
