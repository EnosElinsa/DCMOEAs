classdef (Abstract) TrialDriver < handle
% TrialDriver - Abstract base class for algorithm trial execution.
%
% Implements the unified Shape B trial loop: evolve → increment gen →
% change check. Concrete subclasses implement algorithm-specific logic
% via four abstract methods. run() is Sealed — subclasses must NOT
% override it.
%
% Round 3 extends the four-method seam with a beforeChangeCheck hook
% and unifies the trial loop onto a single canonical topology.
%
% Usage:
%   Subclass TrialDriver, implement initialize, evolveStep,
%   respondToChange, and currentPop. Then:
%     driver = MyAlgoDriver(config, problemFactory);
%     result = driver.run();

    properties (Access = protected)
        config          % Framework configuration struct
        problemFactory  % @(config) -> DynamicProblem (explicit, not smuggled through config)
        problem         % DynamicProblem instance
        controller      % TrialController instance
        state           % Runtime state struct (gen, fes)
        maxgen          % Total generation budget
        initialPop      % Evaluated initial population [1×N Solution array]
        progressEveryGen = 0   % Generation interval for progress fprintf (0 disables)
    end

    methods (Abstract, Access = protected)
        % initialize - Set up algorithm-private state from initial population.
        %   Called once after initTrial. Subclass stashes initialPop into
        %   its own properties.
        initialize(this)

        % evolveStep - Perform one generation of variation + selection.
        %   Mutates algorithm-private properties on this (handle semantics).
        %   Updates this.state in place (e.g., fes counter).
        evolveStep(this)

        % respondToChange - React to an environment change.
        %   Called after stepEnvironment returns false (trial continues).
        %   Subclass refreshes its population as needed.
        respondToChange(this)

        % currentPop - Return the current population for controller use.
        %   Returns the population used for feasibility-based decisions.
        pop = currentPop(this)
    end

    methods (Access = protected)
        function beforeChangeCheck(this) %#ok<MANU>
            % Default no-op. HATC overrides to stash memory archive.
        end
    end

    methods
        function obj = TrialDriver(config, problemFactory)
        % TrialDriver - Constructor.
        %   Stores the configuration and problem factory for use by run().
        %
        %   Input:
        %     config         - framework configuration struct (from createConfig)
        %     problemFactory - function handle @(config) -> DynamicProblem
            obj.config = config;
            obj.problemFactory = problemFactory;
        end
    end

    methods (Sealed)
        function result = run(this)
        % run - Execute the canonical trial loop. Sealed: subclasses must not override.
        %
        %   1. Initialize trial via initTrial
        %   2. Call subclass initialize()
        %   3. Loop: evolveStep → gen++ → maybeLogProgress → change check
        %   4. Final selection and result packaging
        %
        %   Output:
        %     result - struct from TrialController.getResult()

            [this.problem, this.config, this.initialPop, this.state, this.controller, this.maxgen] = ...
                initTrial(this.config, this.problemFactory);
            this.initialize();

            E = this.config.algo.maxGenPerEnv;
            while this.state.gen < this.maxgen
                this.evolveStep();
                this.state.gen = this.state.gen + 1;
                this.maybeLogProgress();
                if mod(this.state.gen, E) == 0
                    this.beforeChangeCheck();
                    if this.controller.stepEnvironment(this.problem, this.currentPop())
                        break;
                    end
                    this.respondToChange();
                end
            end

            this.controller.finalSelect(this.currentPop());
            result = this.controller.getResult();
        end
    end

    methods (Access = private)
        function maybeLogProgress(this)
            if this.progressEveryGen > 0 && ...
                    mod(this.state.gen, this.progressEveryGen) == 0
                fprintf('    Gen=%d\n', this.state.gen);
            end
        end
    end
end
