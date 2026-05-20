function [population, indexPop] = diveHisSelection(population, historicalPopulation, state, similarityThreshold, N)
% diveHisSelection - Diversity-based historical selection.
%   Splits the current population into similar (to historical) and novel
%   individuals. Similar individuals are sorted by NSGA-II criteria; novel
%   individuals are selected by proximity to the historical non-dominated front.
%
% Inputs:
%   population             - current combined population (Solution array)
%   historicalPopulation   - matched historical population (Solution array)
%   state                  - 1 if environment was previously similar, 0 otherwise
%   similarityThreshold    - distance threshold for similarity detection
%   N                      - target population size
%
% Outputs:
%   population - selected population of size N
%   indexPop   - indices of selected individuals

    historicalObjs = historicalPopulation.objs();
    distToHist = min(pdist2(population.objs(), historicalObjs), [], 2);

    %% Partition into similar and novel individuals
    if state == 1
        similarIdx = find(distToHist <= similarityThreshold);
    else
        similarIdx = [];
    end
    novelIdx = setdiff(1:length(population), similarIdx);

    %% Sort similar individuals by NSGA-II criteria (no constraints, early stop)
    [~, selectedHistIdx] = sortSolutions(population(similarIdx), 3, N, length(novelIdx));

    %% Select novel individuals by proximity to historical non-dominated front
    if ~isempty(novelIdx)
        selectedNovelIdx = [];
        sortColIdx = 1;
        [frontNo, ~] = ndSort(historicalObjs, 1);
        crowdDis = crowdingDistance(historicalObjs, frontNo);

        frontMembers = find(frontNo == 1);
        [~, sortedCrowdIdx] = sort(crowdDis(frontMembers), 'descend');
        ndIndices = frontMembers(sortedCrowdIdx);

        ndHistObjs = historicalObjs(ndIndices, :);
        [~, sortedDistIdx] = sort(pdist2(ndHistObjs, population.objs()), 2);
        while length(selectedNovelIdx) < N
            selectedNovelIdx = [selectedNovelIdx, sortedDistIdx(:, sortColIdx)'];
            selectedNovelIdx = unique(selectedNovelIdx, 'stable');
            sortColIdx = sortColIdx + 1;
        end
        novelPop = population(selectedNovelIdx(1:N));
        population = [population(similarIdx(selectedHistIdx)), novelPop];
        indexPop = [similarIdx(selectedHistIdx); selectedNovelIdx(1:N)'];
        indexPop = indexPop(1:N);
    end
end
