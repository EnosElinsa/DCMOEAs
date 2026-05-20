function [frontNo, maxFNo] = ndSort(varargin)
% ndSort - Perform non-dominated sorting by using efficient non-dominated sort.
% frontNo = ndSort(F,s) performs non-dominated sorting on F, where F is
% the matrix of objective values of a set of solutions, and s is the
% number of solutions to be sorted at least. frontNo(i) denotes the front
% number of the i-th solution. The solutions have not been sorted are
% assigned a front number of inf.
% frontNo = ndSort(F,C,s) performs non-dominated sorting based on
% constrained domination, where C is the matrix of constraint violations
% of solutions. In this case, feasible solutions always dominate
% infeasible solutions, and one infeasible solution dominates another
% infeasible solution if the former has a smaller overall constraint
% violation than the latter.
% In particular, s = 1 indicates finding only the first non-dominated
% front, s = size(F,1)/2 indicates sorting only half the population
% (which is often used in algorithms), and s = inf indicates sorting the
% whole population.
% [frontNo,K] = ndSort(...) also returns the maximum front number besides inf.
% Example:
% [frontNo, maxFNo] = ndSort(popObj, 1)
% [frontNo, maxFNo] = ndSort(popObj, popCon, inf)

    popObj = varargin{1};
    [N,M]  = size(popObj);
    if nargin == 2
        nSort  = varargin{2};
    else
        popCon = varargin{2};
        nSort  = varargin{3};
        infeasible           = any(popCon>0,2);
        popObj(infeasible,:) = repmat(max(popObj,[],1),sum(infeasible),1) + repmat(sum(max(0,popCon(infeasible,:)),2),1,M);
    end
    if M < 3 || N < 500
        [frontNo, maxFNo] = ensSS(popObj, nSort);
    else
        [frontNo, maxFNo] = tENS(popObj, nSort);
    end
end

function [frontNo, maxFNo] = ensSS(popObj, nSort)
    [popObj, ~, loc] = unique(popObj, 'rows');
    tbl     = hist(loc, 1:max(loc));
    [N,M]   = size(popObj);
    frontNo = inf(1,N);
    maxFNo  = 0;
    while sum(tbl(frontNo<inf)) < min(nSort,length(loc))
        maxFNo = maxFNo + 1;
        for i = 1 : N
            if frontNo(i) == inf
                dominated = false;
                for j = i-1 : -1 : 1
                    if frontNo(j) == maxFNo
                        m = 2;
                        while m <= M && popObj(i,m) >= popObj(j,m)
                            m = m + 1;
                        end
                        dominated = m > M;
                        if dominated || M == 2
                            break;
                        end
                    end
                end
                if ~dominated
                    frontNo(i) = maxFNo;
                end
            end
        end
    end
    frontNo = frontNo(:,loc);
end

function [frontNo, maxFNo] = tENS(popObj, nSort)
    [popObj, ~, loc] = unique(popObj, 'rows');
    tbl       = hist(loc, 1:max(loc));
    [N,M]     = size(popObj);
    frontNo   = inf(1,N);
    maxFNo    = 0;
    forest    = zeros(1,N);
    children  = zeros(N,M-1);
    leftChild = zeros(1,N) + M;
    father    = zeros(1,N);
    brother   = zeros(1,N) + M;
    [~,oRank] = sort(popObj(:,2:M),2,'descend');
    oRank     = oRank + 1;
    while sum(tbl(frontNo<inf)) < min(nSort,length(loc))
        maxFNo = maxFNo + 1;
        root   = find(frontNo==inf,1);
        forest(maxFNo) = root;
        frontNo(root)  = maxFNo;
        for p = 1 : N
            if frontNo(p) == inf
                pruning = zeros(1,N);
                q = forest(maxFNo);
                while true
                    m = 1;
                    while m < M && popObj(p,oRank(q,m)) >= popObj(q,oRank(q,m))
                        m = m + 1;
                    end
                    if m == M
                        break;
                    else
                        pruning(q) = m;
                        if leftChild(q) <= pruning(q)
                            q = children(q,leftChild(q));
                        else
                            while father(q) && brother(q) > pruning(father(q))
                                q = father(q);
                            end
                            if father(q)
                                q = children(father(q),brother(q));
                            else
                                break;
                            end
                        end
                    end
                end
                if m < M
                    frontNo(p) = maxFNo;
                    q = forest(maxFNo);
                    while children(q,pruning(q))
                        q = children(q,pruning(q));
                    end
                    children(q,pruning(q)) = p;
                    father(p) = q;
                    if leftChild(q) > pruning(q)
                        brother(p)   = leftChild(q);
                        leftChild(q) = pruning(q);
                    else
                        bro = children(q,leftChild(q));
                        while brother(bro) < pruning(q)
                            bro = children(q,brother(bro));
                        end
                        brother(p)   = brother(bro);
                        brother(bro) = pruning(q);
                    end
                end
            end
        end
    end
    frontNo = frontNo(:,loc);
end
