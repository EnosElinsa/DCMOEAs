classdef TrialLogger < handle
% TrialLogger - Pure recording class for trial snapshots.
% Records population data (as plain matrices), problem snapshots, and
% decision/objective history. HV is computed post-hoc after all trials
% complete, once the reference point is determined from actual data.
%
% All execution control is handled by TrialController.

    properties
        noFeasibleFlag
        outputSave
    end

    methods
        function obj = TrialLogger(problem)
            obj.noFeasibleFlag = false;

            obj.outputSave = struct();
            obj.outputSave.problemSnapshots = {problem.toStruct()};
            obj.outputSave.popObjs = {};    % {cycle} -> [N x M]
            obj.outputSave.popCVs  = {};    % {cycle} -> [N x 1]
            obj.outputSave.bestDecs = [];   % [D x nCycles]
            obj.outputSave.bestObjs = [];   % [M x nCycles]
            obj.outputSave.cycleInfos = {}; % problem-specific diagnostic information
        end

        function markNoFeasible(obj)
        % markNoFeasible - Flag that the trial ended with no feasible solution.
            obj.noFeasibleFlag = true;
        end

        function recordStep(obj, problem, bestSol, pop, info)
        % recordStep - Save problem snapshot, decision, objectives, population
        % data, and cycle diagnostic info as plain matrices.
            obj.outputSave.problemSnapshots{end+1} = problem.toStruct();
            obj.outputSave.bestDecs(:, end+1) = bestSol.dec(:);
            obj.outputSave.bestObjs(:, end+1) = bestSol.obj(:);
            obj.outputSave.popObjs{end+1} = pop.objs();
            obj.outputSave.popCVs{end+1}  = pop.cvs();
            obj.outputSave.cycleInfos{end+1} = info;
        end

        function recordFinalSelect(obj, bestSol, pop)
        % recordFinalSelect - Record the final selected solution.
            obj.outputSave.bestDecs(:, end+1) = bestSol.dec(:);
            obj.outputSave.bestObjs(:, end+1) = bestSol.obj(:);
            obj.outputSave.popObjs{end+1} = pop.objs();
            obj.outputSave.popCVs{end+1}  = pop.cvs();
        end

        function result = getResult(obj)
        % getResult - Package recorded data into standardized result struct.
            result.feasible   = ~obj.noFeasibleFlag;
            result.outputInfo = obj.outputSave;
        end
    end
end
