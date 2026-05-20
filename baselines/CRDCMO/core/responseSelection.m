function archive = responseSelection(population, N)
% responseSelection - Truncate to N solutions on the first non-dominated front.
% Removes objective duplicates,
% extracts the first front under (constraint-free) NDSort, then re-runs an
% NDSort on the negated objectives and keeps that front-1 subset, finally
% truncating to size N via distance-based crowding removal.
%
% Inputs:
%   population - Solution object array
%   N          - target output size
% Outputs:
%   archive - Solution object array (size <= N)

    if isempty(population)
        archive = Solution.empty();
        return;
    end

    [~, b] = unique(population.objs(), 'rows');
    population = population(b);

    [frontNo, ~] = ndSort(population.objs(), N);
    front1 = population(frontNo == 1);
    if isempty(front1)
        archive = Solution.empty();
        return;
    end

    [front, ~] = ndSort(-front1.objs(), 1);
    archive = front1(front == 1);

    if length(archive) > N
        del = truncate(archive.objs(), length(archive) - N);
        archive(del) = [];
    end
end

function del = truncate(popObj, K)
% truncate - Distance-based truncation, removing K crowded solutions.
    distance = pdist2(popObj, popObj);
    distance(logical(eye(size(distance, 1)))) = inf;
    del = false(1, size(popObj, 1));
    while sum(del) < K
        remain = find(~del);
        temp = sort(distance(remain, remain), 2);
        [~, rank] = sortrows(temp);
        del(remain(rank(1))) = true;
    end
end
