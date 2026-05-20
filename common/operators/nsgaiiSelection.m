function [population, frontNo, crowdDis] = nsgaiiSelection(population, N, ignoreConstraints)
% nsgaiiSelection - NSGA-II environmental selection supporting Solution objects.
%   [population, frontNo, crowdDis] = nsgaiiSelection(population, N, ignoreConstraints)
%   Performs non-dominated sorting and crowding distance-based truncation to
%   select exactly N individuals from the provided population array.
%   Inputs:
%       population        - Array of standard Solution objects
%       N                 - Target size of the output population
%       ignoreConstraints - (Optional) Boolean flag. If true, constraint
%                           violations will be ignored during sorting. Default is false.
%   Outputs:
%       population        - Array of selected Solution objects [1 x N]
%       frontNo           - Front numbers of exactly the selected individuals [1 x N]
%       crowdDis          - Crowding distances of exactly the selected individuals [1 x N]

    if nargin < 3
        ignoreConstraints = false;
    end

    objs = population.objs();
    
    if ignoreConstraints
        % Ignore constraint values entirely, treating all as feasible
        cons = zeros(size(objs, 1), 1);
    else
        cons = population.cons();
    end

    %% Non-dominated sorting
    [frontNo, maxFNo] = ndSort(objs, cons, N);
    
    % Mask of solutions firmly within the accepted fronts
    next = frontNo < maxFNo;
    
    %% Calculate the crowding distance of each solution
    crowdDis = crowdingDistance(objs, frontNo);
    
    %% Select solutions in the last partial front based on crowding distances
    lastIndices = find(frontNo == maxFNo);
    
    % Sort indices of the last front by crowding distance descending
    [~, rank]   = sort(crowdDis(lastIndices), 'descend');
    
    % Number of remaining slots to fill
    numNeeded = N - sum(next);
    
    % Select the top numNeeded elements from the sorted last front
    next(lastIndices(rank(1:numNeeded))) = true;
    
    %% Output Generation
    population = population(next);
    frontNo    = frontNo(next);
    crowdDis   = crowdDis(next);
end
