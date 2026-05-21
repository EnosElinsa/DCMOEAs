function [pop, popLCM, popDCM, typeFlag] = dlcm(kneeArray1, kneeArray2, popLCM, popDCM, typeFlag)
% dlcm - Direction Learning and Cosine Mapping (decision space).
% Converts Cartesian direction vectors to hyperspherical coordinates,
% adjusts angles for sign consistency, then maps predicted directions
% back to Cartesian space. Splits output into LCM (centroid-predicted)
% and DCM (cosine-mapped) sub-populations.
% Inputs:
%   kneeArray1 - [D x N] decision variables at time K-1
%   kneeArray2 - [D x N] decision variables at time K-2
%   popLCM     - accumulated LCM population (appended to)
%   popDCM     - accumulated DCM population (appended to)
%   typeFlag   - operator type flag
% Outputs:
%   pop        - [N x D] predicted population
%   popLCM     - updated LCM population
%   popDCM     - updated DCM population
%   typeFlag   - updated type flag

    epsilon = 1e-7;
    directionVec = kneeArray1 - kneeArray2 + epsilon;
    numDims = size(directionVec, 1);
    numIndividuals = size(kneeArray1, 2);

    %% Compute group centroid shift
    centroidPrev = mean(kneeArray1, 2)';
    centroidPrevPrev = mean(kneeArray2, 2)';
    centroidDelta = centroidPrev' - centroidPrevPrev' + epsilon;

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

    %% Reconstruct Cartesian vectors from hyperspherical coordinates
    directionVecT = directionVec';
    reconstructedPop = zeros(numDims, numIndividuals);
    cartesian = zeros(1, numDims);
    centroidCartesian = zeros(1, numDims);

    for num = 1:numIndividuals + 1
        if num <= numIndividuals
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
        else
            angles = centroidAngles';
            vecMagnitude = norm(centroidDelta);
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
            centroidCartesian = cartesian;
        end
    end

    %% Adjust angles for sign consistency
    reconstructionError = sum(kneeArray2 + reconstructedPop - kneeArray1, 1);
    centroidError = sum(centroidPrevPrev + centroidCartesian - centroidPrev);
    for k = 1:size(reconstructionError, 2)
        if abs(reconstructionError(k)) > 1
            if polarAngles(end, k) > 0
                polarAngles(end, k) = polarAngles(end, k) - pi;
            else
                polarAngles(end, k) = polarAngles(end, k) + pi;
            end
        end
    end

    if abs(centroidError) > 1
        if centroidAngles(end) > 0
            centroidAngles(end) = centroidAngles(end) - pi;
        else
            centroidAngles(end) = centroidAngles(end) + pi;
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

    %% Apply DCM (cosine mapping) prediction
    pop = mod(abs(kneeArray1 + reconstructedPop), 1)';

    %% Split into CP (centroid-predicted LCM) and DCM sub-populations
    crossoverProb = 0.5;
    cpIndices = find(rand(1, size(pop, 1)) < crossoverProb);
    dcmIndices = setdiff(1:size(pop, 1), cpIndices);
    pop(cpIndices, :) = kneeArray1(:, cpIndices)' + scaledDirection(cpIndices, :);

    popLCM = [popLCM; pop(cpIndices, :)];
    popDCM = [popDCM; pop(dcmIndices, :)];
end
