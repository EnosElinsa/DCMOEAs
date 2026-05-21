# DCMOEAs — Dynamic Constrained Multi-Objective Evolutionary Algorithms

A MATLAB benchmark framework for evaluating evolutionary algorithms on dynamic constrained multi-objective optimization problems (DCMOPs).

## Features

- **6 baseline algorithms**: CRDCMO, DCNSGAII_A, DCNSGAII_B, HATC, mEDCMOA, TDCEA
- **Modular architecture**: shared operators, population utilities, and metrics in `common/`
- **Dynamic environment support**: automatic environment switching with configurable change frequency
- **Hypervolume-based evaluation**: post-processing computes per-trial HV with global reference point
- **Parallel execution**: optional `parfor`-based multi-run parallelism
- **Extensible**: add new algorithms by subclassing `TrialDriver` with a 2-line `runAlgorithmTrial.m` wrapper, new problems by subclassing `DynamicProblem`

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
│   │   ├── sbxCrossover.m      # Simulated binary crossover (primitive)
│   │   ├── deCrossover.m       # DE rand/1 + binomial crossover (primitive)
│   │   ├── polynomialMutation.m# Polynomial mutation (primitive)
│   │   ├── sbxPm.m            # SBX + PM bundle (replaces operatorGA)
│   │   ├── dePm.m             # DE-crossover + PM bundle (replaces operatorDE)
│   │   └── tournamentSelection.m
│   ├── population/             # Population initialization & evaluation
│   ├── metrics/                # HV computation & result analysis
│   └── trial/                  # Trial lifecycle management
│       └── TrialDriver.m      # Abstract base class for algorithm drivers
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
| `run.numRuns` | 30 | Independent runs per algorithm |
| `run.numWorkers` | 0 | Parallel workers (0 = serial) |
| `run.seedBase` | 200 | Base seed for reproducibility |

## Adding a New Algorithm

New algorithms are added by subclassing `TrialDriver` — an abstract base class that owns the trial loop (initialization, generation advancement, change-point detection, and termination). You implement four methods that define your algorithm's behavior, and the framework handles the rest.

### 1. Create a `TrialDriver` subclass

Create `baselines/MyAlgo/MyAlgoDriver.m` with the 5-method skeleton (constructor + 4 abstract methods):

```matlab
classdef MyAlgoDriver < TrialDriver
    properties (Access = private)
        pop             % Algorithm-private population state
        operatorParams  % Variation operator parameters
    end

    methods
        function obj = MyAlgoDriver(config)
            obj@TrialDriver(config);
        end
    end

    methods (Access = protected)
        function initialize(this)
            % Called once after initTrial. Stash the initial population
            % and set up any algorithm-specific state.
            this.pop = this.initialPop;
            this.operatorParams = struct('proC',1,'disC',20,'proM',1,'disM',20);
        end

        function evolveStep(this)
            % One generation of variation + selection.
            % Mutate this.pop and this.state in place (handle semantics).
            [this.pop, this.state] = evolve(this.config, this.state, ...
                this.problem, this.pop, this.operatorParams);
        end

        function respondToChange(this)
            % React to an environment change. Called after stepEnvironment
            % returns false (trial continues). Refresh population as needed.
            % Example: random replacement, prediction, re-initialization, etc.
        end

        function pop = currentPop(this)
            % Return the current population for controller use
            % (feasibility checks, best-solution selection).
            pop = this.pop;
        end
    end
end
```

### 2. Create the 2-line `runAlgorithmTrial.m` wrapper

Create `baselines/MyAlgo/runAlgorithmTrial.m`:

```matlab
function result = runAlgorithmTrial(config)
    driver = MyAlgoDriver(config);
    result = driver.run();
end
```

This wrapper preserves the per-baseline entry-point contract that `runBenchmark` and `runTrialBatch` expect.

### 3. Run it

```matlab
runBenchmark(@myProblemFactory, 'algorithms', {'MyAlgo'});
```

### Method reference

| Method | Purpose |
|--------|---------|
| `initialize(this)` | Set up algorithm state from `this.initialPop`. Called once. |
| `evolveStep(this)` | One generation: variation → evaluation → selection. Mutates `this.state`. |
| `respondToChange(this)` | Handle environment change (re-init, predict, adapt). |
| `currentPop(this)` | Return the population used for feasibility/termination decisions. |

### Notes

- The base class provides `this.config`, `this.problem`, `this.controller`, `this.state`, `this.maxgen`, and `this.initialPop` as protected properties — use them freely in your subclass.
- `evolveStep` and `respondToChange` mutate state in place via handle semantics. They take no arguments and return nothing.
- For multi-population algorithms, `currentPop` returns whichever population the controller should use for feasibility-based decisions (e.g., `pop1` for dual-population designs).
- Each baseline owns its `operatorParams` struct inline with literature attribution — these are algorithm characteristics, not framework configuration.

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
