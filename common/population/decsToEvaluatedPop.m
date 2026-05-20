function [pop, state] = decsToEvaluatedPop(dec, problem, state)
% decsToEvaluatedPop - Create Solution objects from decision matrix and evaluate.
%
% Inputs:
%   dec     - [N×D] decision variable matrix
%   problem - DynamicProblem instance
%   state   - mutable runtime state
%
% Outputs:
%   pop   - evaluated Solution object array [1×N]
%   state - updated runtime state

    pop = Solution.fromDecs(dec);
    [pop, state] = evaluatePopulation(problem, pop, state);
end
