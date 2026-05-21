function [newPop1, newPop2, flag, state] = tdcResponse(config, state, problem, pop1, pop2, prevPop1)
% tdcResponse - CRDCMO change-response (TDC) strategy.
% Re-evaluates the current pop1 under the new
% environment and branches on the magnitude of the per-objective mean shift:
%   * Constraint-only change (mean shift <= 1e-6 in every component):
%       - Predict a new constraint-aware pop1 via per-dim IGP regression
%         (igpNewPop) using the re-evaluated pop1 as anchor.
%       - Re-evaluate the unconstrained archive (pop2) and merge
%         everything via updateArchive() to refresh the archive.
%       - SPEA2-select the constrained population from the feasible subset
%         plus the IGP predictions to fill (N - archiveSize).
%       - Sets Flag = true so the main loop switches to the
%         matingPoolCR/updateArchive branch on subsequent generations.
%   * Objective change (any component > 1e-6):
%       - SPEA2-tournament-select N/2 anchors from the re-evaluated pop1,
%         then IGP-predict their decisions (igpNewPop).
%       - Generate an unconstrained diversity-compensation set via
%         igpNewUPop using the centroid shift between prev and current pop1.
%       - SPEA2-select pop1 (with constraints) and pop2 (without constraints)
%         from the merged set of size 3*N/2.
%       - Sets Flag = false.
%
% Inputs:
%   config   - configuration struct (uses .domain)
%   state    - mutable runtime state
%   problem  - DynamicProblem instance
%   pop1     - current Solution array under the OLD environment (stale objs)
%   pop2     - current archive Solution array (may be empty after init quirks)
%   prevPop1 - Solution array of pop1 at the END of the PREVIOUS environment
%              (empty for the first transition; only its decs are used by
%              igpNewUPop to compute the centroid-shift vector)
% Outputs:
%   newPop1 - refreshed constrained Solution array
%   newPop2 - refreshed archive Solution array (may be empty if no feasible)
%   flag    - boolean Flag for branch selection
%   state   - updated runtime state

    N = numel(pop1);
    Nhalf = floor(N / 2);
    domain = config.domain;

    %% Re-evaluate pop1 decisions under the new environment
    [pop1Reev, state] = decsToEvaluatedPop(pop1.decs(), problem, state);

    %% Objective mean shift
    ctInterval = mean(pop1Reev.objs(), 1) - mean(pop1.objs(), 1);

    %% Feasible subset of re-evaluated pop1
    feasibleMask = pop1Reev.cvs() == 0;
    feasibleSubset = pop1Reev(feasibleMask);

    if all(ctInterval <= 1e-6)
        % --- Branch 1: constraint-only change ---
        igpDec = igpNewPop(pop1Reev, domain);
        [igpPop, state] = decsToEvaluatedPop(igpDec, problem, state);

        if ~isempty(pop2)
            [pop2Reev, state] = decsToEvaluatedPop(pop2.decs(), problem, state);
        else
            pop2Reev = Solution.empty();
        end

        newPop2 = updateArchive([feasibleSubset, igpPop, pop2Reev], Nhalf);

        targetSize = max(1, N - numel(newPop2));
        [newPop1, ~] = spea2Selection([feasibleSubset, igpPop], targetSize, false);
        flag = true;
    else
        % --- Branch 2: objective change ---
        fitness = calFitness(pop1Reev.objs(), pop1Reev.cons());
        matingIdx = tournamentSelection(2, Nhalf, fitness);
        igpDec = igpNewPop(pop1Reev(matingIdx), domain);
        [igpPop, state] = decsToEvaluatedPop(igpDec, problem, state);

        uOffDec = igpNewUPop(pop1Reev, prevPop1, domain, Nhalf);
        [uOffPop, state] = decsToEvaluatedPop(uOffDec, problem, state);

        merged = [feasibleSubset, igpPop, uOffPop];
        [newPop1, ~] = spea2Selection(merged, Nhalf, false);
        [newPop2, ~] = spea2Selection(merged, Nhalf, true);
        flag = false;
    end
end


