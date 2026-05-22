classdef MedcmoaDriver < TrialDriver
% MedcmoaDriver - TrialDriver subclass for mEDCMOA.
%
% Implements the multi-tribe evolutionary dynamic constrained multi-objective
% algorithm. mEDCMOA uses its own evolution logic (selectMatingPool, sbxPm,
% classifyTribes, selectPopulation) rather than the common evolve.m, and has
% a currentGenFES > 0 guard on evolution inside evolveStep.
%
% Reference: mEDCMOA paper operator parameters (proC=0.8, disC=5, proM=0.05, disM=40).

    properties (Access = private)
        pop             % Current population [1×N Solution array]
        currentGenFES   % Remaining FES budget for current environment
        operatorParams  % SBX/PM operator parameters struct (mEDCMOA paper values)
        delta           % Per-variable search step sizes [D×1]
        eachGenMaxFES   % FES budget per environment change
        responseFESRate % Fraction of FES allocated to change response
        preEvolution    % Pre-evolution generation count (mEDCMOA paper: 80)
    end

    methods
        function obj = MedcmoaDriver(config, problemFactory)
            obj@TrialDriver(config, problemFactory);
            obj.progressEveryGen = 100;
        end
    end

    methods (Access = protected)
        function initialize(this)
            this.pop = this.initialPop;

            % mEDCMOA paper operator parameters (proC=0.8, disC=5, proM=0.05, disM=40)
            this.operatorParams = struct('proC',0.8,'disC',5,'proM',0.05,'disM',40);

            % Coordinate-search step sizes: 10% of each variable's range,
            % floored at 1e-6 to avoid degenerate zero-width dimensions.
            domain = this.problem.getDomain();
            ranges = domain(:, 2) - domain(:, 1);
            this.delta = max(ranges / 10, 1e-6);
            this.responseFESRate = 0.7;

            this.preEvolution = 80;
            changeTimes = 60;
            % mEDCMOA paper Table II: total FES budget (ADR-0002, ADR-0003)
            totalMaxFES = 900000000;
            this.eachGenMaxFES = floor( ...
                (totalMaxFES - this.preEvolution * this.config.algo.popSize) / changeTimes);

            this.currentGenFES = Inf;
        end

        function evolveStep(this)
        % evolveStep - One generation of mEDCMOA evolution.
        %   Guarded by currentGenFES > 0: if the FES budget for the current
        %   environment is exhausted, no evolution occurs (a non-trivial
        %   difference from other baselines).

            if this.currentGenFES > 0
                popParent = selectMatingPool(this.pop);
                parentDecs = this.pop.decs();
                parentDecs = parentDecs(popParent', :);
                offspringDecs = sbxPm(parentDecs, this.problem.getDomain(), this.operatorParams, 'full');

                offspring = Solution.fromDecs(offspringDecs);
                [offspring, this.state] = evaluatePopulation(this.problem, offspring, this.state);
                this.currentGenFES = this.currentGenFES - size(offspringDecs, 1);

                [FT, DIT, NIT, ~] = classifyTribes(this.pop, offspring, Solution.empty());
                this.pop = selectPopulation(FT, DIT, NIT, this.config.algo.popSize);
            end
        end

        function respondToChange(this)
        % respondToChange - React to an environment change.
        %   Resets FES budget, re-evaluates population, runs tribe-based
        %   response, and updates the nondominated set.

            this.currentGenFES = this.eachGenMaxFES;

            % Re-evaluate after environment change
            [this.pop, this.state] = evaluatePopulation(this.problem, this.pop, this.state);
            this.currentGenFES = this.currentGenFES - numel(this.pop);

            % Tribe-based change response
            responseParams = struct( ...
                'eachGenMaxFES',   this.eachGenMaxFES, ...
                'responseFESRate', this.responseFESRate, ...
                'delta',           this.delta, ...
                'popSize',         this.config.algo.popSize, ...
                'domain',          this.config.domain);
            [this.pop, FT, this.state, this.currentGenFES] = ...
                respondToChange(this.pop, responseParams, this.state, this.problem, this.currentGenFES);

            % Update nondominated archive
            updateNondominatedSet(FT, Solution.empty(), this.config.algo.popSize);
        end

        function pop = currentPop(this)
            pop = this.pop;
        end
    end
end
