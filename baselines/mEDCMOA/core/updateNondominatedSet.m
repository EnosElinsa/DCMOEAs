function AS = updateNondominatedSet(population, population2, popsize)
% updateNondominatedSet - Archive maintenance for nondominated solutions.
% Merges two populations, removes duplicates, keeps front-1 up to popsize.
% Inputs:
% population - Solution object array (primary)
% population2 - Solution object array (secondary, can be empty)
% popsize - maximum archive size
% Outputs:
% AS - nondominated Solution object array

    if ~isempty(population2)
        population = [population, population2];
    end

    %% Remove duplicate individuals
    allDecs = population.decs();  % [N x D]
    [~, ia, ~] = unique(allDecs, 'rows', 'stable');
    population = population(ia);

    objs = population.objs();  % [N x M]
    cons = population.cons();  % [N x K]
    [frontNo, ~] = ndSort(objs, cons, numel(population));
    AS = population(frontNo == 1);

    if numel(AS) > popsize
        asObjs = AS.objs();  % [nAS x M]
        crowdDis = crowdingDistance(asObjs, ones(1, numel(AS)));
        [~, rank] = sort(crowdDis, 'descend');
        AS = AS(rank(1:popsize));
    end
end
