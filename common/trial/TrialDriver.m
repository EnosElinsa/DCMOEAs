classdef (Abstract) TrialDriver < handle
% TrialDriver - Abstract base class for algorithm trial execution.
%
% Implements the unified Shape B trial loop: evolve → increment gen →
% change check. Concrete subclasses implement algorithm-specific logic
% via four abstract methods.
%
% Usage:
%   Subclass TrialDriver, implement initialize, evolveStep,
%   respondToChange, and currentPop. Then:
%     driver = MyAlgoDriver(config);
%     result = driver.run();

    properties (Access = protected)
        config      % Framework configuration struct
        problem     % DynamicProblem instance
        controller  % TrialController instance
        state       % Runtime state struct (gen, fes)
        maxgen      % Total generation budget
        initialPop  % Evaluated initial population [1×N Solution array]
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

    methods
        function obj = TrialDriver(config)
        % TrialDriver - Constructor.
        %   Stores the configuration for use by run().
        %
        %   Input:
        %     config - framework configuration struct (from createConfig)
            obj.config = config;
        end

        function result = run(this)
        % run - Execute the unified Shape B trial loop.
        %
        %   1. Initialize trial via initTrial
        %   2. Call subclass initialize()
        %   3. Loop: evolveStep → gen++ → change check
        %   4. Final selection and result packaging
        %
        %   Output:
        %     result - struct from TrialController.getResult()

            [this.problem, this.config, this.initialPop, this.state, this.controller, this.maxgen] = ...
                initTrial(this.config);
            this.initialize();

            while this.state.gen < this.maxgen
                this.evolveStep();
                this.state.gen = this.state.gen + 1;

                if mod(this.state.gen, this.config.algo.maxGenPerEnv) == 0
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
end
