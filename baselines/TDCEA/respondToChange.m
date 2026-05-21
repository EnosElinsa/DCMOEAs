function [newPop, state] = respondToChange(config, state, problem, pop, number)
% respondToChange - TDCEA diversity compensation strategy (TDC).
% Re-evaluates population, applies feasibility-driven perturbation
% using centroid shift between consecutive environments, plus random
% replacement of a fraction of individuals.
%
% Inputs:
%   config  - configuration struct
%   problem - DynamicProblem instance
%   pop     - Solution object array (current population, may be multi-row history)
%   number  - current environment index (>= 2 means history available)
% Outputs:
%   newPop  - Solution object array after change response

    N = config.algo.popSize;
    domain = problem.getDomain();  % [D x 2]
    lowerBound = repmat(domain(:, 1)', N, 1);  % [N x D]
    upperBound = repmat(domain(:, 2)', N, 1);  % [N x D]

    %% Re-evaluate current population under new environment
    decMat = pop.decs();  % [N x D]
    newPop = decsToEvaluatedPop(decMat, problem, state);

    %% Detect change magnitude
    change1 = sum(sum(abs(pop.objs() - newPop.objs()), 2));
    if change1 >= 1e-6
        lambda = 1;
    else
        lambda = 0;
    end

    %% Feasibility analysis
    numCons = size(newPop(1).con, 2);
    conMat = newPop.cons();  % [N x numCons]
    feasible = sum(conMat <= 0, 2) == numCons;
    numFeasible = sum(feasible);
    feasibleRate = numFeasible / N;

    %% Perturbation using centroid shift
    if number > 2
        % Use centroid of previous and current populations
        centroid = zeros(2, size(decMat, 2));
        % Previous centroid approximated from current pop before re-eval
        centroid(1, :) = mean(pop.decs(), 1);
        centroid(2, :) = mean(decMat, 1);
        interval = centroid(2, :) - centroid(1, :);

        dec1 = decMat + lambda * feasibleRate * unifrnd(repmat(min(interval, 0), N, 1), repmat(max(interval, 0), N, 1));
        dec2 = decMat - (1 - feasibleRate) * unifrnd(repmat(min(interval, 0), N, 1), repmat(max(interval, 0), N, 1));

        % Boundary repair (reflection)
        dec1(dec1 < lowerBound) = 2 * lowerBound(dec1 < lowerBound) - dec1(dec1 < lowerBound);
        dec1(dec1 > upperBound) = 2 * upperBound(dec1 > upperBound) - dec1(dec1 > upperBound);
        dec2(dec2 < lowerBound) = 2 * lowerBound(dec2 < lowerBound) - dec2(dec2 < lowerBound);
        dec2(dec2 > upperBound) = 2 * upperBound(dec2 > upperBound) - dec2(dec2 > upperBound);

        % Split by feasibility
        dec1(~feasible, :) = [];
        dec2(feasible, :) = [];
    else
        dec1 = decMat(feasible, :);
        dec2 = decMat(~feasible, :);
    end

    %% Random replacement
    alpha = round(0.1 * N);
    np1 = round(feasibleRate * alpha);
    np2 = alpha - np1;

    rand1 = unifrnd(repmat(domain(:, 1)', round(np1), 1), repmat(domain(:, 2)', round(np1), 1));
    rand2 = unifrnd(repmat(domain(:, 1)', round(np2), 1), repmat(domain(:, 2)', round(np2), 1));

    if numFeasible > 0 && np1 > 0
        idx1 = randperm(size(dec1, 1), min(np1, size(dec1, 1)));
        dec1(idx1, :) = rand1(1:length(idx1), :);
    end
    if (N - numFeasible) > 0 && np2 > 0
        idx2 = randperm(size(dec2, 1), min(np2, size(dec2, 1)));
        dec2(idx2, :) = rand2(1:length(idx2), :);
    end

    %% Evaluate combined population
    allDec = [dec1; dec2];
    newPop = decsToEvaluatedPop(allDec, problem, state);
end


