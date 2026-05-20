function offspring = operatorGA(inds, matingPool, domain, op)
% operatorGA - SBX crossover + polynomial mutation generating both offspring
% halves. Wraps sbxCrossover/polynomialMutation against the shared
% operatorParams convention (proM is in *rate* form: per-bit probability =
% op.proM/D).
% Inputs:
% inds       - [N x D] decision variable matrix (row-per-individual)
% matingPool - indices of selected parents (length must be 2*K)
% domain     - [D x 2] variable bounds [lower, upper]
% op         - operatorParams struct with fields proC, disC, proM, disM
% Outputs:
% offspring  - [2*K x D] offspring decision variables

    parent1 = inds(matingPool(1 : length(matingPool)/2), :);
    parent2 = inds(matingPool(length(matingPool)/2 + 1 : end), :);
    D = size(parent1, 2);

    %% Simulated binary crossover
    [off1, off2] = sbxCrossover(parent1, parent2, op.proC, op.disC);

    %% Polynomial mutation (rate form: per-bit probability = op.proM/D)
    offspring = polynomialMutation([off1; off2], domain, op.proM/D, op.disM);
end
