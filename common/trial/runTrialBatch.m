function runTrialBatch(saveDir, numRuns, numWorkers, seedBase, trialFn, label)
% runTrialBatch - Batch execution of independent trials.
%
% Supports serial/parallel modes, checkpoint resume, and incremental checkpoint saving.
%
% Input:
%   saveDir    - directory for saving results
%   numRuns    - number of independent runs
%   numWorkers - number of parallel workers (0 = serial)
%   seedBase   - seed base (seed for trial k = seedBase + k)
%   trialFn    - function handle @(seed) -> result struct
%                result must contain .feasible and .outputInfo fields
%   label      - display label (algorithm name)

    % Create save directory
    if ~exist(saveDir, 'dir')
        mkdir(saveDir);
    end

    % Checkpoint file path
    checkpointFile = fullfile(saveDir, 'checkpoint.mat');

    % Load existing checkpoint or initialize
    [results, completedRuns] = loadCheckpoint(checkpointFile, numRuns);

    % Determine pending trials
    pendingRuns = find(~completedRuns);
    nDone = sum(completedRuns);

    if isempty(pendingRuns)
        fprintf('  [%s] All %d runs already complete\n', label, numRuns);
        saveFinalResults(saveDir, results, completedRuns);
        return;
    end

    if nDone > 0
        fprintf('  [%s] Resuming: %d/%d runs already complete\n', label, nDone, numRuns);
    end

    % Incremental save interval
    saveEvery = 5;

    %% Serial mode (numWorkers == 0)
    if numWorkers == 0
        fprintf('  [%s] Running %d tasks serially...\n', label, length(pendingRuns));
        sinceLastSave = 0;

        for k = 1:length(pendingRuns)
            runIdx = pendingRuns(k);
            seed = seedBase + runIdx;

            try
                tStart = tic;
                result = trialFn(seed);
                result.wallTime = toc(tStart);
            catch ME
                fprintf('  [%s] Run %d/%d FAILED: %s\n', label, runIdx, numRuns, ME.message);
                result.feasible = false;
                result.outputInfo = struct();
                result.wallTime = 0;
                result.error = ME.message;
            end

            results{runIdx} = result;
            completedRuns(runIdx) = true;

            fprintf('  [%s] Run %d/%d completed | Feasible=%d | %.1fs\n', ...
                label, runIdx, numRuns, result.feasible, result.wallTime);

            % Incremental checkpoint save
            sinceLastSave = sinceLastSave + 1;
            if sinceLastSave >= saveEvery || k == length(pendingRuns)
                saveCheckpoint(checkpointFile, results, completedRuns);
                sinceLastSave = 0;
            end
        end

    %% Parallel mode (numWorkers > 0)
    else
        fprintf('  [%s] Submitting %d tasks to %d workers...\n', ...
            label, length(pendingRuns), numWorkers);

        pool = gcp('nocreate');
        if isempty(pool)
            pool = parpool('local', numWorkers);
        end

        % Submit all pending trials
        nPending = length(pendingRuns);
        futures(1:nPending) = parallel.FevalFuture;
        for k = 1:nPending
            seed = seedBase + pendingRuns(k);
            futures(k) = parfeval(pool, @executeTrialTimed, 1, trialFn, seed);
        end

        % Fetch results one by one
        sinceLastSave = 0;
        for k = 1:nPending
            try
                [completedIdx, result] = fetchNext(futures);
            catch ME
                % fetchNext itself threw an exception - find the errored future
                completedIdx = findErrorFuture(futures, pendingRuns, completedRuns);
                if isempty(completedIdx)
                    % Cannot determine which future errored, skip
                    fprintf('  [%s] fetchNext error: %s\n', label, ME.message);
                    continue;
                end
                result.feasible = false;
                result.outputInfo = struct();
                result.wallTime = 0;
                result.error = ME.message;
            end

            runIdx = pendingRuns(completedIdx);
            results{runIdx} = result;
            completedRuns(runIdx) = true;

            if isfield(result, 'error')
                fprintf('  [%s] Run %d/%d FAILED: %s\n', ...
                    label, runIdx, numRuns, result.error);
            else
                fprintf('  [%s] Run %d/%d completed | Feasible=%d | %.1fs\n', ...
                    label, runIdx, numRuns, result.feasible, result.wallTime);
            end

            % Incremental checkpoint save
            sinceLastSave = sinceLastSave + 1;
            if sinceLastSave >= saveEvery || k == nPending
                saveCheckpoint(checkpointFile, results, completedRuns);
                sinceLastSave = 0;
            end
        end
    end

    % Final save of results.mat
    saveFinalResults(saveDir, results, completedRuns);
    fprintf('  [%s] All %d runs complete. Results saved to %s\n', ...
        label, numRuns, fullfile(saveDir, 'results.mat'));
end


%% =====================================================================
%%  Helper Functions
%% =====================================================================

function result = executeTrialTimed(trialFn, seed)
% executeTrialTimed - Execute a single trial with timing, catching exceptions.
    tStart = tic;
    try
        result = trialFn(seed);
        result.wallTime = toc(tStart);
    catch ME
        result.feasible = false;
        result.outputInfo = struct();
        result.wallTime = toc(tStart);
        result.error = ME.message;
    end
end

function [results, completedRuns] = loadCheckpoint(checkpointFile, numRuns)
% loadCheckpoint - Load existing checkpoint or initialize empty results.
    if isfile(checkpointFile)
        loaded = load(checkpointFile);
        if isfield(loaded, 'completedRuns') && length(loaded.completedRuns) == numRuns
            results = loaded.results;
            completedRuns = loaded.completedRuns;
            return;
        end
    end
    results = cell(1, numRuns);
    completedRuns = false(1, numRuns);
end

function saveCheckpoint(checkpointFile, results, completedRuns)
% saveCheckpoint - Save checkpoint to disk.
    save(checkpointFile, 'results', 'completedRuns');
end

function saveFinalResults(saveDir, results, completedRuns)
% saveFinalResults - Save final results.mat file.
    resultsFile = fullfile(saveDir, 'results.mat');
    save(resultsFile, 'results', 'completedRuns');
end

function idx = findErrorFuture(futures, pendingRuns, completedRuns)
% findErrorFuture - Find the index of the errored future among parfeval futures.
    idx = [];
    for k = 1:length(futures)
        runIdx = pendingRuns(k);
        if ~completedRuns(runIdx) && strcmp(futures(k).State, 'finished') ...
                && ~isempty(futures(k).Error)
            idx = k;
            return;
        end
    end
end
