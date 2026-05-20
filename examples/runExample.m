% runExample.m - DCMOEA benchmark framework example script
%
% Runs a complete trial using the DC-DTLZ1 test problem and the DCNSGAII_A baseline algorithm.
% Can be run directly without modifying any parameters.
%
% Output:
%   Console output includes a summary with algorithm name and MHV (Mean Hypervolume) statistics.
%
% Usage:
%   >> cd examples
%   >> runExample

%% ======================== Path setup ========================
% Get project root directory (parent of examples)
rootDir = fileparts(fileparts(mfilename('fullpath')));

% Add framework common paths
addpath(genpath(fullfile(rootDir, 'common')));

% Add baseline algorithm paths
addpath(genpath(fullfile(rootDir, 'baselines')));

% Add example problem paths
addpath(fullfile(rootDir, 'examples', 'DCDTLZ'));

%% ======================== MEX file check ========================
% Check if Hypervolume MEX file is available
mexFile = fullfile(rootDir, 'common', 'metrics', 'Hypervolume.mexw64');
if ~isfile(mexFile)
    % Try 32-bit version
    mexFile32 = fullfile(rootDir, 'common', 'metrics', 'Hypervolume_MEX.mexw32');
    if ~isfile(mexFile32)
        error('runExample:missingMEX', ...
            ['Required MEX file not found:\n' ...
             '  %s\n' ...
             '  %s\n' ...
             'Please compile or obtain the Hypervolume MEX binary for your platform.'], ...
            mexFile, mexFile32);
    end
end

%% ======================== Run benchmark ========================
fprintf('=== DC-DTLZ1 Example ===\n');
fprintf('Algorithm: DCNSGAII_A\n');
fprintf('Runs: 5 (reduced for demonstration)\n');
fprintf('========================\n\n');

% Use DC-DTLZ1 factory function
factory = @dcdtlzFactory;

% Run benchmark
%   - Use DCNSGAII_A single baseline algorithm
%   - 5 independent runs (reduced for faster demonstration)
%   - Serial execution (numWorkers=0)
%   - Results saved to results/example directory
runBenchmark(factory, ...
    'algo.popSize', 100, ...
    'algo.maxGenPerEnv', 50, ...
    'run.numRuns', 5, ...
    'run.numWorkers', 0, ...
    'algorithms', {'DCNSGAII_A'}, ...
    'resultsDir', fullfile(rootDir, 'results', 'example'));
