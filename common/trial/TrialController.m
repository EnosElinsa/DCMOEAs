classdef TrialController < handle
% TrialController - Execution controller for algorithm trials.
% Orchestrates the per-cycle loop: feasibility check → select best
% solution → execute decision → log snapshot → advance environment.
% Delegates all recording to TrialLogger.
%
% This is a problem-agnostic controller that works with any DynamicProblem
% subclass through the standard interface.

    properties
        logger       % TrialLogger
        weights      % [1 x M] objective weights
        problem      % DynamicProblem reference
    end

    methods
        function obj = TrialController(problem, config)
        % TrialController - Constructor.
        %   Initializes weights (equal if empty) and creates TrialLogger.
        %
        %   Inputs:
        %     problem - DynamicProblem instance
        %     config  - framework config struct with config.algo.weights
            obj.problem = problem;
            obj.weights = config.algo.weights;
            if isempty(obj.weights)
                obj.weights = ones(1, problem.nObj) / problem.nObj;
            end
            obj.logger = TrialLogger(problem);
        end

        function [bestSol, noFeasible, isDone] = stepEnvironment(obj, problem, pop)
        % stepEnvironment - End-of-cycle transition.
        %   1. Filter feasible solutions (cv == 0)
        %   2. Select best via weighted sum of normalized objectives
        %   3. Execute decision (updateAfterExecution)
        %   4. Record snapshot via TrialLogger
        %   5. Check termination (isDone)
        %   6. Advance environment (updateEnvironment)
        %
        %   Outputs:
        %     bestSol    - selected best feasible Solution (or [])
        %     noFeasible - true if no feasible solution exists
        %     isDone     - true if trial should terminate
            isDone = false;

            % Select best feasible solution
            feasibleMask = ([pop.cv] == 0);
            feasiblePop = pop(feasibleMask);

            if isempty(feasiblePop)
                obj.logger.markNoFeasible();
                noFeasible = true;
                isDone = true;
                bestSol = [];
                return;
            end
            noFeasible = false;

            bestSol = problem.selectBest(feasiblePop, obj.weights);

            % Execute decision
            info = problem.updateAfterExecution(bestSol.dec);

            % Record snapshot
            obj.logger.recordStep(problem, bestSol, pop, info);

            % Check termination
            if problem.isDone()
                isDone = true;
                return;
            end

            % Advance environment
            problem.updateEnvironment();

            if problem.isDone()
                isDone = true;
            end
        end

        function finalSelect(obj, pop)
        % finalSelect - Record the final selected solution from the last
        % population. Uses the same weighted selection logic as stepEnvironment.
            feasibleMask = ([pop.cv] == 0);
            feasiblePop = pop(feasibleMask);
            if ~isempty(feasiblePop)
                bestSol = obj.problem.selectBest(feasiblePop, obj.weights);
                obj.logger.recordFinalSelect(bestSol, pop);
            end
        end

        function result = getResult(obj)
        % getResult - Delegate to TrialLogger to package recorded data.
            result = obj.logger.getResult();
        end
    end
end
