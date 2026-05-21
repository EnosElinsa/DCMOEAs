classdef DCDTLZ2Short < DCDTLZ2
% DCDTLZ2Short - DC-DTLZ2 variant with reduced horizon (4 environments).
%
% Avoids the floating-point boundary case at t=5 where the constraint
% boundary coincides exactly with the Pareto front (sin(pi)=0 makes r=1.0
% and ||obj||^2=1.0 on the Pareto front, causing near-zero but non-zero CV).
% Suitable for quick demonstrations that reliably produce HV values.

    methods
        function initialize(obj, config)
            initialize@DCDTLZ2(obj, config);
            obj.tMax = 4;
        end
    end
end
