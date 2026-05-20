function result = runAlgorithmTrial(config)
    % DCNSGAII_B uses respondToChangeDCB (polynomial mutation) instead of
    % respondToChange (random replacement).

    [problem, config, pop, state, controller, maxgen] = initTrial(config);
    maxGenPerEnv = config.algo.maxGenPerEnv;
    problemIndex = config.run.problemIndex;

    while state.gen <= maxgen
        if mod(state.gen, maxGenPerEnv(problemIndex)) == 0 && state.gen ~= 0
            [~, noFeasible, isDone] = controller.stepEnvironment(problem, pop);
            if noFeasible || isDone
                break;
            end

            % DNSGA-II-B: mutation-based response
            [pop, state] = respondToChangeDCB(config, state, problem, pop);
        end

        [pop, state] = evolve(config, state, problem, pop);

        if mod(state.gen, 50) == 0
            fprintf('    Gen=%d\n', state.gen);
        end
        state.gen = state.gen + 1;
    end

    controller.finalSelect(pop);
    result = controller.getResult();
end
