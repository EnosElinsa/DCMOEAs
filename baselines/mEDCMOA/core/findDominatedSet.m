function flag = findDominatedSet(obj, cv, AS)
% findDominatedSet - Check if individual dominates any member of archive set.
% Refactored from mEDCMOA/DominatedSet.m.
% Inputs:
% obj - objective vector of individual
% cv - constraint violation of individual
% AS - Solution object array (archive set)
% Outputs:
% flag - 1 if individual dominates at least one AS member, 0 otherwise

    flag = 0;
    for i = 1:numel(AS)
        if checkDominance(obj, cv, AS(i).obj, AS(i).cv) == 1
            flag = 1;
        end
    end
end
