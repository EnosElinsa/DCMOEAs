classdef TdceaDriver < TrialDriver
% TdceaDriver - TrialDriver subclass for TDCEA.
%
% Implements the dual-population SPEA2 coevolution algorithm with
% differential evolution operators. pop1 considers constraints,
% pop2 ignores constraints. Both populations share offspring.
%
% Change response uses the TDC (Two-population Diversity Compensation)
% strategy via the external respondToChange function.
%
% Reference: TDCEA paper operator parameters (DE: CR=1, F=0.5; PM: proM=1, disM=20).

    properties (Access = private)
        pop1            % Constrained population [1×N Solution array]
        pop2            % Unconstrained population [1×N Solution array]
        fitness1        % SPEA2 fitness values for pop1 [1×N]
        fitness2        % SPEA2 fitness values for pop2 [1×N]
        number          % Environment index counter (for TDC centroid shift)
        operatorParams  % DE/PM operator parameters struct
    end

    methods
        function obj = TdceaDriver(config, problemFactory)
            obj@TrialDriver(config, problemFactory);
        end
    end

    methods (Access = protected)
        function initialize(this)
            this.pop1 = this.initialPop;
            this.pop2 = this.initialPop;

            this.fitness1 = calFitness(this.pop1.objs(), this.pop1.cons());
            this.fitness2 = calFitness(this.pop2.objs());

            this.number = 1;

            % DE/PM parameters (TDCEA paper: CR=1, F=0.5, proM=1, disM=20)
            this.operatorParams = struct('proC',1,'disC',20,'proM',1,'disM',20);
        end

        function evolveStep(this)
        % evolveStep - One generation of dual-population DE + SPEA2 selection.
        %   Generates N/2 offspring from each population using DE/PM,
        %   then applies SPEA2 environmental selection on the combined
        %   parent+offspring pools.

            N = this.config.algo.popSize;
            halfN = floor(N / 2);
            op = this.operatorParams;
            domain = this.problem.getDomain();

            %% Tournament selection based on SPEA2 fitness
            matingPool1 = tournamentSelection(2, N, this.fitness1);
            matingPool2 = tournamentSelection(2, N, this.fitness2);

            %% DE-based offspring generation for pop1
            offDec1 = dePm( ...
                this.pop1(randperm(N, halfN)).decs(), ...
                this.pop1(matingPool1(1:halfN)).decs(), ...
                this.pop1(matingPool1(halfN + 1 : 2 * halfN)).decs(), ...
                domain, 1, 0.5, op.proM, op.disM);
            [offspring1, this.state] = decsToEvaluatedPop(offDec1, this.problem, this.state);

            %% DE-based offspring generation for pop2
            offDec2 = dePm( ...
                this.pop2(randperm(N, halfN)).decs(), ...
                this.pop2(matingPool2(1:halfN)).decs(), ...
                this.pop2(matingPool2(halfN + 1 : 2 * halfN)).decs(), ...
                domain, 1, 0.5, op.proM, op.disM);
            [offspring2, this.state] = decsToEvaluatedPop(offDec2, this.problem, this.state);

            %% SPEA2 environmental selection
            [this.pop1, this.fitness1] = spea2Selection([this.pop1, offspring1, offspring2], N, false);
            [this.pop2, this.fitness2] = spea2Selection([this.pop2, offspring1, offspring2], N, true);
        end

        function respondToChange(this)
        % respondToChange - React to an environment change using TDC strategy.
        %   Increments the environment counter, delegates to the external
        %   respondToChange function, then resets both populations and fitness.

            this.number = this.number + 1;

            [newPop, this.state] = respondToChange(this.config, this.state, ...
                this.problem, this.pop1, this.number);

            this.pop1 = newPop;
            this.pop2 = newPop;
            this.fitness1 = calFitness(this.pop1.objs(), this.pop1.cons());
            this.fitness2 = calFitness(this.pop2.objs());
        end

        function pop = currentPop(this)
            pop = this.pop1;
        end
    end
end
