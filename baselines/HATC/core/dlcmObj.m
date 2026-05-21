function [pop, popLCM, popDCM, typeFlag] = dlcmObj(kneeArray1, kneeArray2, typeFlag)
% dlcmObj - Direction Learning and Cosine Mapping (objective space).
%   Generalized M-dimensional version of DLCM operating in objective space.
%   Converts direction vectors to hyperspherical coordinates, blends with
%   centroid direction, and reconstructs predicted objectives.
%
% Inputs:
%   kneeArray1 - [M x N] objective values at time K-1
%   kneeArray2 - [M x N] objective values at time K-2
%   typeFlag   - operator type flag
%
% Outputs:
%   pop        - [N x M] predicted objective values
%   popLCM     - LCM sub-population
%   popDCM     - DCM sub-population
%   typeFlag   - updated type flag

    epsilon = 1e-7;

    %% Sort both arrays by first objective for alignment
    [~, sortIdx1] = sort(kneeArray1(1, :));
    kneeArray1 = kneeArray1(:, sortIdx1);
    [~, sortIdx2] = sort(kneeArray2(1, :));
    kneeArray2 = kneeArray2(:, sortIdx2);

    numDims = size(kneeArray1, 1);
    numIndividuals = size(kneeArray1, 2);
    directionVec = kneeArray1 - kneeArray2 + epsilon;

    %% Compute group centroid shift
    centroidPrev     = mean(kneeArray1, 2)';
    centroidPrevPrev = mean(kneeArray2, 2)';
    centroidDelta    = centroidPrev' - centroidPrevPrev' + epsilon;

    %% Compute individual scaling factors
    scalingFactors = zeros(1, numIndividuals);
    for ok = 1:numIndividuals
        scalingFactors(ok) = norm(kneeArray1(:, ok) - kneeArray2(:, ok)) ./ norm(centroidDelta);
    end
    meanScaling = mean(scalingFactors) / size(scalingFactors, 2);
    scalingFactors = scalingFactors + normrnd(0, meanScaling);
    scaledDirection = abs(scalingFactors)' .* repmat(centroidDelta', numIndividuals, 1);

    %% Convert individual direction vectors to hyperspherical angles
    polarAngles = zeros(numDims - 1, numIndividuals);
    for j = 1:numIndividuals
        for i = 1:numDims - 2
            tailNorm = sqrt(sum(directionVec(i + 1:end, j).^2));
            polarAngles(i, j) = atan(tailNorm / (directionVec(i, j)));
        end
    end
    lastAngleIdx = size(polarAngles, 1);
    for j = 1:numIndividuals
        polarAngles(lastAngleIdx, j) = atan(directionVec(lastAngleIdx + 1, j) / (directionVec(lastAngleIdx, j)));
    end

    %% Convert centroid direction to hyperspherical angles
    centroidAngles = zeros(1, numDims - 1);
    for i = 1:numDims - 2
        tailNorm = sqrt(sum(centroidDelta(i + 1:end).^2));
        centroidAngles(i) = atan(tailNorm / (centroidDelta(i)));
        if centroidAngles(i) < 0
            centroidAngles(i) = centroidAngles(i) + pi;
        end
    end
    lastIdx = length(centroidAngles);
    centroidAngles(lastIdx) = atan(centroidDelta(lastIdx + 1) / (centroidDelta(lastIdx)));

    %% Reconstruct individual Cartesian vectors from hyperspherical coordinates
    %% (centroid reconstruction omitted: unlike dlcm.m, this objective-space
    %% variant does not use centroidError for sign-consistency adjustment.)
    directionVecT = directionVec';
    reconstructedPop = zeros(numDims, numIndividuals);
    cartesian = zeros(1, numDims);

    for num = 1:numIndividuals
        angles = polarAngles(:, num);
        vecMagnitude = norm(directionVecT(num, :));
        for i = 1:numDims
            if i == 1
                cartesian(i) = vecMagnitude * cos(angles(i));
            elseif i < numDims
                sinProduct = 1;
                for j = 1:i - 1
                    sinProduct = sinProduct * sin(angles(j));
                end
                cartesian(i) = vecMagnitude * sinProduct * cos(angles(i));
            else
                sinProduct = 1;
                for j = 1:i - 1
                    sinProduct = sinProduct * sin(angles(j));
                end
                cartesian(i) = vecMagnitude * sinProduct;
            end
        end
        reconstructedPop(:, num) = cartesian;
    end

    %% Adjust angles for sign consistency
    reconstructionError = sum(kneeArray2 + reconstructedPop - kneeArray1, 1);
    for k = 1:size(reconstructionError, 2)
        if abs(reconstructionError(k)) > 1
            if polarAngles(end, k) > 0
                polarAngles(end, k) = polarAngles(end, k) - pi;
            else
                polarAngles(end, k) = polarAngles(end, k) + pi;
            end
        end
    end

    %% Final prediction: blend individual and centroid angles
    reconstructedPop = zeros(numDims, numIndividuals);
    cartesian = zeros(1, numDims);

    for num = 1:numIndividuals
        blendedAngles = 0.5 * (centroidAngles' + polarAngles(:, num));
        for i = 1:numDims
            if i == 1
                cartesian(i) = norm(scaledDirection(num, :)) * cos(blendedAngles(i));
            elseif i < numDims
                sinProduct = 1;
                for j = 1:i - 1
                    sinProduct = sinProduct * sin(blendedAngles(j));
                end
                cartesian(i) = norm(scaledDirection(num, :)) * sinProduct * cos(blendedAngles(i));
            else
                sinProduct = 1;
                for j = 1:i - 1
                    sinProduct = sinProduct * sin(blendedAngles(j));
                end
                cartesian(i) = norm(scaledDirection(num, :)) * sinProduct;
            end
        end
        reconstructedPop(:, num) = cartesian;
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
