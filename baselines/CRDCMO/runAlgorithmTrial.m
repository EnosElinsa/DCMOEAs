function result = runAlgorithmTrial(config)
% runAlgorithmTrial - CRDCMO baseline trial entry point.

    [problem, config, pop, state, controller, ~] = initTrial(config);
    problemIndex = config.run.problemIndex;
    config.maxGenPerEnv = config.algo.maxGenPerEnv(problemIndex);
    pop1 = pop;
    pop2 = pop;

    [pop1, pop2, problem, noFeasibleFlag, state] = ...
        crdcmoAlgorithm(config, state, problem, pop1, pop2, controller);

    controller.finalSelect(pop1);
    result = controller.getResult();
end
