function crowdDis = crowdingDistance(popObj, frontNo)
% crowdingDistance - Calculate the crowding distances of solutions front by front.
% CD = crowdingDistance(F) calculates the crowding distances of solutions
% according to their objective values in F.
% CD = crowdingDistance(F, frontNo) calculates the crowding distances of
% solutions in each non-dominated front, where frontNo is the front
% numbers of solutions.
% Example:
% crowdDis = crowdingDistance(popObj, frontNo)

    [N,M] = size(popObj);
    if nargin < 2
        frontNo = ones(1,N);
    end
    crowdDis = zeros(1,N);
    fronts   = setdiff(unique(frontNo),inf);
    for f = 1 : length(fronts)
        front = find(frontNo==fronts(f));
        fmax  = max(popObj(front,:),[],1);
        fmin  = min(popObj(front,:),[],1);
        for i = 1 : M
            [~,rank] = sortrows(popObj(front,i));
            crowdDis(front(rank(1)))   = inf;
            crowdDis(front(rank(end))) = inf;
            for j = 2 : length(front)-1
                crowdDis(front(rank(j))) = crowdDis(front(rank(j)))+(popObj(front(rank(j+1)),i)-popObj(front(rank(j-1)),i))/(fmax(i)-fmin(i));
            end
        end
    end
end
