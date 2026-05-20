classdef DCDTLZ1 < DynamicProblem
% DCDTLZ1 - Dynamically constrained DTLZ1 test problem.
% Objective functions and constraints vary with currentT.

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
            obj.nVar = 12;  % Default M + k - 1 = 3 + 10 - 1
            obj.lower = zeros(1, obj.nVar);
            obj.upper = ones(1, obj.nVar);
            obj.currentT = 1;
            obj.severity = 5;  % Can be read from config
        end

        function [popObj, popCon, popDec] = calObj(obj, popDec)
            [N, D] = size(popDec);
            M = obj.nObj;
            k = D - M + 1;

            % Dynamic parameters: shift varying with t
            shift = 0.5 * sin(0.5 * pi * obj.currentT / obj.severity);

            % DTLZ1 objectives
            g = 100 * (k + sum((popDec(:,M:end) - shift).^2 ...
                - cos(20*pi*(popDec(:,M:end) - shift)), 2));

            popObj = zeros(N, M);
            popObj(:,1) = 0.5 * prod(popDec(:,1:M-1), 2) .* (1 + g);
            for m = 2:M-1
                popObj(:,m) = 0.5 * prod(popDec(:,1:M-m), 2) ...
                    .* (1 - popDec(:,M-m+1)) .* (1 + g);
            end
            popObj(:,M) = 0.5 * (1 - popDec(:,1)) .* (1 + g);

            % Dynamic constraints
            r = 0.5 + 0.1 * sin(pi * obj.currentT / obj.severity);
            sumObj = sum(popObj, 2);
            popCon = zeros(N, 2);
            popCon(:,1) = sumObj - r;           % sum(obj) <= r
            popCon(:,2) = -(sumObj - 0.1*r);    % sum(obj) >= 0.1*r
        end

        function domain = getDomain(obj)
            domain = [obj.lower', obj.upper'];
        end

        function D = getDecisionDims(obj)
            D = obj.nVar;
        end

        function info = updateAfterExecution(obj, selectedDec) %#ok<INUSD>
            info.selectedDec = selectedDec;
            info.currentT = obj.currentT;
        end

        function updateEnvironment(obj)
            obj.currentT = obj.currentT + 1;
        end

        function done = isDone(obj)
            done = (obj.currentT >= obj.tMax);
        end

        function s = toStruct(obj)
            s.currentT = obj.currentT;
            s.nObj = obj.nObj;
            s.nCon = obj.nCon;
        end
    end
end
