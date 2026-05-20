function [pop, state] = respondToChange(config, state, problem, pop)
% respondToChange - DNSGA-II-A change response.
% Replaces a fraction of population with random individuals,
% then re-evaluates entire population.
% Inputs:
%   config  - static configuration struct
%   state   - mutable runtime state
%   problem - DynamicProblem instance
%   pop     - Solution object array [1 x popSize]
% Outputs:
%   pop   - updated Solution object array after change response
%   state - updated state

    popsize = numel(pop);
    N = floor(popsize * config.algo.replacementRate / 2) * 2;
    selected = randperm(popsize, N);

    %% DNSGA-II-A: Replace selected individuals with random points
    domain = config.domain;
    D = size(domain, 1);
    for i = 1:N
        newDec = domain(:, 1) + (domain(:, 2) - domain(:, 1)) .* rand(D, 1);
        pop(selected(i)).dec = newDec';
    end

    %% Re-evaluate entire population
    [pop, state] = evaluatePopulation(problem, pop, state);
end
