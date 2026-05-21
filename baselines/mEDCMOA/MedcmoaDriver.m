classdef MedcmoaDriver < TrialDriver
% MedcmoaDriver - TrialDriver subclass for mEDCMOA.
%
% Implements the multi-tribe evolutionary dynamic constrained multi-objective
% algorithm. mEDCMOA uses its own evolution logic (selectMatingPool, sbxPm,
% classifyTribes, selectPopulation) rather than the common evolve.m, and has
% a unique loop structure where the environment change check occurs BEFORE
% the evolution step, with a currentGenFES > 0 guard on evolution.
%
% Reference: mEDCMOA paper operator parameters (proC=0.8, disC=5, proM=0.05, disM=40).

    properties (Access = private)
        pop             % Current population [1×N Solution array]
        currentGenFES   % Remaining FES budget for current environment
        operatorParams  % SBX/PM operator parameters struct (mEDCMOA paper values)
        delta           % Per-variable search step sizes [D×1]
        eachGenMaxFES   % FES budget per environment change
        responseFESRate % Fraction of FES allocated to change response
    end

    methods
        function obj = MedcmoaDriver(config)
            obj@TrialDriver(config);
        end

        function result = run(this)
        % run - Execute mEDCMOA's trial loop.
        %
        %   mEDCMOA's loop differs from the standard Shape B loop:
        %   the environment change check occurs at the TOP of the loop
        %   (before evolution), and evolution is guarded by currentGenFES > 0.
        %
        %   Loop structure: change check → evolveStep (guarded) → gen++

            [this.problem, this.config, this.initialPop, this.state, this.controller, this.maxgen] = ...
                initTrial(this.config);
            this.initialize();
            ft = this.config.algo.maxGenPerEnv;

            while this.state.gen <= this.maxgen
                % --- Environment change check (at top of loop) ---
                if mod(this.state.gen, ft) == 0 && this.state.gen ~= 0
                    if this.controller.stepEnvironment(this.problem, this.currentPop())
                        break;
                    end
                    this.respondToChange();
                end

                % --- Evolution (guarded) ---
                this.evolveStep();

                if mod(this.state.gen, 100) == 0
                    fprintf('    Gen=%d\n', this.state.gen);
                end
                this.state.gen = this.state.gen + 1;
            end

            this.controller.finalSelect(this.currentPop());
            result = this.controller.getResult();
        end
    end

    methods (Access = protected)
        function initialize(this)
            this.pop = this.initialPop;

            % mEDCMOA paper operator parameters (proC=0.8, disC=5, proM=0.05, disM=40)
            this.operatorParams = struct('proC',0.8,'disC',5,'proM',0.05,'disM',40);

            % Coordinate-search step sizes: 10% of each variable's range,
            % floored at 1e-6 to avoid degenerate zero-width dimensions.
            ranges = this.config.domain(:, 2) - this.config.domain(:, 1);
            this.delta = max(ranges / 10, 1e-6);
            this.responseFESRate = 0.7;

            this.config.algo.preEvolution = 80;
            changeTimes = 60;
            problemIndex = this.config.run.problemIndex; %#ok<NASGU> preserved for maxFESTable indexing
            maxFESTable  = [900000000, 152000];
            this.eachGenMaxFES = floor( ...
                (maxFESTable(1, 1) - this.config.algo.preEvolution * this.config.algo.popSize) / changeTimes);

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
                offspringDecs = sbxPm(parentDecs, this.config.domain, this.operatorParams, 'full');

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
            responseConfig = this.config;
            responseConfig.eachGenMaxFES = this.eachGenMaxFES;
            responseConfig.responseFESRate = this.responseFESRate;
            responseConfig.delta = this.delta;
            [this.pop, FT, this.state, this.currentGenFES] = ...
                respondToChange(this.pop, responseConfig, this.state, this.problem, this.currentGenFES);

            % Update nondominated archive
            updateNondominatedSet(FT, Solution.empty(), this.config.algo.popSize);
        end

        function pop = currentPop(this)
            pop = this.pop;
        end
    end
end
