function [newPopulation, allNumb] = sortSolutions(population, sortMode, np1, np2)
% sortSolutions - Sort population by NSGA-II ranking criteria.
% sortMode selects sorting variant:
% 0 = with constraints
% 1 = no constraints
% 2 = adaptive penalty
% 3 = no constraints, early stop at np1-np2
% 4 = with constraints, early stop at np1-np2

    populationCount = length(population);
    switch sortMode
        case 0
            [frontNo, maxFNo] = ndSort(population.objs(), population.cons(), populationCount);
            crowdDis = crowdingDistance(population.objs(), frontNo);
            allNumb = collectSortedIndices(frontNo, maxFNo, crowdDis, 0, 0);

        case 1
            [frontNo, maxFNo] = ndSort(population.objs(), populationCount);
            crowdDis = crowdingDistance(population.objs(), frontNo);
            allNumb = collectSortedIndices(frontNo, maxFNo, crowdDis, 0, 0);

        case 2
            penalizedObj = AdaptivePenaltyFunction(population);
            [frontNo, maxFNo] = ndSort(penalizedObj, populationCount);
            crowdDis = crowdingDistance(population.objs(), frontNo);
            allNumb = collectSortedIndices(frontNo, maxFNo, crowdDis, 0, 0);

        case 3
            [frontNo, maxFNo] = ndSort(population.objs(), populationCount);
            crowdDis = crowdingDistance(population.objs(), frontNo);
            allNumb = collectSortedIndices(frontNo, maxFNo, crowdDis, np1, np2);

        case 4
            [frontNo, maxFNo] = ndSort(population.objs(), population.cons(), populationCount);
            crowdDis = crowdingDistance(population.objs(), frontNo);
            allNumb = collectSortedIndices(frontNo, maxFNo, crowdDis, np1, np2);

        otherwise
            error('Unsupported sortMode: %d', sortMode);
    end

    newPopulation = population(allNumb);
end

function allNumb = collectSortedIndices(frontNo, maxFNo, crowdDis, np1, np2)
    allNumb = [];
    useEarlyStop = np1 > 0;

    for frontIdx = 1:maxFNo
        frontMembers = find(frontNo == frontIdx);
        frontCrowdDis = crowdDis(frontMembers);
        [~, sortedCrowdIdx] = sort(frontCrowdDis, 'descend');
        allNumb = [allNumb, frontMembers(sortedCrowdIdx)];

        if useEarlyStop && (length(allNumb) + np2 >= np1)
            break;
        end
    end
end
