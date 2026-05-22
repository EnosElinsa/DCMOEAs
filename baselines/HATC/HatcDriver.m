classdef HatcDriver < TrialDriver
% HatcDriver - TrialDriver subclass for HATC.
%
% Implements the History-Assisted Two-population Cooperative (HATC)
% algorithm. HATC uses a memory archive of past populations and CGLP
% prediction for change response, with dual-population evolution after
% the first environment.
%
% Key behaviors:
%   - Environment 1 (gen < maxGenPerEnv): single-pop NSGA-II evolution
%   - Environment 2+ (gen >= maxGenPerEnv): dual-pop with diveHisSelection
%   - Change response: stash pop into memoryArchive, then CGLP prediction
%     or random+SBX fallback for population regeneration
%   - beforeChangeCheck stashes pop into memoryArchive before each boundary
%   - progressEveryGen = 50 for generation progress printing

    properties (Access = private)
        pop             % Current population [1×N Solution array]
        uPop            % Unconstrained population [1×N Solution array]
        pop1            % Sub-population 1 [1×(N/2) Solution array]
        pop2            % Sub-population 2 [1×(N/2) Solution array]
        memoryArchive   % Cell array of past populations
        prepop          % Cell array of CGLP-predicted decision variables
        preobj          % Cell array of CGLP-predicted objectives
        matchedHistPop  % Matched historical population for diveHisSelection
        operatorParams  % SBX/PM operator parameters struct
    end

    methods
        function obj = HatcDriver(config, problemFactory)
            obj@TrialDriver(config, problemFactory);
            obj.progressEveryGen = 50;
        end
    end

    methods (Access = protected)
        function beforeChangeCheck(this)
        % beforeChangeCheck - Stash current pop into memory archive.
        %   Called by the sealed TrialDriver.run() at each environment
        %   boundary, immediately before controller.stepEnvironment.
            this.memoryArchive{end+1} = this.pop;
        end

        function initialize(this)
            this.pop = this.initialPop;
            this.uPop = this.initialPop;

            this.operatorParams = struct('proC',1,'disC',20,'proM',1,'disM',20);

            this.memoryArchive = {};
            this.prepop = {};
            this.preobj = {};
            this.pop1 = [];
            this.pop2 = [];
            this.matchedHistPop = [];
        end

        function evolveStep(this)
        % evolveStep - One generation of HATC evolution.
        %   Two branches based on whether we are in the first environment
        %   (gen < maxGenPerEnv) or subsequent environments
        %   (gen >= maxGenPerEnv).

            popSize = this.config.algo.popSize;
            op = this.operatorParams;
            domain = this.problem.getDomain();   % [D×2]

            if this.state.gen < this.config.algo.maxGenPerEnv
                % --- Branch 1: Single-pop evolution (Environment 1) ---
                [~, frontNo, crowdDis] = nsgaiiSelection(this.pop, popSize);
                matingPool = tournamentSelection(2, popSize*2, frontNo, -crowdDis);
                parents = this.pop(matingPool).decs();
                offDec = sbxPm(parents, domain, op, 'firstHalf');
                [offspring, this.state] = decsToEvaluatedPop(offDec, this.problem, this.state);
                [this.pop, ~, ~] = nsgaiiSelection([this.pop, offspring], popSize);
                [this.uPop, ~, ~] = nsgaiiSelection([this.uPop, offspring], popSize, true);
            else
                % --- Branch 2: Dual-pop evolution (Environment 2+) ---
                halfSize = popSize / 2;

                % Sub-population 1: unconstrained selection + SBX
                [~, frontNo1, crowdDis1] = nsgaiiSelection(this.pop1, halfSize, true);
                matingPool1 = tournamentSelection(2, popSize, frontNo1, -crowdDis1);
                parents1 = this.pop1(matingPool1).decs();
                offDec1 = sbxPm(parents1, domain, op, 'firstHalf');
                [offspring1, this.state] = decsToEvaluatedPop(offDec1, this.problem, this.state);

                % Sub-population 2: constrained selection, parents from pop1
                [~, frontNo2, crowdDis2] = nsgaiiSelection(this.pop2, halfSize);
                matingPool2 = tournamentSelection(2, popSize, frontNo2, -crowdDis2);
                parents2 = this.pop1(matingPool2).decs();
                offDec2 = sbxPm(parents2, domain, op, 'firstHalf');
                [offspring2, this.state] = decsToEvaluatedPop(offDec2, this.problem, this.state);

                % Selection: pop1 uses diveHisSelection, pop2 uses NSGA-II
                this.pop1 = diveHisSelection([this.pop1, offspring1, offspring2], this.matchedHistPop, 0, 0.05, halfSize);
                this.pop2 = nsgaiiSelection([this.pop2, offspring1, offspring2], halfSize);

                % Main pop and unconstrained pop updated with both offspring
                [this.pop, ~, ~] = nsgaiiSelection([this.pop, offspring1, offspring2], popSize);
                [this.uPop, ~, ~] = nsgaiiSelection([this.uPop, offspring1, offspring2], popSize, true);
            end
        end

        function respondToChange(this)
        % respondToChange - React to an environment change.
        %   Called after memoryArchive stash and stepEnvironment (in run()).
        %   Performs CGLP prediction, memory retrieval, and population
        %   regeneration.

            popSize = this.config.algo.popSize;
            op = this.operatorParams;
            domain = this.problem.getDomain();   % [D×2]
            lowerRow = domain(:, 1)';            % [1×D]
            upperRow = domain(:, 2)';            % [1×D]

            % --- Change Detection & Memory Retrieval ---
            envIdx = length(this.memoryArchive) + 1;

            if envIdx >= 3
                % Predict using CGLP
                this.prepop{envIdx} = cglpPre(this.memoryArchive, popSize, 1, domain);
                this.preobj{envIdx} = cglpPreObj(this.memoryArchive, popSize, 1);
            end

            if envIdx == 3
                % Nearest match based on naive distance (simplified)
                this.matchedHistPop = this.memoryArchive{1};
            elseif envIdx > 3
                % Nearest match based on prediction distance
                predObjHistory = this.preobj;
                currentPredObj = this.preobj{end};
                predObjDistance = inf(1, envIdx);
                for predEnvIdx = 3:envIdx-1
                    predObjDistance(predEnvIdx) = sum(min(pdist2(predObjHistory{predEnvIdx}, currentPredObj), [], 2));
                end
                [~, nearestPredEnvIdx] = min(predObjDistance);
                this.matchedHistPop = this.memoryArchive{nearestPredEnvIdx};
            else
                this.matchedHistPop = this.memoryArchive{end};
            end

            % --- Generate new population responding to change ---
            if envIdx >= 3
                dec = this.prepop{envIdx};
            else
                randDec = unifrnd(repmat(lowerRow, round(0.2*popSize), 1), repmat(upperRow, round(0.2*popSize), 1));
                lastCP = this.memoryArchive{end}.decs();
                long = randperm(popSize);
                parents = lastCP(long(round(0.2*popSize)+1:end), :);
                offDec1 = sbxPm(parents, domain, op, 'full');
                dec = [randDec; offDec1];
            end

            if size(unique(dec, 'rows'), 1) < popSize
                addDec = unifrnd(repmat(lowerRow, popSize, 1), repmat(upperRow, popSize, 1));
                newDec = unique([dec; addDec], 'rows', 'stable');
                dec = newDec(1:popSize, :);
            end

            [this.pop, this.state] = decsToEvaluatedPop(dec, this.problem, this.state);
            this.uPop = this.pop;

            randN = randperm(popSize);
            this.pop1 = this.pop(randN(1:popSize/2));
            this.pop2 = this.pop(randN(popSize/2+1:end));
        end

        function pop = currentPop(this)
            pop = this.pop;
        end
    end
end
