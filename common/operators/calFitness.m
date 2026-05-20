function fitness = calFitness(popObj, popCon)
% calFitness - Calculate the fitness of each solution (SPEA2-style).
% fitness = calFitness(popObj) calculates the fitness based on objective
% values only.
% fitness = calFitness(popObj, popCon) calculates the fitness considering
% constraint violations in popCon.
% Inputs:
% popObj - [N x M] objective value matrix
% popCon - [N x K] constraint violation matrix (optional)
% Outputs:
% fitness - [1 x N] fitness vector

    N = size(popObj,1);
    if nargin == 1
        cv = zeros(N,1);
    else
        cv = sum(max(0,popCon),2);
    end

    %% Detect the dominance relation between each two solutions
    dominate = false(N);
    for i = 1 : N-1
        for j = i+1 : N
            if cv(i) < cv(j)
                dominate(i,j) = true;
            elseif cv(i) > cv(j)
                dominate(j,i) = true;
            else
                k = any(popObj(i,:)<popObj(j,:)) - any(popObj(i,:)>popObj(j,:));
                if k == 1
                    dominate(i,j) = true;
                elseif k == -1
                    dominate(j,i) = true;
                end
            end
        end
    end
    
    %% Calculate S(i)
    S = sum(dominate,2);
    
    %% Calculate R(i)
    R = zeros(1,N);
    for i = 1 : N
        R(i) = sum(S(dominate(:,i)));
    end
    
    %% Calculate D(i)
    distance = pdist2(popObj,popObj);
    distance(logical(eye(length(distance)))) = inf;
    distance = sort(distance,2);
    D = 1./(distance(:,floor(sqrt(N)))+2);
    
    %% Calculate the fitnesses
    fitness = R + D';
end
