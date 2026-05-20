function [pop, popLCM, popDCM, typeFlag] = dlcmObj(kneeArray1, kneeArray2, popLCM, popDCM, typeFlag)
% dlcmObj - Direction Learning and Cosine Mapping (objective space).
%   Simplified 2D version of DLCM operating in objective space. Computes
%   direction ratios, blends with centroid direction, and reconstructs
%   predicted objectives via trigonometric mapping.
%
% Inputs:
%   kneeArray1 - [M x N] objective values at time K-1
%   kneeArray2 - [M x N] objective values at time K-2
%   popLCM     - accumulated LCM population (replaced)
%   popDCM     - accumulated DCM population (replaced)
%   typeFlag   - operator type flag
%
% Outputs:
%   pop        - [N x M] predicted objective values
%   popLCM     - LCM sub-population
%   popDCM     - DCM sub-population
%   typeFlag   - updated type flag

    %% Sort both arrays by first objective for alignment
    [~, sortIdx1] = sort(kneeArray1(1, :));
    kneeArray1 = kneeArray1(:, sortIdx1);
    [~, sortIdx2] = sort(kneeArray2(1, :));
    kneeArray2 = kneeArray2(:, sortIdx2);

    numIndividuals = size(kneeArray1, 2);
    directionVec = kneeArray1 - kneeArray2;

    %% Compute group centroid shift
    centroidPrev     = mean(kneeArray1', 1);
    centroidPrevPrev = mean(kneeArray2', 1);
    centroidDelta    = centroidPrev' - centroidPrevPrev';

    %% Compute individual scaling factors
    scalingFactors = zeros(1, numIndividuals);
    for ok = 1:numIndividuals
        scalingFactors(ok) = norm(kneeArray1(:, ok) - kneeArray2(:, ok)) ./ norm(centroidDelta);
    end
    meanScaling = mean(scalingFactors) / size(scalingFactors, 2);
    scalingFactors = scalingFactors + normrnd(0, meanScaling);
    scaledDirection = abs(scalingFactors)' .* repmat(centroidDelta', numIndividuals, 1);

    %% Compute 2D direction ratios
    polarAngles = zeros(1, numIndividuals);
    for j = 1:numIndividuals
        polarAngles(1, j) = directionVec(1, j) / (directionVec(2, j) + 0.00001);
    end
    centroidAngle = centroidDelta(1) / (centroidDelta(2) + 0.0001);

    %% Reconstruct predictions with blended angles
    reconstructedPop = zeros(2, numIndividuals);
    for num = 1:numIndividuals
        blendedAngle = 0.5 * (centroidAngle' + polarAngles(:, num));
        reconstructedPop(1, num) = norm(scaledDirection(num, :)) * cos(blendedAngle);
        reconstructedPop(2, num) = norm(scaledDirection(num, :)) * sin(blendedAngle);
    end

    %% Apply DCM prediction
    pop = mod(kneeArray1 + reconstructedPop, 1)';

    %% Split into CP (centroid-predicted) and DCM sub-populations
    crossoverProb = 0.5;
    cpIndices  = find(rand(1, size(pop, 1)) < crossoverProb);
    dcmIndices = setdiff(1:size(pop, 1), cpIndices);
    pop(cpIndices, :) = kneeArray1(:, cpIndices)' + scaledDirection(cpIndices, :);

    popLCM = pop(cpIndices, :);
    popDCM = pop(dcmIndices, :);
end
