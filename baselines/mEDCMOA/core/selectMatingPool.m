function pPrime = selectMatingPool(pop)
% selectMatingPool - Binary tournament on modified objectives for mEDCMOA.
% Uses modified objectives (via modifyObjectives) for selection.
% Inputs:
% pop - Solution object array
% Outputs:
% pPrime - [N x 1] selected parent indices

    N = numel(pop);
    pPrime = [];

    %% Calculate modified objective values
    modifiedObj = modifyObjectives(pop);  % [M x N]

    [frontNo, ~] = ndSort(modifiedObj', [], N);
    crowdDistances = crowdingDistance(modifiedObj', frontNo);

    %% Binary tournament selection
    for i = 1:N
        indices = randperm(N, 2);

        flag = checkDominance(modifiedObj(:, indices(1)), 0, ...
                              modifiedObj(:, indices(2)), 0);

        if flag == 1
            pPrime = [pPrime; indices(1)];
        elseif flag == -1
            pPrime = [pPrime; indices(2)];
        else
            if crowdDistances(indices(1)) > crowdDistances(indices(2))
                pPrime = [pPrime; indices(1)];
            elseif crowdDistances(indices(1)) < crowdDistances(indices(2))
                pPrime = [pPrime; indices(2)];
            else
                if rand() < 0.5
                    pPrime = [pPrime; indices(1)];
                else
                    pPrime = [pPrime; indices(2)];
                end
            end
        end
    end
end
