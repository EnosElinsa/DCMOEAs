function offspring = operatorDE(domain,parent1,parent2,parent3,parameter)
% operatorDE - Differential evolution operator.
% off = operatorDE(domain,p1,p2,p3) generates offspring using DE:
% p1 + F*(p2-p3) followed by polynomial mutation.
% off = operatorDE(domain,p1,p2,p3,{CR,F,proM,disM}) specifies the
% parameters of operators.
% Inputs:
% domain - [2 x D] bounds: domain(1,:) = lower, domain(2,:) = upper
% parent1 - [N x D] first parent set
% parent2 - [N x D] second parent set
% parent3 - [N x D] third parent set
% parameter - (optional) cell {CR, F, proM, disM}
% Outputs:
% offspring - [N x D] offspring decision variables

    %% Parameter setting
    if nargin > 4
        [CR,F,proM,disM] = deal(parameter{:});
    else
        [CR,F,proM,disM] = deal(1,0.5,1,20);
    end
    [N,D] = size(parent1);

    %% Differental evolution
    site = rand(N,D) < CR;
    offspring       = parent1;
    offspring(site) = offspring(site) + F*(parent2(site)-parent3(site));

    %% Polynomial mutation
    offspring = polynomialMutation(offspring, domain, proM/D, disM);
end
