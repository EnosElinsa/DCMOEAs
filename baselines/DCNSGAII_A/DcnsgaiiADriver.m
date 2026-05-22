classdef DcnsgaiiADriver < TrialDriver
% DcnsgaiiADriver - TrialDriver subclass for DNSGA-II-A.
% Implements the standard NSGA-II evolution with SBX/PM operators
% and random-replacement change response (DNSGA-II variant A).

    properties (Access = private)
        pop             % Current population [1×N Solution array]
        operatorParams  % SBX/PM operator parameters struct
        replacementRate % Fraction of population replaced on environment change
    end

    methods
        function obj = DcnsgaiiADriver(config, problemFactory)
            obj@TrialDriver(config, problemFactory);
        end
    end

    methods (Access = protected)
        function initialize(this)
            this.pop = this.initialPop;
            % NSGA-II default SBX/PM parameters (Deb et al. 2002)
            this.operatorParams = struct('proC',1,'disC',20,'proM',1,'disM',20);
            % DNSGA-II-A change-response replacement ratio (Deb et al. 2007)
            this.replacementRate = 0.2;
        end

        function evolveStep(this)
            [this.pop, this.state] = evolve(this.config, this.state, ...
                this.problem, this.pop, this.operatorParams);
        end

        function respondToChange(this)
            [this.pop, this.state] = respondToChange(this.config, ...
                this.state, this.problem, this.pop, this.replacementRate);
        end

        function pop = currentPop(this)
            pop = this.pop;
        end
    end
end
