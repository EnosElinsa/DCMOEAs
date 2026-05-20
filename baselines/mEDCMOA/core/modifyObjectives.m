function objs = modifyObjectives(pop)
% modifyObjectives - Compute modified objective values for mating selection.
% Refactored from mEDCMOA/ModifyObjects.m.
% Combines normalized objectives with constraint violation penalty.
% Inputs:
% pop - Solution object array
% Outputs:
% objs - [M x N] modified objective values (column-per-individual)

    cvVec = [pop.cv];              % [1 x N]
    N = numel(pop);
    oriObjs = pop.objs()';         % [M x N]

    rF = sum(cvVec == 0) / N;
    maxCons = max(cvVec);
    if maxCons == 0
        maxCons = 1e-5;
    end
    maxObj = max(oriObjs, [], 2);
    minObj = min(oriObjs, [], 2);
    v = sum(cvVec ./ maxCons, 1);
    fBa = (oriObjs - minObj) ./ (maxObj - minObj);
    objs = (fBa.^2 + v.^2).^0.5;
    Y = fBa;
    Y(:, v == 0) = 0;
    p = (1 - rF) .* v + rF .* Y;
    objs = objs + p;
end
