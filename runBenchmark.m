function runBenchmark(problemFactory, varargin)
% runBenchmark - DCMOEA benchmark framework entry point.
%
% Usage:
%   runBenchmark(@MyProblemFactory)
%   runBenchmark(@MyProblemFactory, 'algo.popSize', 200, 'run.numRuns', 30)
%   runBenchmark(@MyProblemFactory, 'algorithms', {'CRDCMO','TDCEA'})
%   runBenchmark(@MyProblemFactory, 'resultsDir', './my_results')
%
% Input:
%   problemFactory - function handle @(config) -> DynamicProblem instance
%   varargin       - key-value configuration overrides
%
% problemFactory signature:
%   function problem = myFactory(config)
%       problem = MyDCMOP();
%       problem.initialize(config);
%   end

    % Parse arguments: extract special keys, pass remaining to createConfig
    [algorithms, resultsDir, configOverrides] = parseArgs(varargin);

    % Create configuration
    config = createConfig(configOverrides{:});

    % Set up framework paths
    setupFrameworkPaths();

    fprintf('=== DCMOEA Benchmark ===\n');
    fprintf('Algorithms: %s\n', strjoin(algorithms, ', '));
    fprintf('Results dir: %s\n', resultsDir);
    fprintf('Runs per algorithm: %d\n', config.run.numRuns);
    fprintf('========================\n\n');

    % Run all algorithms
    for aIdx = 1:length(algorithms)
        algoName = algorithms{aIdx};
        fprintf('[%d/%d] Running algorithm: %s\n', aIdx, length(algorithms), algoName);

        try
            % Lookup driver constructor from registry
            driverCtor = AlgorithmRegistry.lookup(algoName);

            % Construct trialFn
            trialFn = @(seed) runSingleTrial(driverCtor, seed, config, problemFactory);

            % Call batch execution
            runTrialBatch( ...
                fullfile(resultsDir, algoName), ...
                config.run.numRuns, ...
                config.run.numWorkers, ...
                config.run.seedBase, ...
                trialFn, algoName);

        catch ME
            fprintf('  [%s] ALGORITHM FAILED: %s\n', algoName, ME.message);
            fprintf('  Continuing with remaining algorithms...\n\n');
        end
    end

    % Post-processing: HV computation (delegated to analyzeResults)
    fprintf('\n=== Post-processing: HV Computation ===\n');
    try
        hvResults = analyzeResults(resultsDir, algorithms); %#ok<NASGU>
    catch ME
        fprintf('  Post-processing FAILED: %s\n', ME.message);
    end
end


%% =====================================================================
%%  Local Functions
%% =====================================================================

function [algorithms, resultsDir, configOverrides] = parseArgs(args)
% parseArgs - Parse varargin, extract special keys, pass remaining as configuration overrides.
%
% Special keys:
%   'algorithms' - cell array of algorithm names
%   'resultsDir' - string, results directory path

    algorithms = {'CRDCMO', 'TDCEA', 'mEDCMOA', 'DCNSGAII_A', 'DCNSGAII_B', 'HATC'};
    resultsDir = './results';
    configOverrides = {};

    i = 1;
    while i <= length(args)
        if ischar(args{i}) || isstring(args{i})
            key = char(args{i});
            if i + 1 <= length(args)
                val = args{i + 1};
                if strcmpi(key, 'algorithms')
                    algorithms = val;
                    i = i + 2;
                elseif strcmpi(key, 'resultsDir')
                    resultsDir = val;
                    i = i + 2;
                else
                    % Configuration override parameter, pass to createConfig
                    configOverrides{end+1} = key; %#ok<AGROW>
                    configOverrides{end+1} = val; %#ok<AGROW>
                    i = i + 2;
                end
            else
                % Odd number of arguments, skip
                i = i + 1;
            end
        else
            i = i + 1;
        end
    end
end


function setupFrameworkPaths()
% setupFrameworkPaths - Add framework common and baseline paths.
    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(rootDir, 'common')));
    addpath(genpath(fullfile(rootDir, 'baselines')));
end


function result = runSingleTrial(driverCtor, seed, config, problemFactory)
% runSingleTrial - Execute a single algorithm trial.
%
% Set seed, construct the driver via the registry-provided constructor,
% and call driver.run().
%
% Input:
%   driverCtor     - driver constructor handle (from AlgorithmRegistry.lookup)
%   seed           - random seed
%   config         - framework configuration struct
%   problemFactory - problem factory function handle

    % Ensure framework paths are available (parallel workers may need this)
    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(rootDir, 'common')));
    addpath(genpath(fullfile(rootDir, 'baselines')));

    % Set seed
    config.run.seed = seed;

    % Construct driver and run trial
    driver = driverCtor(config, problemFactory);
    result = driver.run();
end



