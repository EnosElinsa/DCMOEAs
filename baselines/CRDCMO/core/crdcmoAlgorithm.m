function [pop1, pop2, problem, noFeasibleFlag, state] = ...
    crdcmoAlgorithm(config, state, problem, pop1, pop2, controller)
% crdcmoAlgorithm - CRDCMO dual-population SPEA2 coevolution loop with
% IGP-based change response.
% Maintains two populations:
%   * pop1 (size N): constraint-aware SPEA2 selection
%   * pop2 (size <= N/2 after the first generation): unconstrained archive
% Each generation:
%   1) Generate N offspring from pop1 via tournament + SBX/PM (GA defaults).
%   2) Generate N/2 offspring for the archive from either pop2 (Flag=false,
%      tournament on unconstrained SPEA2 fitness) or matingPoolCR(pop1,pop2)
%      (Flag=true, cosine-similarity / CV-aware mating with the archive).
%   3) SPEA2-select pop1 (with constraints) and pop2 (without constraints)
%      from the merged offspring pool; when Flag=true, pop2 is rebuilt via
%      updateArchive() instead of SPEA2.
% Every ft generations the controller advances the environment and the TDC
% change response (tdcResponse) refreshes both populations and toggles Flag.
%
% Inputs:
%   config     - configuration struct (uses .algo.popSize, .domain,
%                .maxGenPerEnv = scalar gen-per-env for current problem)
%   state      - mutable runtime state
%   problem    - UAVHAP handle
%   pop1, pop2 - initial Solution arrays (typically equal copies of the
%                random initial population, size N each)
%   controller - TrialController handle
% Outputs:
%   pop1, pop2     - final Solution arrays
%   problem        - updated UAVHAP handle
%   noFeasibleFlag - true if a no-feasible termination was raised
%   state          - updated runtime state

    N = config.algo.popSize;
    Nhalf = N / 2;
    maxgen = config.maxGenPerEnv * problem.tMax;
    ft = config.maxGenPerEnv;
    domain = config.domain;

    noFeasibleFlag = false;
    flag = false;
    prevPop1 = Solution.empty();

    fitness1 = calFitness(pop1.objs(), pop1.cons());
    fitness2 = calFitness(pop2.objs());

    % CRDCMO operator params.
    op = struct('proC',1,'disC',20,'proM',1,'disM',20);

    while maxgen > state.gen
        %% --- Offspring 1: tournament on pop1 SPEA2 fitness, GA op ---
        matingPool1 = tournamentSelection(2, 2 * Nhalf, fitness1);
        parentDecs1 = pop1(matingPool1).decs();
        offspringDecs1 = generateGaOffspring(parentDecs1, domain, op);
        [offspring1, state] = decsToEvaluatedPop(offspringDecs1, problem, state);

        %% --- Offspring 2: switch on Flag ---
        if flag
            mating2 = matingPoolCR(pop1, pop2, Nhalf);
            parentDecs2 = mating2.decs();
            offspringDecs2 = generateGaOffspring(parentDecs2, domain, op);
            [offspring2, state] = decsToEvaluatedPop(offspringDecs2, problem, state);
            pop2 = updateArchive([pop2, pop1, offspring1, offspring2], Nhalf);
        else
            matingPool2 = tournamentSelection(2, Nhalf, fitness2);
            parentDecs2 = pop2(matingPool2).decs();
            offspringDecs2 = generateGaOffspring(parentDecs2, domain, op);
            [offspring2, state] = decsToEvaluatedPop(offspringDecs2, problem, state);
            [pop2, fitness2] = spea2Selection([pop2, offspring1, offspring2], Nhalf, true);
        end

        %% --- pop1 environmental selection (with constraints) ---
        [pop1, fitness1] = spea2Selection([pop1, offspring1, offspring2], N, false);

        state.gen = state.gen + 1;

        %% --- Change point: every ft gens advance env + run TDC response ---
        if mod(state.gen, ft) == 0
            [~, ~, isComplete] = controller.stepEnvironment(problem, pop1);
            if isComplete
                if controller.logger.noFeasibleFlag
                    noFeasibleFlag = true;
                end
                return;
            end

            preTdcPop1 = pop1;  % preserve env-t final pop1 for next centroid shift
            [pop1, pop2, flag, state] = tdcResponse(config, state, problem, pop1, pop2, prevPop1);
            prevPop1 = preTdcPop1;

            fitness1 = calFitness(pop1.objs(), pop1.cons());
            if ~isempty(pop2)
                fitness2 = calFitness(pop2.objs());
            else
                fitness2 = [];
            end
        end

        if mod(state.gen, 50) == 0
            fprintf('    Gen=%d\n', state.gen);
        end
    end
end

function offspringDecs = generateGaOffspring(parentDecs, domain, op)
% generateGaOffspring - SBX crossover + polynomial mutation using shared
% operatorParams (op.proC, op.disC, op.proM/D, op.disM). Returns one
% offspring per parent (M parents -> M offspring); odd-sized parent
% matrices drop the trailing parent (GA behaviour).
    [M, D] = size(parentDecs);
    half = floor(M / 2);
    [off1, off2] = sbxCrossover( ...
        parentDecs(1:half, :), parentDecs(half+1:2*half, :), op.proC, op.disC);
    offspringDecs = polynomialMutation([off1; off2], domain, op.proM/D, op.disM);
end


