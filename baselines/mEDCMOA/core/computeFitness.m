function fitness = computeFitness(pop, option)
% computeFitness - Compute fitness values for a population.
% Eqa5 = number of individuals dominated BY this individual.
% Eqa6 = number of individuals that DOMINATE this individual.
% Inputs:
% pop - Solution object array
% option - 'Eqa5' or 'Eqa6'
% Outputs:
% fitness - [1 x N] fitness values

    N = numel(pop);
    fitness5 = zeros(1, N);
    fitness6 = zeros(1, N);
    for i = 1:N
        for j = i+1:N
            flag = checkDominance(pop(i).obj, 0, pop(j).obj, 0);
            if flag == 1
                fitness5(i) = fitness5(i) + 1;
                fitness6(j) = fitness6(j) + 1;
            elseif flag == -1
                fitness5(j) = fitness5(j) + 1;
                fitness6(i) = fitness6(i) + 1;
            end
        end
    end
    switch option
        case 'Eqa5'
            fitness = fitness5;
        case 'Eqa6'
            fitness = fitness6;
        otherwise
            error('Unknown fitness option');
    end
end
