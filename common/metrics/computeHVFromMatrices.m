function hv = computeHVFromMatrices(popObjs, popCVs, refPoint)
% computeHVFromMatrices - Compute hypervolume from raw objective/CV matrices.
%
% Used for post-hoc HV recomputation when populations are stored as plain
% matrices (popObjs, popCVs) rather than Solution object arrays.
%
% Inputs:
%   popObjs  - [N x M] objective values matrix
%   popCVs   - [N x 1] constraint violation vector
%   refPoint - [M x 1] reference point for HV computation
%
% Outputs:
%   hv - hypervolume value (-1 if no feasible solutions)

    if isempty(popObjs) || isempty(popCVs)
        hv = -1;
        return;
    end

    % Filter feasible solutions
    feasibleMask = (popCVs == 0);

    if ~any(feasibleMask)
        hv = -1;
        return;
    end

    popObj = popObjs(feasibleMask, :);  % [nFeasible x M]

    % Non-dominated sorting to find first front
    [frontNo, ~] = ndSort(popObj, [], size(popObj, 1));
    frontOneMask = (frontNo == 1);
    val = popObj(frontOneMask, :)';  % [M x nFront1] column-per-individual for Hypervolume MEX

    % Compute hypervolume
    hv = Hypervolume(val, refPoint);
end
