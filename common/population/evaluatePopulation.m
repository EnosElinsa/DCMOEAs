function [pop, state] = evaluatePopulation(problem, pop, state)
% evaluatePopulation - Evaluate population objectives and constraints.
%
% Calls problem.calObj(dec) to obtain objective values and constraint values,
% and populates the obj/con/cv fields of each Solution.
%
% Input:
%   problem - DynamicProblem instance
%   pop     - Solution object array [1×N]
%   state   - runtime state struct with .fes field
%
% Output:
%   pop   - Solution array with obj/con/cv populated
%   state - state with .fes incremented by N

    % Guard: skip empty population
    if numel(pop) == 0
        return;
    end

    % Filter individuals with empty decision variables
    validMask = arrayfun(@(s) ~isempty(s.dec), pop);
    if ~all(validMask)
        pop = pop(validMask);
        if numel(pop) == 0
            return;
        end
    end

    dec = pop.decs();  % [N x D]

    [popObj, popCon, dec] = problem.calObj(dec);

    for i = 1:numel(pop)
        pop(i).dec = dec(i, :);
        pop(i).obj = popObj(i, :);
        pop(i).con = popCon(i, :);
        pop(i).cv  = sum(max(0, popCon(i, :)));
    end

    state.fes = state.fes + numel(pop);
end
