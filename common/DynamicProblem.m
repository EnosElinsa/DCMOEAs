classdef (Abstract) DynamicProblem < handle
% DynamicProblem - Abstract base class for dynamic constrained multi-objective problems.
% All custom problems must inherit from this class and implement all abstract methods.
%
% Abstract properties:
%   lower    - [1 x D] decision variables lower bounds
%   upper    - [1 x D] decision variables upper bounds
%   nObj     - number of objective functions M (positive integer)
%   nCon     - number of constraints K (non-negative integer)
%   tMax     - maximum number of environment changes / dynamic periods (positive integer)
%   currentT - current environment period (positive integer, initial value is 1)
%
% Abstract methods:
%   initialize          - Initialize problem instance based on configuration
%   calObj              - Compute objective functions and constraints
%   getDomain           - Return decision space boundaries
%   getDecisionDims     - Return decision variable dimensions
%   updateAfterExecution- Update problem state after executing selected decision
%   updateEnvironment   - Advance to the next dynamic environment
%   isDone              - Determine whether the problem has terminated
%   toStruct            - Serialize to struct
%
% Default methods:
%   selectBest          - Weighted sum selection of best feasible solution

    properties (Abstract, SetAccess = protected)
        lower       % [1 x D] decision variables lower bounds
        upper       % [1 x D] decision variables upper bounds
        nObj        % number of objective functions M
        nCon        % number of constraints K
        tMax        % maximum number of environment changes (dynamic periods)
        currentT    % current environment period
    end

    methods (Abstract)
        % initialize - Initialize problem instance based on configuration
        %   config: generic configuration struct
        initialize(obj, config)

        % calObj - Compute objective functions and constraints
        %   Input: popDec [N x D] decision variable matrix
        %   Output: popObj [N x M] objective values
        %           popCon [N x K] constraint values (>0 indicates violation)
        %           popDec [N x D] possibly corrected decision variables
        [popObj, popCon, popDec] = calObj(obj, popDec)

        % getDomain - Return decision space boundaries
        %   Output: domain [D x 2] matrix, column 1 = lower bounds, column 2 = upper bounds
        domain = getDomain(obj)

        % getDecisionDims - Return decision variable dimensions D
        D = getDecisionDims(obj)

        % updateAfterExecution - Update problem state after executing selected decision
        %   Input: selectedDec [1 x D]
        %   Output: info struct (problem-specific diagnostic information)
        info = updateAfterExecution(obj, selectedDec)

        % updateEnvironment - Advance to the next dynamic environment
        updateEnvironment(obj)

        % isDone - Determine whether the problem has terminated (all periods completed)
        done = isDone(obj)

        % toStruct - Serialize to struct (for logging)
        s = toStruct(obj)
    end

    methods
        function bestSol = selectBest(obj, feasiblePop, weights) %#ok<INUSL>
        % selectBest - Default best solution selection (can be overridden)
        % Performs min-max normalization on the objective values of the feasible
        % population column-wise to [0, 1], then computes the weighted sum and
        % returns the individual with the minimum weighted sum.
        %
        %   Input:
        %     feasiblePop - feasible population (Solution array)
        %     weights     - [1 x M] or [M x 1] objective weights vector
        %
        %   Output:
        %     bestSol - individual with minimum weighted sum, returns [] if feasiblePop is empty

            % Handle empty population edge case
            if isempty(feasiblePop)
                bestSol = [];
                return;
            end

            % Get objective value matrix [N x M]
            feasibleObj = feasiblePop.objs();

            % Min-max normalization
            objMin = min(feasibleObj, [], 1);
            objMax = max(feasibleObj, [], 1);
            objRange = objMax - objMin;
            objRange(objRange == 0) = 1;  % Avoid division by zero
            normObj = (feasibleObj - objMin) ./ objRange;

            % Weighted sum computation
            weightedSum = normObj * weights(:);

            % Select individual with minimum weighted sum
            [~, bestIdx] = min(weightedSum);
            bestSol = feasiblePop(bestIdx);
        end
    end
end
