function [pop, popLCM, popDCM, typeFlag] = cglpPreObj(hisPareto, popSize, typeFlag)
% cglpPreObj - Correlation-Guided Learning Prediction (objective space).
%   Divides population into high/mid/low correlation groups via gray
%   relational analysis in objective space, then applies group-specific
%   prediction operators: centroid shift (high), DLCM (mid), or archive
%   replacement (low).
%
% Inputs:
%   hisPareto  - cell array of historical Pareto-optimal Solution objects
%   popSize    - population size
%   typeFlag   - operator type flag
%
% Outputs:
%   pop        - [popSize x M] predicted objective values
%   popLCM     - LCM sub-population from DLCM operator
%   popDCM     - DCM sub-population from DLCM operator
%   typeFlag   - updated type flag

    numGroups = 3;
    topGroupFraction = 6;
    timeIdx = length(hisPareto) + 1;

    %% Build historical population structs
    hisPop{timeIdx - 1}.X = hisPareto{timeIdx - 1}.decs()';
    hisPop{timeIdx - 1}.F = hisPareto{timeIdx - 1}.objs()';
    hisPop{timeIdx - 2}.X = hisPareto{timeIdx - 2}.decs()';
    hisPop{timeIdx - 2}.F = hisPareto{timeIdx - 2}.objs()';

    %% Match individuals across time steps by nearest objective distance
    distanceMatrix = pdist2(hisPop{timeIdx - 1}.F', hisPop{timeIdx - 2}.F');
    nearestIdxMap = zeros(1, popSize);
    for ii = 1:popSize
        [~, nearestIdxMap(ii)] = min(distanceMatrix(ii, :));
    end
    hisPop{timeIdx - 2}.X = hisPop{timeIdx - 2}.X(:, nearestIdxMap);
    hisPop{timeIdx - 2}.F = hisPop{timeIdx - 2}.F(:, nearestIdxMap);

    %% Gray relational analysis in objective space
    indivPrev     = hisPop{timeIdx - 1}.F;
    indivPrevPrev = hisPop{timeIdx - 2}.F;
    indivDelta    = indivPrev - indivPrevPrev;

    centroidPrev     = mean(hisPop{timeIdx - 1}.F, 2)';
    centroidPrevPrev = mean(hisPop{timeIdx - 2}.F, 2)';
    centroidDelta    = centroidPrev' - centroidPrevPrev';

    indivDelta = [indivDelta; 1:popSize];
    deltaWithIndex = indivDelta;
    groupIndices = cell(numGroups, 1);

    normalizedData = [deltaWithIndex(1:size(indivPrev, 1), :), centroidDelta]';
    for i = 1:size(deltaWithIndex, 2) + 1
        normalizedData(i, :) = normalizedData(i, :) / (normalizedData(i, 1) + 0.0001);
    end

    numRows = size(normalizedData, 1);
    referenceSeq = normalizedData(numRows, :);
    compareSeq   = normalizedData(1:numRows - 1, :);
    numCompare   = size(compareSeq, 1);

    grayRelation = zeros(1, numCompare);
    rho = 0.5;
    for i = 1:size(referenceSeq, 1)
        diffMatrix = zeros(numCompare, size(referenceSeq, 2));
        for j = 1:numCompare
            diffMatrix(j, :) = compareSeq(j, :) - referenceSeq(i, :);
        end
        minDiff = min(abs(diffMatrix), [], 'all');
        maxDiff = max(abs(diffMatrix), [], 'all');
        grayCoefficients = (minDiff + rho * maxDiff) ./ (abs(diffMatrix) + rho * maxDiff);
        grayRelation(i, :) = sum(grayCoefficients, 2)' / size(grayCoefficients, 2);
    end
    [~, sortedRelationIdx] = sort(grayRelation, 'descend');

    %% Divide into three correlation groups
    highCutoff = topGroupFraction / 10 * popSize;
    midCutoff  = 9 / 10 * popSize;
    groupIndices{1} = deltaWithIndex(end, sortedRelationIdx(1:highCutoff));
    groupIndices{2} = deltaWithIndex(end, sortedRelationIdx(highCutoff + 1:midCutoff));
    groupIndices{3} = deltaWithIndex(end, sortedRelationIdx(midCutoff + 1:end));

    predictedSolution = zeros(popSize, size(indivPrevPrev, 1));

    %% High correlation group: centroid shift prediction
    highGroupIdx = groupIndices{1};
    groupCentroidPrev     = mean(hisPop{timeIdx - 1}.F(:, highGroupIdx), 2)';
    groupCentroidPrevPrev = mean(hisPop{timeIdx - 2}.F(:, highGroupIdx), 2)';
    groupCentroidDelta    = groupCentroidPrev' - groupCentroidPrevPrev';

    meanShift = repmat(groupCentroidDelta', size(highGroupIdx, 2), 1);
    predictedSolution(highGroupIdx, :) = hisPop{timeIdx - 1}.F(:, highGroupIdx)' + meanShift;

    %% Mid correlation group: DLCM prediction
    [predictedSolution(groupIndices{2}, :), popLCM, popDCM, typeFlag] = ...
        dlcmObj(hisPop{timeIdx - 1}.F(:, groupIndices{2}), ...
                hisPop{timeIdx - 2}.F(:, groupIndices{2}), typeFlag);

    %% Low correlation group: archive replacement
    lowGroupIdx = groupIndices{end};
    if size(hisPareto{timeIdx - 1}, 2) > size(lowGroupIdx, 2)
        predictedSolution(lowGroupIdx, :) = hisPareto{timeIdx - 1}(1:size(lowGroupIdx, 2)).objs();
    else
        predictedSolution(lowGroupIdx(1:size(hisPareto{timeIdx - 1}, 2)), :) = hisPareto{timeIdx - 1}.objs();
    end

    pop = predictedSolution(1:popSize, :);
