function addset = selectElites(pop, fitness, required)
% selectElites - Select best solutions by fitness then crowding distance.
% Inputs:
% pop - Solution object array
% fitness - [1 x N] fitness values
% required - number of solutions to select
% Outputs:
% addset - selected Solution object array

    [sortval, sortindex] = sort(fitness);
    addset = Solution.empty();
    index = 0;
    while required > 0
        frontIndices = sortindex(sortval == index);
        if length(frontIndices) > required
            crowdDis = crowdingDistance(pop(frontIndices).objs(), zeros(1, length(frontIndices)));
            [~, sortindex2] = sort(crowdDis);
            frontIndices = frontIndices(sortindex2(end - required + 1:end));
        end
        required = required - length(frontIndices);
        addset = [addset, pop(frontIndices)];
        index = index + 1;
    end
end
