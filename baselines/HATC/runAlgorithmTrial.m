function result = runAlgorithmTrial(config)
% HATC Baseline Trial Runner

    [problem, config, pop, state, controller, maxgen] = initTrial(config);

    problemIndex = config.run.problemIndex;
    maxGenPerEnv = config.algo.maxGenPerEnv;

    boundary.lower = problem.lower;
    boundary.upper = problem.upper;

    % HATC operator params
    op = struct('proC',1,'disC',20,'proM',1,'disM',20);

    %% Initialize Populations
    popSize = config.algo.popSize;
    uPop = pop;

    memoryArchive = {};
    prepop = {};
    preobj = {};
    
    pop1 = [];
    pop2 = [];
    matchedHistPop = [];

    while state.gen <= maxgen
        if mod(state.gen, maxGenPerEnv(problemIndex)) == 0 && state.gen ~= 0
            
            % Save memory for past environment
            memoryArchive{end+1} = pop;
            
            [~, noFeasible, isDone] = controller.stepEnvironment(problem, pop);
            if noFeasible || isDone
                break;
            end
            
            % Change Detection & Memory Retrieval
            envIdx = length(memoryArchive) + 1;
            
            if envIdx >= 3
                % Predict using CGLP
                prepop{envIdx} = cglpPre(memoryArchive, popSize, 1, boundary);
                preobj{envIdx} = cglpPreObj(problem, memoryArchive, popSize, 1);
            end
            
            if envIdx == 3
                % Nearest match based on naive distance (simplified)
                matchedHistPop = memoryArchive{1};
            elseif envIdx > 3
                % Nearest match based on prediction distance
                predObjHistory = preobj;
                currentPredObj = preobj{end};
                predObjDistance = inf(1, envIdx);
                for predEnvIdx = 3:envIdx-1
                    predObjDistance(predEnvIdx) = sum(min(pdist2(predObjHistory{predEnvIdx}, currentPredObj), [], 2));
                end
                [~, nearestPredEnvIdx] = min(predObjDistance);
                matchedHistPop = memoryArchive{nearestPredEnvIdx};
            else
                matchedHistPop = memoryArchive{end};
            end
            
            % Generate new population responding to change
            if envIdx >= 3
                dec = prepop{envIdx};
            else
                randDec = unifrnd(repmat(boundary.lower, round(0.2*popSize), 1), repmat(boundary.upper, round(0.2*popSize), 1));
                lastCP = memoryArchive{end}.decs();
                long = randperm(popSize);
                % hyperGA replica using shared operatorParams (keeps both offspring halves).
                parents = lastCP(long(round(0.2*popSize)+1:end), :);
                [off1, off2] = sbxCrossover(parents(1:end/2, :), parents(end/2+1:end, :), op.proC, op.disC);
                Dh = size(off1, 2);
                offDec1 = polynomialMutation([off1; off2], [boundary.lower', boundary.upper'], op.proM/Dh, op.disM);
                dec = [randDec; offDec1];
            end
            
            if size(unique(dec, 'rows'), 1) < popSize
                addDec = unifrnd(repmat(boundary.lower, popSize, 1), repmat(boundary.upper, popSize, 1));
                newDec = unique([dec; addDec], 'rows', 'stable');
                dec = newDec(1:popSize, :);
            end
            
            pop = decsToEvaluatedPop(dec, problem, state);
            uPop = pop;
            
            randN = randperm(popSize);
            pop1 = pop(randN(1:popSize/2));
            pop2 = pop(randN(popSize/2+1:end));
        end

        % Generational step
        if state.gen < maxGenPerEnv(problemIndex)
            % Single pop evolution (Environment 1)
            [~, frontNo, crowdDis] = nsgaiiSelection(pop, popSize);
            matingPool = tournamentSelection(2, popSize*2, frontNo, -crowdDis);
            % gaHalf replica using shared operatorParams (keeps only first offspring half).
            parents = pop(matingPool).decs();
            [off1, ~] = sbxCrossover(parents(1:end/2, :), parents(end/2+1:end, :), op.proC, op.disC);
            offDec = polynomialMutation(off1, [boundary.lower', boundary.upper'], op.proM/size(off1, 2), op.disM);
            offspring = decsToEvaluatedPop(offDec, problem, state);
            [pop, ~, ~] = nsgaiiSelection([pop, offspring], popSize);
            [uPop, ~, ~] = nsgaiiSelection([uPop, offspring], popSize, true);
        else
            % Dual pop evolution (Environment 2+)
            [~, frontNo1, crowdDis1] = nsgaiiSelection(pop1, popSize/2, true);
            matingPool1 = tournamentSelection(2, popSize, frontNo1, -crowdDis1);
            parents1 = pop1(matingPool1).decs();
            [off1_1, ~] = sbxCrossover(parents1(1:end/2, :), parents1(end/2+1:end, :), op.proC, op.disC);
            offDec1 = polynomialMutation(off1_1, [boundary.lower', boundary.upper'], op.proM/size(off1_1, 2), op.disM);
            offspring1 = decsToEvaluatedPop(offDec1, problem, state);

            [~, frontNo2, crowdDis2] = nsgaiiSelection(pop2, popSize/2);
            matingPool2 = tournamentSelection(2, popSize, frontNo2, -crowdDis2);
            % pop1 is used for matingPool2 decs (intentional design choice)
            parents2 = pop1(matingPool2).decs();
            [off1_2, ~] = sbxCrossover(parents2(1:end/2, :), parents2(end/2+1:end, :), op.proC, op.disC);
            offDec2 = polynomialMutation(off1_2, [boundary.lower', boundary.upper'], op.proM/size(off1_2, 2), op.disM);
            offspring2 = decsToEvaluatedPop(offDec2, problem, state);

            pop1 = diveHisSelection([pop1, offspring1, offspring2], matchedHistPop, 0, 0.05, popSize/2);
            pop2 = nsgaiiSelection([pop2, offspring1, offspring2], popSize/2);

            [pop, ~, ~] = nsgaiiSelection([pop, offspring1, offspring2], popSize);
            [uPop, ~, ~] = nsgaiiSelection([uPop, offspring1, offspring2], popSize, true);
        end

        if mod(state.gen, 50) == 0
            fprintf('    Gen=%d\n', state.gen);
        end
        state.gen = state.gen + 1;
    end

    controller.finalSelect(pop);
    result = controller.getResult();
end


