function [pop, popLCM, popDCM, typeFlag] = cglpPre(hisPareto, popSize, typeFlag, domain)
% cglpPre - Correlation-Guided Learning Prediction (decision space).
% Divides population into high/mid/low correlation groups via gray
% relational analysis, then applies group-specific prediction operators.
% Inputs:
%   hisPareto  - cell array of historical Pareto sets
%   popSize    - population size
%   typeFlag   - operator type flag (passed to dlcm)
%   domain     - [D×2] decision variable bounds (column 1 = lower,
%                column 2 = upper). See ADR-0004.
% Outputs:
%   pop       - [popSize x D] predicted decision variables
%   popLCM    - LCM-predicted sub-population (from dlcm)
%   popDCM    - DCM-predicted sub-population (from dlcm)
%   typeFlag  - updated type flag

    numGroups = 3;
    topGroupFraction = 0.6;  % fraction of population in high-correlation group
    timeIdx = length(hisPareto) + 1;

    %% Load historical populations from two most recent environments
    % memoryArchive contains arrays of Solution objects. Extract them here:
    hisPop{timeIdx - 1}.X = hisPareto{timeIdx - 1}.decs()';
    hisPop{timeIdx - 1}.F = hisPareto{timeIdx - 1}.objs()';
    hisPop{timeIdx - 2}.X = hisPareto{timeIdx - 2}.decs()';
    hisPop{timeIdx - 2}.F = hisPareto{timeIdx - 2}.objs()';
    numPoints = size(hisPop{timeIdx - 1}.X, 2);

    lowerRow = domain(:, 1)';   % [1×D]
    upperRow = domain(:, 2)';   % [1×D]
    lowerBound = repmat(lowerRow, numPoints, 1);
    upperBound = repmat(upperRow, numPoints, 1);
    upperBound = upperBound';
    lowerBound = lowerBound';
    randomFallback = lowerBound' + rand(size(upperBound')) .* (upperBound - lowerBound)';

    %% Match individuals across time steps by nearest objective distance
    distanceMatrix = pdist2(hisPop{timeIdx - 1}.F', hisPop{timeIdx - 2}.F');
    nearestIdxMap = zeros(1, popSize);
    for ii = 1:popSize
        [~, nearestIdxMap(ii)] = min(distanceMatrix(ii, :));
    end
    hisPop{timeIdx - 2}.X = hisPop{timeIdx - 2}.X(:, nearestIdxMap);
    hisPop{timeIdx - 2}.F = hisPop{timeIdx - 2}.F(:, nearestIdxMap);

    %% Gray relational analysis for correlation grouping
    indivPrev = hisPop{timeIdx - 1}.X;
    indivPrevPrev = hisPop{timeIdx - 2}.X;
    indivDelta = indivPrev - indivPrevPrev;
    centroidPrev = mean(hisPop{timeIdx - 1}.X, 2)';
    centroidPrevPrev = mean(hisPop{timeIdx - 2}.X, 2)';
    centroidDelta = centroidPrev' - centroidPrevPrev';

    deltaWithIndex = [indivDelta; 1:popSize];

    %% Compute gray relational coefficients
    normalizedData = [deltaWithIndex(1:size(indivPrev, 1), :), centroidDelta]';
    for i = 1:size(normalizedData, 1)
        normalizedData(i, :) = normalizedData(i, :) / (normalizedData(i, 1) + 0.0001);
    end

    numRows = size(normalizedData, 1);
    referenceSeq = normalizedData(numRows, :);
    compareSeq = normalizedData(1:numRows - 1, :);
    diffMatrix = zeros(size(compareSeq));

    for j = 1:size(compareSeq, 1)
        diffMatrix(j, :) = compareSeq(j, :) - referenceSeq;
    end
    minDiff = min(abs(diffMatrix), [], 'all');
    maxDiff = max(abs(diffMatrix), [], 'all');
    rho = 0.5;  % gray relational distinguishing coefficient
    grayCoefficients = (minDiff + rho * maxDiff) ./ (abs(diffMatrix) + rho * maxDiff);
    grayRelation = sum(grayCoefficients, 2)' / size(grayCoefficients, 2);

    [~, sortedRelationIdx] = sort(grayRelation, 'descend');

    %% Divide into three correlation groups
    groupIndices = cell(numGroups, 1);
    groupIndices{1} = deltaWithIndex(end, sortedRelationIdx(1:topGroupFraction / 10 * popSize));
    groupIndices{2} = deltaWithIndex(end, sortedRelationIdx(topGroupFraction / 10 * popSize + 1:9 / 10 * popSize));
    groupIndices{3} = deltaWithIndex(end, sortedRelationIdx(9 / 10 * popSize + 1:end));

    predictedSolution = zeros(popSize, size(lowerBound, 1));

    %% High correlation group: centroid-shift prediction
    highGroupIdx = 1;
    groupCentroidPrev = mean(hisPop{timeIdx - 1}.X(:, groupIndices{highGroupIdx}), 2)';
    groupCentroidPrevPrev = mean(hisPop{timeIdx - 2}.X(:, groupIndices{highGroupIdx}), 2)';
    groupCentroidDelta = groupCentroidPrev' - groupCentroidPrevPrev';

    meanShift = repmat(groupCentroidDelta', size(groupIndices{highGroupIdx}, 2), 1);
    predictedSolution(groupIndices{highGroupIdx}, :) = hisPop{timeIdx - 1}.X(:, groupIndices{highGroupIdx})' + meanShift;

    %% Mid correlation group: Direction Learning and Cosine Mapping (DLCM)
    popLCM = [];
    popDCM = [];
    [predictedSolution(groupIndices{2}, :), popLCM, popDCM, typeFlag] = ...
        dlcm(hisPop{timeIdx - 1}.X(:, groupIndices{2}), ...
             hisPop{timeIdx - 2}.X(:, groupIndices{2}), popLCM, popDCM, typeFlag);

    %% Low correlation group: historical Pareto front reuse
    if size(hisPareto{timeIdx - 1}, 2) > size(groupIndices{end}, 2)
        predictedSolution(groupIndices{end}, :) = hisPareto{timeIdx - 1}(1:size(groupIndices{end}, 2)).decs();
    else
        predictedSolution(groupIndices{end}(1:size(hisPareto{timeIdx - 1}, 2)), :) = hisPareto{timeIdx - 1}.decs();
    end

    %% Clip to bounds
    pop = predictedSolution(1:popSize, :);
    outOfBounds = (pop < lowerBound') | (pop > upperBound');
    pop(outOfBounds) = randomFallback(outOfBounds);
end
