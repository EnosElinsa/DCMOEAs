function [pop1, pop2, problem, noFeasibleFlag, state] = ...
    tdceaAlgorithm(config, state, problem, pop1, pop2, controller)
% tdceaAlgorithm - Core TDCEA dual-population SPEA2 coevolution loop.
% Uses differential evolution operators with dual populations:
%   pop1 considers constraints, pop2 ignores constraints.
% SPEA2 environmental selection on both populations.
%
% Inputs:
%   config      - configuration struct
%   state       - runtime state struct
%   problem     - UAVHAP problem instance
%   pop1        - Solution object array (constrained population)
%   pop2        - Solution object array (unconstrained population)
%   controller  - TrialController instance for environment step triggers
% Outputs:
%   pop1, pop2       - final populations
%   problem          - updated problem instance
%   noFeasibleFlag   - true if no feasible solutions found at a change point

    N = config.algo.popSize;
    maxgen = config.maxGenPerEnv * problem.tMax;
    ft = config.maxGenPerEnv;
    domain = config.domain;  % [D x 2]

    noFeasibleFlag = false;
    number = 1;

    %% Initial fitness
    fitness1 = calFitness(pop1.objs(), pop1.cons());
    fitness2 = calFitness(pop2.objs());

    %% Operator parameters
    %% DE keeps CR/F at DE defaults; proM/disM feed the polynomial-mutation step.
    op = struct('proC',1,'disC',20,'proM',1,'disM',20);
    deParams = {1, 0.5, op.proM, op.disM};

    %% Main evolution loop
    while maxgen > state.gen
        %% DE-based offspring generation (N/2 offspring each)
        matingPool1 = tournamentSelection(2, N, fitness1);
        matingPool2 = tournamentSelection(2, N, fitness2);
        halfN = floor(N / 2);

        % DE for pop1: parent1 = random subset of pop1 (N/2), parent2/3 from mating pool halves
        offDec1 = operatorDE(domain', ...
            pop1(randperm(N, halfN)).decs(), ...
            pop1(matingPool1(1:halfN)).decs(), ...
            pop1(matingPool1(halfN + 1 : 2 * halfN)).decs(), deParams);
        offspring1 = decsToEvaluatedPop(offDec1, problem, state);

        % DE for pop2: same structure
        offDec2 = operatorDE(domain', ...
            pop2(randperm(N, halfN)).decs(), ...
            pop2(matingPool2(1:halfN)).decs(), ...
            pop2(matingPool2(halfN + 1 : 2 * halfN)).decs(), deParams);
        offspring2 = decsToEvaluatedPop(offDec2, problem, state);

        %% Environmental selection
        [pop1, fitness1] = spea2Selection([pop1, offspring1, offspring2], N, false);
        [pop2, fitness2] = spea2Selection([pop2, offspring1, offspring2], N, true);

        state.gen = state.gen + 1;

        %% Change point logic
        if mod(state.gen, ft) == 0
            [~, ~, isComplete] = controller.stepEnvironment(problem, pop1);
            if isComplete
                if controller.logger.noFeasibleFlag
                    noFeasibleFlag = true;
                end
                return;
            end

            %% Change response (TDC)
            number = number + 1;
            [newPop, state] = respondToChange(config, state, problem, pop1, number);
            pop1 = newPop;
            pop2 = newPop;
            fitness1 = calFitness(pop1.objs(), pop1.cons());
            fitness2 = calFitness(pop2.objs());
        end

        if mod(state.gen, 50) == 0
            fprintf('    Gen=%d\n', state.gen);
        end
    end
end


