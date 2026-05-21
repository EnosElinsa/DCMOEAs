function config = createConfig(varargin)
% createConfig - Generic DCMOEA benchmark framework configuration.
%
% config = createConfig() returns a struct containing two sub-structures:
%   config.algo     - algorithm tunable parameters
%   config.run      - runtime parameters (seed, parallel, etc.)
%
% config = createConfig('algo.popSize', 200, 'run.seed', 42) overrides fields.

    %% ======================== algo ========================
    config.algo.popSize         = 100;          % population size N
    config.algo.maxGenPerEnv    = 50;           % maximum generations per environment
    config.algo.weights         = [];           % objective weights (empty = equal weights)

    %% ======================== run ========================
    config.run.seed         = 1;
    config.run.numRuns      = 30;               % number of independent runs
    config.run.numWorkers   = 0;                % number of parallel workers (0 = serial)
    config.run.seedBase     = 200;              % seed base
    config.run.problemIndex = 1;                % problem index (baseline compatibility)

    %% ======================== overrides ========================
    for i = 1:2:length(varargin)
        key = varargin{i};
        val = varargin{i+1};
        dotIdx = strfind(key, '.');
        if isempty(dotIdx), continue; end
        group = key(1:dotIdx(1)-1);
        field = key(dotIdx(1)+1:end);
        if isfield(config, group) && isfield(config.(group), field)
            config.(group).(field) = val;
        end
    end
end
