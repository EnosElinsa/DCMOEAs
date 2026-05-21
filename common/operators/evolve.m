function [pop, state] = evolve(config, state, problem, pop, operatorParams)
% evolve - NSGA-II SBX+PM evolution step (shared).
% Uses calFitness + tournamentSelection from common/operators/.
% Inputs:
%   config         - static configuration struct
%   state          - mutable runtime state
%   problem        - DynamicProblem instance
%   pop            - Solution object array [1 x popSize]
%   operatorParams - struct with fields proC, disC, proM, disM
%                    (variation operator parameters, owned by caller)
% Outputs:
%   pop   - updated Solution object array [1 x popSize]
%   state - updated state

    popsize = config.algo.popSize;

    %% Guard: population size must be even for mating pool split
    if mod(popsize, 2) ~= 0
        error('evolve:oddPopSize', 'Population size must be even for mating pool split.');
    end

    domain = problem.getDomain();

    %% Extract matrices from Solution array (row-per-individual)
    parentDecs = pop.decs();   % [N x D]
    parentObjs = pop.objs();   % [N x M]
    parentCons = pop.cons();   % [N x K]

    %% Mating selection via SPEA2 fitness + binary tournament
    fitnessPop = calFitness(parentObjs, parentCons);
    matingPool = tournamentSelection(2, popsize, fitnessPop);

    %% SBX + Polynomial Mutation
    op = operatorParams;
    parent1 = parentDecs(matingPool(1:popsize/2), :);
    parent2 = parentDecs(matingPool(popsize/2+1:end), :);
    [~, D] = size(parent1);
    [off1, off2] = sbxCrossover(parent1, parent2, op.proC, op.disC);
    offspringDecs = polynomialMutation([off1; off2], domain, op.proM/D, op.disM);

    %% Build offspring Solution array using static factory and evaluate
    offspring = Solution.fromDecs(offspringDecs);
    [offspring, state] = evaluatePopulation(problem, offspring, state);

    %% NSGA-II Environmental Selection
    pop = nsgaiiSelection([pop, offspring], popsize);
end
