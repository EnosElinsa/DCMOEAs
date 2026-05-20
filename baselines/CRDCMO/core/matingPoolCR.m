function matingPool = matingPoolCR(population, archive, N)
% matingPoolCR - Cosine-similarity / CV-aware mating pool used when the
% Flag=true branch of CRDCMO is active (mature feasible archive).
%
% Two regimes:
%   - Sparse archive (numel(archive) < N): combine population+archive,
%     deduplicate by objective, and tournament-select on
%     (sum-of-objectives, decision-space density) to produce N parents.
%   - Mature archive (numel(archive) >= N): pair-wise stochastic mating
%     between population and archive, alternating a CV-based pick and an
%     angle-based pick (both keyed on cosine-distance ranks).
%
% Inputs:
%   population - Solution object array (typically pop1)
%   archive    - Solution object array (typically pop2)
%   N          - target mating-pool size
% Outputs:
%   matingPool - Solution object array (size N)

    if numel(archive) < N
        popAll = [population, archive];
        [~, b] = unique(popAll.objs(), 'rows');
        popAll = popAll(b);
        density = densityCal(popAll.decs());
        idx = tournamentSelection(2, N, sum(popAll.objs(), 2), density);
        matingPool = popAll(idx);
        return;
    end

    allPop = [population, archive];
    nPop = numel(population);
    nArc = numel(archive);

    objs = allPop.objs();
    zMin = min(objs, [], 1);
    zMax = max(objs, [], 1);
    denom = (zMax - zMin) + 1e-10;
    normalized = (objs - zMin) ./ denom + 1e-10;

    cosine = 1 - pdist2(normalized, normalized, 'cosine');
    cosine = cosine .* (1 - eye(size(normalized, 1)));

    temp = sort(-cosine, 2);
    [~, rank] = sortrows(temp);

    cv1 = sum(max(0, population.cons()), 2);
    cv2 = sum(max(0, archive.cons()), 2);

    angle1 = rank(1:nPop);
    angle2 = rank(nPop+1:end);

    idx1 = randi(nPop, 1, N);
    idx2 = randi(nArc, 1, N);

    matingPool = Solution.empty();
    i = 0;
    while length(matingPool) < N
        if cv1(idx1(i+1)) < cv2(idx2(i+1))
            matingPool = [matingPool, population(idx1(i+1))]; %#ok<AGROW>
        else
            matingPool = [matingPool, archive(idx2(i+1))]; %#ok<AGROW>
        end
        if length(matingPool) >= N, break; end
        if angle1(idx1(i+2)) < angle2(idx2(i+2))
            matingPool = [matingPool, population(idx1(i+2))]; %#ok<AGROW>
        else
            matingPool = [matingPool, archive(idx2(i+2))]; %#ok<AGROW>
        end
        i = i + 2;
    end
end

function density = densityCal(decs)
% densityCal - Inverse of the kth-nearest-neighbour distance in normalised
% decision space; smaller value indicates a more diverse individual (used as
% a tie-breaker that prefers diversity).
    [N, ~] = size(decs);
    if N <= 1
        density = zeros(N, 1);
        return;
    end
    zMin = min(decs, [], 1);
    zMax = max(decs, [], 1);
    denom = (zMax - zMin) + 1e-20;
    normalized = (decs - zMin) ./ denom;
    distance = pdist2(normalized, normalized);
    distance(logical(eye(size(distance, 1)))) = inf;
    distSort = sort(distance, 2);
    k = min(floor(sqrt(N)) + 1, N);
    density = 1 ./ (1 + distSort(:, k));
end
