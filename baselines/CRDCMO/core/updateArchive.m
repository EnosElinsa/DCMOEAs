function archive = updateArchive(allPop, N)
% updateArchive - Archive update preferring feasible solutions, with a final
% truncation step to enforce size N.
% If the union population contains any
% feasible solution, the archive is built from the first non-dominated front
% of [objectives, CV] and then restricted to its infeasible-but-non-dominated
% extreme tier; otherwise the archive is empty.
%
% Inputs:
%   allPop - Solution object array (any size)
%   N      - target archive size
% Outputs:
%   archive - Solution object array (size <= N, possibly empty)

    if isempty(allPop)
        archive = Solution.empty();
        return;
    end

    cv = sum(max(0, allPop.cons()), 2);
    if ~any(cv == 0)
        archive = Solution.empty();
        return;
    end

    %% Front-1 of [obj, CV] joint sort (feasibility-aware NDSort)
    objsAndCV = [allPop.objs(), cv];
    [frontNo, ~] = ndSort(objsAndCV, inf);
    front1 = allPop(frontNo == 1);

    %% Restrict to infeasible-yet-on-front
    cvFront = sum(max(0, front1.cons()), 2);
    infeasibleMask = cvFront ~= 0;
    infeasiblePop = front1(infeasibleMask);
    if isempty(infeasiblePop)
        archive = Solution.empty();
        return;
    end

    %% Among the kept infeasible solutions, take the front-1 of -objs
    [front, ~] = ndSort(-infeasiblePop.objs(), 1);
    archive = infeasiblePop(front == 1);

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
