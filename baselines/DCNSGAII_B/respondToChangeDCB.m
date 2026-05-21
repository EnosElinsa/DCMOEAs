function [pop, state] = respondToChangeDCB(config, state, problem, pop) %#ok<INUSL>
% respondToChangeDCB - DNSGA-II-B change response (polynomial mutation).
% Mutates a zeta fraction of the population using the shared
% operatorParams (per-bit rate proM/D) and re-evaluates.
    zeta = 0.5;  % DNSGA-II-B mutation fraction
    popsize = numel(pop);
    N = floor(popsize * zeta / 2) * 2;
    selected = randperm(popsize, N);

    domain = problem.getDomain();
    D = size(domain, 1);
    selectedDecs = pop(selected).decs();

    % Polynomial mutation
    op = struct('proC',1,'disC',20,'proM',1,'disM',20);
    selectedDecs = polynomialMutation(selectedDecs, domain, op.proM/D, op.disM);

    for i = 1:N
        pop(selected(i)).dec = selectedDecs(i, :);
    end

    [pop, state] = evaluatePopulation(problem, pop, state);
end

