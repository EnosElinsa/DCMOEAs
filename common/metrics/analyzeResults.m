function hvResults = analyzeResults(resultsDir, algorithms)
% analyzeResults - Post-processing: compute reference point, HV, print summary.
%
% Standalone function extracted from runBenchmark.m for testability and reuse.
% Computes a global reference point across all algorithm results, calculates
% per-trial hypervolume values, and prints a formatted summary table.
%
% Inputs:
%   resultsDir - path to results directory (char vector)
%   algorithms - cell array of algorithm name strings
%
% Outputs:
%   hvResults  - struct array with fields:
%                .algoName (string)
%                .hvValues ([1×numRuns] doubles, -1 for infeasible)
%                .meanHV   (scalar or NaN)
%                .stdHV    (scalar or NaN)

    refPoint = computeReferencePoint(resultsDir, algorithms);
    if isempty(refPoint)
        fprintf('  WARNING: No feasible results found.\n');
        hvResults = struct('algoName',{},'hvValues',{},'meanHV',{},'stdHV',{});
        return;
    end
    hvResults = computeAllHV(resultsDir, algorithms, refPoint);
    printSummary(algorithms, hvResults);
end


%% =====================================================================
%%  Local Functions
%% =====================================================================

function refPoint = computeReferencePoint(resultsDir, algorithms)
% computeReferencePoint - Scan all results to compute reference point.
%
% Reference point = per-dimension maximum of all feasible objective values * 1.1 (10% margin).
% Returns empty [] if no feasible results exist.

    refPoint = [];
    maxObjs = [];

    for aIdx = 1:length(algorithms)
        algoName = algorithms{aIdx};
        resultsFile = fullfile(resultsDir, algoName, 'results.mat');

        if ~isfile(resultsFile)
            continue;
        end

        loaded = load(resultsFile);
        if ~isfield(loaded, 'results')
            continue;
        end

        results = loaded.results;
        for rIdx = 1:length(results)
            r = results{rIdx};
            if isempty(r) || ~isfield(r, 'feasible') || ~r.feasible
                continue;
            end
            if ~isfield(r, 'outputInfo') || ~isfield(r.outputInfo, 'popObjs')
                continue;
            end

            popObjsCells = r.outputInfo.popObjs;
            popCVsCells = r.outputInfo.popCVs;

            for cIdx = 1:length(popObjsCells)
                popObjs = popObjsCells{cIdx};
                popCVs = popCVsCells{cIdx};

                if isempty(popObjs) || isempty(popCVs)
                    continue;
                end

                % Filter feasible solutions
                feasibleMask = (popCVs == 0);
                if ~any(feasibleMask)
                    continue;
                end

                feasibleObjs = popObjs(feasibleMask, :);

                % Update per-dimension maximum
                currentMax = max(feasibleObjs, [], 1);
                if isempty(maxObjs)
                    maxObjs = currentMax;
                else
                    maxObjs = max(maxObjs, currentMax);
                end
            end
        end
    end

    if isempty(maxObjs)
        return;
    end

    % Reference point = maximum * 1.1 (10% margin), as column vector
    refPoint = maxObjs(:) * 1.1;
end


function hvResults = computeAllHV(resultsDir, algorithms, refPoint)
% computeAllHV - Compute HV for all algorithm results.
%
% For each algorithm, loads results.mat from its subdirectory, computes HV
% for the last cycle of each trial using computeHVFromMatrices, and aggregates
% mean/std statistics.
%
% Returns a struct array, each element containing algoName, hvValues, meanHV, stdHV.

    hvResults = struct('algoName', {}, 'hvValues', {}, 'meanHV', {}, 'stdHV', {});

    for aIdx = 1:length(algorithms)
        algoName = algorithms{aIdx};
        resultsFile = fullfile(resultsDir, algoName, 'results.mat');

        entry.algoName = algoName;
        entry.hvValues = [];
        entry.meanHV = NaN;
        entry.stdHV = NaN;

        if ~isfile(resultsFile)
            hvResults(end+1) = entry; %#ok<AGROW>
            continue;
        end

        loaded = load(resultsFile);
        if ~isfield(loaded, 'results')
            hvResults(end+1) = entry; %#ok<AGROW>
            continue;
        end

        results = loaded.results;
        hvValues = [];

        for rIdx = 1:length(results)
            r = results{rIdx};
            if isempty(r) || ~isfield(r, 'feasible') || ~r.feasible
                hvValues(end+1) = -1; %#ok<AGROW>
                continue;
            end
            if ~isfield(r, 'outputInfo') || ~isfield(r.outputInfo, 'popObjs')
                hvValues(end+1) = -1; %#ok<AGROW>
                continue;
            end

            % Compute HV for the last cycle of this trial
            popObjsCells = r.outputInfo.popObjs;
            popCVsCells = r.outputInfo.popCVs;

            if isempty(popObjsCells)
                hvValues(end+1) = -1; %#ok<AGROW>
                continue;
            end

            % Use the last cycle's population
            lastObjs = popObjsCells{end};
            lastCVs = popCVsCells{end};

            hv = computeHVFromMatrices(lastObjs, lastCVs, refPoint);
            hvValues(end+1) = hv; %#ok<AGROW>
        end

        entry.hvValues = hvValues;
        validHV = hvValues(hvValues >= 0);
        if ~isempty(validHV)
            entry.meanHV = mean(validHV);
            entry.stdHV = std(validHV);
        end

        hvResults(end+1) = entry; %#ok<AGROW>
    end
end


function printSummary(~, hvResults)
% printSummary - Print HV summary table.
%
% Displays a formatted table with columns: Algorithm, Mean HV, Std HV.
% Shows "N/A" for algorithms with no valid HV values.

    fprintf('\n=== Benchmark Summary ===\n');
    fprintf('%-15s  %12s  %12s\n', 'Algorithm', 'Mean HV', 'Std HV');
    fprintf('%s\n', repmat('-', 1, 43));

    for aIdx = 1:length(hvResults)
        entry = hvResults(aIdx);
        if isnan(entry.meanHV)
            fprintf('%-15s  %12s  %12s\n', entry.algoName, 'N/A', 'N/A');
        else
            fprintf('%-15s  %12.6f  %12.6f\n', entry.algoName, entry.meanHV, entry.stdHV);
        end
    end

    fprintf('%s\n', repmat('-', 1, 43));
    fprintf('=========================\n');
end
