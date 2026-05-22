classdef CrdcmoDriver < TrialDriver
% CrdcmoDriver - TrialDriver subclass for CRDCMO.
% Implements dual-population SPEA2 coevolution with IGP-based change
% response. Maintains two populations:
%   * pop1 (size N): constraint-aware SPEA2 selection
%   * pop2 (size <= N/2): unconstrained archive
% Each generation produces offspring from both populations and applies
% SPEA2 environmental selection. Change response uses tdcResponse which
% toggles between constraint-only and objective-change strategies.

    properties (Access = private)
        pop1            % Constrained population [1×N Solution array]
        pop2            % Unconstrained archive [1×(N/2) Solution array]
        fitness1        % SPEA2 fitness for pop1 (constraint-aware)
        fitness2        % SPEA2 fitness for pop2 (unconstrained)
        flag            % Boolean: true after constraint-only change
        prevPop1        % Previous env's pop1 for centroid shift in tdcResponse
        operatorParams  % SBX/PM operator parameters struct
    end

    methods
        function obj = CrdcmoDriver(config, problemFactory)
            obj@TrialDriver(config, problemFactory);
        end
    end

    methods (Access = protected)
        function initialize(this)
            this.pop1 = this.initialPop;
            this.pop2 = this.initialPop;
            this.fitness1 = calFitness(this.pop1.objs(), this.pop1.cons());
            this.fitness2 = calFitness(this.pop2.objs());
            this.flag = false;
            this.prevPop1 = Solution.empty();
            % CRDCMO operator params (Tian et al. 2021)
            this.operatorParams = struct('proC',1,'disC',20,'proM',1,'disM',20);
        end

        function evolveStep(this)
            N = this.config.algo.popSize;
            Nhalf = N / 2;
            op = this.operatorParams;
            domain = this.problem.getDomain();

            %% --- Offspring 1: tournament on pop1 SPEA2 fitness, GA op ---
            matingPool1 = tournamentSelection(2, 2 * Nhalf, this.fitness1);
            parentDecs1 = this.pop1(matingPool1).decs();
            offspringDecs1 = sbxPm(parentDecs1, domain, op, 'full');
            [offspring1, this.state] = decsToEvaluatedPop(offspringDecs1, this.problem, this.state);

            %% --- Offspring 2: switch on flag ---
            if this.flag
                mating2 = matingPoolCR(this.pop1, this.pop2, Nhalf);
                parentDecs2 = mating2.decs();
                offspringDecs2 = sbxPm(parentDecs2, domain, op, 'full');
                [offspring2, this.state] = decsToEvaluatedPop(offspringDecs2, this.problem, this.state);
                this.pop2 = updateArchive([this.pop2, this.pop1, offspring1, offspring2], Nhalf);
            else
                matingPool2 = tournamentSelection(2, Nhalf, this.fitness2);
                parentDecs2 = this.pop2(matingPool2).decs();
                offspringDecs2 = sbxPm(parentDecs2, domain, op, 'full');
                [offspring2, this.state] = decsToEvaluatedPop(offspringDecs2, this.problem, this.state);
                [this.pop2, this.fitness2] = spea2Selection([this.pop2, offspring1, offspring2], Nhalf, true);
            end

            %% --- pop1 environmental selection (with constraints) ---
            [this.pop1, this.fitness1] = spea2Selection([this.pop1, offspring1, offspring2], N, false);
        end

        function respondToChange(this)
            preTdcPop1 = this.pop1;  % stash BEFORE tdcResponse modifies pop1
            [this.pop1, this.pop2, this.flag, this.state] = ...
                tdcResponse(this.config, this.state, this.problem, ...
                            this.pop1, this.pop2, this.prevPop1);
            this.prevPop1 = preTdcPop1;

            % Recompute fitness after change response
            this.fitness1 = calFitness(this.pop1.objs(), this.pop1.cons());
            if ~isempty(this.pop2)
                this.fitness2 = calFitness(this.pop2.objs());
            else
                this.fitness2 = [];
            end
        end

        function pop = currentPop(this)
            pop = this.pop1;
        end
    end
end
