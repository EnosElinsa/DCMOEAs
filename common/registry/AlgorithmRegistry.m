classdef AlgorithmRegistry
% AlgorithmRegistry - Maps a baseline algorithm name to its TrialDriver class.
%
% Replaces the path-shadowing dispatch of round 2 (addpath + runAlgorithmTrial).
% The default registry contains the six built-in baselines:
%   CRDCMO     -> CrdcmoDriver
%   TDCEA      -> TdceaDriver
%   mEDCMOA    -> MedcmoaDriver
%   DCNSGAII_A -> DcnsgaiiADriver
%   DCNSGAII_B -> DcnsgaiiBDriver
%   HATC       -> HatcDriver
%
% Static methods:
%   register(name, driverCtor)  - Add a new (name, driver-constructor) entry.
%   lookup(name)                - Return the constructor handle for a name.
%   listAlgorithms()            - Return sorted cell array of registered names.
%   isRegistered(name)          - Return logical: is name registered?

    methods (Static)
        function register(name, driverCtor)
        % register - Add a new (name, driver-constructor) entry.
        %   name must be a non-empty char row vector or scalar string.
        %   driverCtor must be a function handle.
        %   Raises AlgorithmRegistry:invalidArgument if inputs are invalid.
        %   Raises AlgorithmRegistry:duplicateRegistration if name already exists.
            name = AlgorithmRegistry.validateName(name);
            if ~isa(driverCtor, 'function_handle')
                error('AlgorithmRegistry:invalidArgument', ...
                    'driverCtor must be a function handle, got %s.', class(driverCtor));
            end
            reg = AlgorithmRegistry.getRegistry();
            if reg.isKey(name)
                error('AlgorithmRegistry:duplicateRegistration', ...
                    'Algorithm ''%s'' is already registered.', name);
            end
            reg(name) = driverCtor; %#ok<NASGU>
        end

        function ctor = lookup(name)
        % lookup - Return the constructor handle for a registered algorithm.
        %   Raises AlgorithmRegistry:unknownAlgorithm if name is not registered.
            name = AlgorithmRegistry.validateName(name);
            reg = AlgorithmRegistry.getRegistry();
            if ~reg.isKey(name)
                available = AlgorithmRegistry.listAlgorithms();
                error('AlgorithmRegistry:unknownAlgorithm', ...
                    'Algorithm ''%s'' is not registered. Available: %s', ...
                    name, strjoin(available, ', '));
            end
            ctor = reg(name);
        end

        function names = listAlgorithms()
        % listAlgorithms - Return a sorted cell array of all registered names.
        %   Names are char row vectors, sorted ascending (case-sensitive).
            reg = AlgorithmRegistry.getRegistry();
            names = sort(reg.keys());
        end

        function tf = isRegistered(name)
        % isRegistered - Return logical scalar: is name registered?
        %   Performs exact case-sensitive comparison.
            name = AlgorithmRegistry.validateName(name);
            reg = AlgorithmRegistry.getRegistry();
            tf = reg.isKey(name);
        end
    end

    methods (Static, Access = private)
        function reg = getRegistry()
        % getRegistry - Return the singleton registry map (lazy-initialized).
        %   Uses a persistent variable so the registry survives across calls.
        %   On first access, populates the six built-in baselines.
            persistent registry
            if isempty(registry)
                registry = containers.Map('KeyType', 'char', 'ValueType', 'any');
                registry('CRDCMO')     = @CrdcmoDriver;
                registry('TDCEA')      = @TdceaDriver;
                registry('mEDCMOA')    = @MedcmoaDriver;
                registry('DCNSGAII_A') = @DcnsgaiiADriver;
                registry('DCNSGAII_B') = @DcnsgaiiBDriver;
                registry('HATC')       = @HatcDriver;
            end
            reg = registry;
        end

        function name = validateName(name)
        % validateName - Ensure name is a non-empty char row vector or scalar string.
        %   Converts scalar string to char. Raises AlgorithmRegistry:invalidArgument
        %   if the input is invalid.
            if isstring(name) && isscalar(name)
                name = char(name);
            end
            if ~ischar(name) || isempty(name) || ~isrow(name)
                error('AlgorithmRegistry:invalidArgument', ...
                    'name must be a non-empty char row vector or scalar string.');
            end
        end
    end
end
