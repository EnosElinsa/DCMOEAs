function [FT, DIT, NIT, AS] = classifyTribes(population1, population2, AS)
% classifyTribes - Classify merged population into FT/DIT/NIT tribes.
% Refactored from mEDCMOA/tribeClassification.m.
% FT = feasible tribe, DIT = dominated infeasible tribe,
% NIT = nondominated infeasible tribe (dominating some AS member).
% Inputs:
% population1 - Solution object array (first population)
% population2 - Solution object array (second, can be empty)
% AS - Solution object array (archive set, can be empty)
% Outputs:
% FT, DIT, NIT - Solution object arrays for each tribe
% AS - updated archive set

    population = [population1, population2];

    cvVec = [population.cv];  % [1 x N]
    feasibleMask = (cvVec == 0);
    infeasibleMask = ~feasibleMask;

    FT = population(feasibleMask);
    infeasibleTribe = population(infeasibleMask);

    %% Update nondominated archive set
    N = numel(population1);
    AS = updateNondominatedSet(FT, AS, N);

    nInf = numel(infeasibleTribe);
    flag = false(1, nInf);
    %% Classify infeasible solutions into DIT and NIT
    for i = 1:nInf
        if findDominatedSet(infeasibleTribe(i).obj, 0, AS) == 1
            flag(i) = true;
        end
    end
    DIT = infeasibleTribe(~flag);
    NIT = infeasibleTribe(flag);
end
