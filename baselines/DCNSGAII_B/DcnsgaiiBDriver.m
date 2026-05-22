classdef DcnsgaiiBDriver < TrialDriver
% DcnsgaiiBDriver - TrialDriver subclass for DNSGA-II-B.
% Implements the standard NSGA-II evolution with SBX/PM operators
% and polynomial-mutation change response (DNSGA-II variant B).

    properties (Access = private)
        pop             % Current population [1×N Solution array]
        operatorParams  % SBX/PM operator parameters struct
    end

    methods
        function obj = DcnsgaiiBDriver(config, problemFactory)
            obj@TrialDriver(config, problemFactory);
        end
    end

    methods (Access = protected)
        function initialize(this)
            this.pop = this.initialPop;
            % NSGA-II default SBX/PM parameters (Deb et al. 2002)
            this.operatorParams = struct('proC',1,'disC',20,'proM',1,'disM',20);
        end

        function evolveStep(this)
            [this.pop, this.state] = evolve(this.config, this.state, ...
                this.problem, this.pop, this.operatorParams);
        end

        function respondToChange(this)
            % respondToChangeDCB declares its own local op struct internally
            % using the same default values as this.operatorParams.
            [this.pop, this.state] = respondToChangeDCB(this.config, ...
                this.state, this.problem, this.pop);
        end

        function pop = currentPop(this)
            pop = this.pop;
        end
    end
end
