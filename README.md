# DCMOEAs — Dynamic Constrained Multi-Objective Evolutionary Algorithms

A MATLAB benchmark framework for evaluating evolutionary algorithms on dynamic constrained multi-objective optimization problems (DCMOPs).

## Features

- **6 baseline algorithms**: CRDCMO, DCNSGAII_A, DCNSGAII_B, HATC, mEDCMOA, TDCEA
- **Modular architecture**: shared operators, population utilities, and metrics in `common/`
- **Dynamic environment support**: automatic environment switching with configurable change frequency
- **Hypervolume-based evaluation**: post-processing computes per-trial HV with global reference point
- **Parallel execution**: optional `parfor`-based multi-run parallelism
- **Extensible**: add new algorithms by implementing `runAlgorithmTrial.m`, new problems by subclassing `DynamicProblem`

## Project Structure

```
DCMOEAs/
├── runBenchmark.m              # Top-level entry point
├── common/
│   ├── Solution.m              # Individual representation class
│   ├── DynamicProblem.m        # Abstract base class for problems
│   ├── createConfig.m          # Configuration factory
│   ├── operators/              # Shared evolutionary operators
│   │   ├── evolve.m            # NSGA-II SBX+PM evolution step
│   │   ├── calFitness.m        # SPEA2 fitness assignment
│   │   ├── ndSort.m            # Efficient non-dominated sorting
│   │   ├── nsgaiiSelection.m   # NSGA-II environmental selection
│   │   ├── spea2Selection.m    # SPEA2 environmental selection
│   │   ├── sbxCrossover.m      # Simulated binary crossover
│   │   ├── polynomialMutation.m# Polynomial mutation
│   │   ├── operatorDE.m        # Differential evolution operator
│   │   ├── operatorGA.m        # GA crossover + mutation wrapper
│   │   └── tournamentSelection.m
│   ├── population/             # Population initialization & evaluation
│   ├── metrics/                # HV computation & result analysis
│   └── trial/                  # Trial lifecycle management
├── baselines/
│   ├── CRDCMO/                 # Constraint-relaxation dual-population CMO
│   ├── DCNSGAII_A/             # Dynamic NSGA-II variant A (random replacement)
│   ├── DCNSGAII_B/             # Dynamic NSGA-II variant B (mutation response)
│   ├── HATC/                   # History-Assisted Temporal Correlation
│   ├── mEDCMOA/                # Modified evolutionary DCMO algorithm
│   └── TDCEA/                  # Two-population DE coevolution
├── examples/
│   ├── runExample.m            # Quick-start example script
│   └── DCDTLZ/                 # DC-DTLZ benchmark problems
└── results/                    # Output directory for benchmark results
```

## Quick Start

```matlab
% 1. Open MATLAB and navigate to the project root
cd path/to/DCMOEAs

% 2. Run the example (DC-DTLZ1 with DCNSGAII_A, 5 runs)
run('examples/runExample.m')
```

## Running a Full Benchmark

```matlab
% Run all 6 algorithms on a custom problem
runBenchmark(@myProblemFactory, ...
    'algo.popSize', 100, ...
    'algo.maxGenPerEnv', 50, ...
    'run.numRuns', 30, ...
    'run.numWorkers', 4, ...
    'algorithms', {'CRDCMO','TDCEA','mEDCMOA','DCNSGAII_A','DCNSGAII_B','HATC'}, ...
    'resultsDir', './results/my_experiment');
```

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `algo.popSize` | 100 | Population size |
| `algo.maxGenPerEnv` | 50 | Generations per dynamic environment |
| `algo.replacementRate` | 0.2 | Fraction replaced on environment change |
| `run.numRuns` | 30 | Independent runs per algorithm |
| `run.numWorkers` | 0 | Parallel workers (0 = serial) |
| `run.seedBase` | 200 | Base seed for reproducibility |

## Adding a New Algorithm

1. Create `baselines/MyAlgo/runAlgorithmTrial.m`:

```matlab
function result = runAlgorithmTrial(config)
    [problem, config, pop, state, controller, maxgen] = initTrial(config);
    
    while state.gen <= maxgen
        % Your evolution logic here
        % Use shared operators: evolve(), evaluatePopulation(), nsgaiiSelection(), etc.
        state.gen = state.gen + 1;
    end
    
    controller.finalSelect(pop);
    result = controller.getResult();
end
```

2. Run it:
```matlab
runBenchmark(@myProblemFactory, 'algorithms', {'MyAlgo'});
```

## Adding a New Problem

Subclass `DynamicProblem` and implement the required methods:

```matlab
classdef MyProblem < DynamicProblem
    methods
        function initialize(obj, config)
            obj.nObj = 2;
            obj.nCon = 1;
            obj.nVar = 10;
            obj.lower = zeros(1, obj.nVar);
            obj.upper = ones(1, obj.nVar);
            obj.tMax = 10;
        end
        
        function [popObj, popCon, popDec] = calObj(obj, popDec)
            % Compute objectives and constraints
        end
        
        function updateEnvironment(obj)
            obj.currentT = obj.currentT + 1;
        end
    end
end
```

## Requirements

- MATLAB R2020b or later
- Statistics and Machine Learning Toolbox (for `pdist2`)
- Parallel Computing Toolbox (optional, for `run.numWorkers > 0`)
- Pre-compiled Hypervolume MEX binary (included for Windows x64)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
