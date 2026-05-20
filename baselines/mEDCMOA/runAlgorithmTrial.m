function result = runAlgorithmTrial(config)
    [problem, config, pop, state, controller, maxgen] = initTrial(config);
    maxGenPerEnv = config.algo.maxGenPerEnv;
    problemIndex = config.run.problemIndex;
    maxFESTable  = [900000000, 152000];

    config.delta = getSearchDelta(config.domain);
    config.responseFESRate = 0.7;
    config.algo.preEvolution = 80;
    changeTimes = 60;
    config.eachGenMaxFES = floor( ...
        (maxFESTable(1, 1) - config.algo.preEvolution * config.algo.popSize) / changeTimes);
    operatorParams = struct('proC',0.8,'disC',5,'proM',0.05,'disM',40);

    currentGenFES = Inf;

    while state.gen <= maxgen
        if mod(state.gen, maxGenPerEnv(problemIndex)) == 0 && state.gen ~= 0
            [~, noFeasible, isDone] = controller.stepEnvironment(problem, pop);
            if noFeasible || isDone
                break;
            end

            currentGenFES = config.eachGenMaxFES;

            % Re-evaluate after environment change
            [pop, state] = evaluatePopulation(problem, pop, state);
            currentGenFES = currentGenFES - numel(pop);

            % Tribe-based change response
            [pop, FT, state, currentGenFES] = respondToChange(pop, config, state, problem, currentGenFES);
            updateNondominatedSet(FT, Solution.empty(), config.algo.popSize);
        end

        if currentGenFES > 0
            popParent = selectMatingPool(pop);
            offspringDecs = operatorGA(pop.decs(), popParent', config.domain, operatorParams);

            offspring = Solution.fromDecs(offspringDecs);
            [offspring, state] = evaluatePopulation(problem, offspring, state);
            currentGenFES = currentGenFES - size(offspringDecs, 1);

            [FT, DIT, NIT, ~] = classifyTribes(pop, offspring, Solution.empty());
            pop = selectPopulation(FT, DIT, NIT, config.algo.popSize);
        end

        if mod(state.gen, 100) == 0
            fprintf('    Gen=%d\n', state.gen);
        end
        state.gen = state.gen + 1;
    end

    controller.finalSelect(pop);
    result = controller.getResult();
end

