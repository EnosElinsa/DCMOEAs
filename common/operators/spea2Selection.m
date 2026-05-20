function [population, fitness] = spea2Selection(population, N, ignoreConstraints)
% spea2Selection - SPEA2 environmental selection with distance-based truncation.
%   [population, fitness] = spea2Selection(population, N, ignoreConstraints)
%   Inputs:
%       population        - Array of standard Solution objects
%       N                 - Target size of the output population
%       ignoreConstraints - (Optional) Boolean flag. If true, calculate
%                           fitness without constraint violation penalties. Default is false.
%   Outputs:
%       population        - Selected Solution array sorted by fitness [1 x N]
%       fitness           - SPEA2 fitness values of selected individuals [1 x N]

    if nargin < 3
        ignoreConstraints = false;
    end

    objs = population.objs();
    
    %% Calculate the fitness of each solution
    if ignoreConstraints
        fitness = calFitness(objs);
    else
        cons = population.cons();
        fitness = calFitness(objs, cons);
    end

    %% Environmental selection target
    next = fitness < 1;
    
    if sum(next) < N
        % If fewer than N solutions have fitness < 1, grab the next best based on fitness
        [~, rank] = sort(fitness);
        next(rank(1:N)) = true;
    elseif sum(next) > N
        % If more than N solutions have fitness < 1, use distance-based truncation
        del = spea2Truncation(objs(next, :), sum(next) - N);
        temp = find(next);
        next(temp(del)) = false;
    end

    % Slice the selected solutions
    population = population(next);
    fitness    = fitness(next);

    % Sort final population descending by fitness
    [fitness, rankIndex] = sort(fitness);
    population = population(rankIndex);
end

function del = spea2Truncation(popObj, K)
% spea2Truncation - Select solutions to remove by distance-based truncation.
%   K is the number of solutions to delete.

    distance = pdist2(popObj, popObj);
    distance(logical(eye(size(distance, 1)))) = inf;
    
    del = false(1, size(popObj, 1));
    while sum(del) < K
        remain = find(~del);
        temp = sort(distance(remain, remain), 2);
        
        [~, rank] = sortrows(temp);
        
        % Delete the solution with the smallest k-th distance
        del(remain(rank(1))) = true;
    end
end
