classdef DCDTLZ2 < DynamicProblem
% DCDTLZ2 - Dynamically constrained DTLZ2 test problem.
% Objective functions are based on DTLZ2 (spherical Pareto front), constraints vary dynamically with currentT.
%
% Features:
%   - 3 objectives (nObj = 3)
%   - 2 dynamic constraints (nCon = 2)
%   - 12 decision variables (M + k - 1 = 3 + 10 - 1 = 12)
%   - Constraints based on squared norm of objective vector (spherical constraints)
%   - Constraint radius varies dynamically with currentT

    properties (SetAccess = protected)
        lower
        upper
        nObj = 3
        nCon = 2
        tMax = 20
        currentT = 0
    end

    properties (Access = private)
        nVar       % Number of decision variables
        severity   % Severity of environmental change
    end

    methods
        function initialize(obj, config) %#ok<INUSD>
        % initialize - Initialize problem instance based on configuration
        %   config: general configuration struct (this problem does not use extra config parameters)
            obj.nVar = 12;  % M + k - 1 = 3 + 10 - 1
            obj.lower = zeros(1, obj.nVar);
            obj.upper = ones(1, obj.nVar);
            obj.currentT = 1;
            obj.severity = 5;
        end

        function [popObj, popCon, popDec] = calObj(obj, popDec)
        % calObj - Compute DTLZ2 objective functions and dynamic constraints
        %   Input: popDec [N x D] decision variable matrix
        %   Output: popObj [N x M] objective values
        %           popCon [N x K] constraint values (>0 indicates violation)
        %           popDec [N x D] decision variables (unmodified)
            N = size(popDec, 1);
            M = obj.nObj;

            % Dynamic parameters: shift varying with t
            shift = 0.5 * sin(0.5 * pi * obj.currentT / obj.severity);

            % DTLZ2 g function
            g = sum((popDec(:, M:end) - shift).^2, 2);

            % DTLZ2 objectives (spherical)
            popObj = zeros(N, M);
            popObj(:, 1) = (1 + g) .* prod(cos(popDec(:, 1:M-1) * pi/2), 2);
            for m = 2:M-1
                popObj(:, m) = (1 + g) .* prod(cos(popDec(:, 1:M-m) * pi/2), 2) ...
                    .* sin(popDec(:, M-m+1) * pi/2);
            end
            popObj(:, M) = (1 + g) .* sin(popDec(:, 1) * pi/2);

            % Dynamic constraints (spherical constraints, varying with t)
            r = 1.0 + 0.2 * sin(pi * obj.currentT / obj.severity);
            sumObjSq = sum(popObj.^2, 2);
            popCon = zeros(N, 2);
            popCon(:, 1) = sumObjSq - r^2;            % ||obj||^2 <= r^2
            popCon(:, 2) = -(sumObjSq - (0.2 * r)^2); % ||obj||^2 >= (0.2*r)^2
        end

        function domain = getDomain(obj)
        % getDomain - Return decision space boundaries
        %   Output: domain [D x 2] matrix, column 1 = lower bound, column 2 = upper bound
            domain = [obj.lower', obj.upper'];
        end

        function D = getDecisionDims(obj)
        % getDecisionDims - Return number of decision variable dimensions D
            D = obj.nVar;
        end

        function info = updateAfterExecution(obj, selectedDec) %#ok<INUSG>
        % updateAfterExecution - Update problem state after executing selected decision
        %   Input: selectedDec [1 x D] selected decision variables
        %   Output: info struct with diagnostic information
            info.selectedDec = selectedDec;
            info.currentT = obj.currentT;
        end

        function updateEnvironment(obj)
        % updateEnvironment - Advance to next dynamic environment
            obj.currentT = obj.currentT + 1;
        end

        function done = isDone(obj)
        % isDone - Determine if problem has terminated
            done = (obj.currentT >= obj.tMax);
        end

        function s = toStruct(obj)
        % toStruct - Serialize to struct (for logging)
            s.currentT = obj.currentT;
            s.nObj = obj.nObj;
            s.nCon = obj.nCon;
            s.severity = obj.severity;
        end
    end
end
