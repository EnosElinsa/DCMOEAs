function [pop, FT, state, responseMaxFES] = respondToChange(pop, config, state, problem, currentGenFES)
% respondToChange - Tribe-based dynamic response strategy for mEDCMOA.
% Steps: (1) generate random sub-population, (2) classify tribes,
% (3) fitness-based elite selection, (4) coordinate search,
% (5) velocity-based adjustment, (6) re-evaluate, (7) final tribe selection.
% Inputs:
% pop - Solution object array
% config - configuration struct (with .eachGenMaxFES, .responseFESRate, .popSize, .domain, .delta)
% state - mutable runtime state
% problem - UAVHAP handle
% currentGenFES - remaining FES for current environment
% Outputs:
% pop - updated Solution object array
% FT - feasible tribe Solution object array
% state - updated runtime state
% responseMaxFES - remaining FES budget after response

    popsize = config.algo.popSize;
    domain = config.domain;
    delta = config.delta;
    D = size(domain, 1);

    responseMaxFES = currentGenFES - config.eachGenMaxFES * (1 - config.responseFESRate);

    %% Generate random sub-population R
    nRandom = floor(0.5 * popsize);
    lower = domain(:,1)';
    upper = domain(:,2)';
    randomDecs = rand(nRandom, D) .* (upper - lower) + lower;
    randomPop = Solution.fromDecs(randomDecs);
    [randomPop, state] = evaluatePopulation(problem, randomPop, state);
    responseMaxFES = responseMaxFES - nRandom * 2 - popsize;

    %% Classify into tribes
    [FT, DIT, NIT, ~] = classifyTribes(pop, randomPop, Solution.empty());

    %% Compute fitness for each tribe
    fitnessFT = computeFitness(FT, 'Eqa6');
    fitnessDIT = computeFitness(DIT, 'Eqa6');
    fitnessNIT = computeFitness(NIT, 'Eqa5');

    %% Select top 10% + fitness==-Inf from each tribe for coordinate search
    [~, b] = sort(fitnessFT);
    fitnessFTIndex = b(1, 1:ceil(size(b, 2) * 0.1));
    fitnessFTNext = fitnessFT == -1;
    fitnessFTNext(1, fitnessFTIndex) = true;

    [~, b] = sort(fitnessDIT);
    fitnessDITIndex = b(1, 1:ceil(size(b, 2) * 0.1));
    fitnessDITNext = fitnessDIT == -1;
    fitnessDITNext(1, fitnessDITIndex) = true;

    [~, b] = sort(fitnessNIT);
    fitnessNITIndex = b(1, 1:ceil(size(b, 2) * 0.1));
    fitnessNITNext = fitnessNIT == -1;
    fitnessNITNext(1, fitnessNITIndex) = true;

    ftSearch = FT(fitnessFTNext);
    ditSearch = DIT(fitnessDITNext);
    nitSearch = NIT(fitnessNITNext);

    %% Coordinate search on selected elites
    [ftXiSet, state, responseMaxFES] = coordinateSearch(ftSearch, problem, state, domain, delta, responseMaxFES);
    [ditXiSet, state, responseMaxFES] = coordinateSearch(ditSearch, problem, state, domain, delta, responseMaxFES);
    [nitXiSet, state, responseMaxFES] = coordinateSearch(nitSearch, problem, state, domain, delta, responseMaxFES);

    %% Compute velocity vectors (with empty-set guards)
    if numel(ftXiSet) > 0 && numel(ftSearch) > 0
        ftXiDecs = ftXiSet.decs()';      % [D x nFtSearch]
        ftSearchDecs = ftSearch.decs()';
        diffFT = ftXiDecs - ftSearchDecs;
        velocityFT = sum(diffFT, 2) ./ max(1, sum(diffFT > -999, 2));
        velocityFT(isnan(velocityFT)) = 0;
    else
        velocityFT = zeros(D, 1);
    end

    if numel(ditXiSet) > 0 && numel(ditSearch) > 0
        ditXiDecs = ditXiSet.decs()';
        ditSearchDecs = ditSearch.decs()';
        diffDIT = ditXiDecs - ditSearchDecs;
        velocityDIT = sum(diffDIT, 2) ./ max(1, sum(diffDIT > -999, 2));
        velocityDIT(isnan(velocityDIT)) = 0;
    else
        velocityDIT = zeros(D, 1);
    end

    if numel(nitXiSet) > 0 && numel(nitSearch) > 0
        nitXiDecs = nitXiSet.decs()';
        nitSearchDecs = nitSearch.decs()';
        diffNIT = nitXiDecs - nitSearchDecs;
        velocityNIT = sum(diffNIT, 2) ./ max(1, sum(diffNIT > -999, 2));
        velocityNIT(isnan(velocityNIT)) = 0;
    else
        velocityNIT = zeros(D, 1);
    end

    %% Velocity-based adjustment for all tribe members
    FT = applyVelocity(FT, velocityFT, domain);
    DIT = applyVelocity(DIT, velocityDIT, domain);
    NIT = applyVelocity(NIT, velocityNIT, domain);

    %% Re-evaluate all tribes
    [FT, state] = evaluatePopulation(problem, FT, state);
    [DIT, state] = evaluatePopulation(problem, DIT, state);
    [NIT, state] = evaluatePopulation(problem, NIT, state);

    %% Merge and reclassify
    pop = [FT, DIT, NIT];
    [FT, DIT, NIT, ~] = classifyTribes(pop, Solution.empty(), Solution.empty());

    %% Final tribe-aware selection
    pop = selectPopulation(FT, DIT, NIT, popsize);
    responseMaxFES = responseMaxFES + config.eachGenMaxFES * (1 - config.responseFESRate);
end

function tribe = applyVelocity(tribe, velocity, domain)
% applyVelocity - Perturb tribe members by velocity with boundary repair.
    D = size(domain, 1);
    for i = 1:numel(tribe)
        for j = 1:D
            adjustedVal = tribe(i).dec(j) + velocity(j);
            if adjustedVal < domain(j, 1)
                adjustedVal = (domain(j, 1) - tribe(i).dec(j)) * rand() + tribe(i).dec(j);
            elseif adjustedVal > domain(j, 2)
                adjustedVal = (domain(j, 2) - tribe(i).dec(j)) * rand() + tribe(i).dec(j);
            end
            tribe(i).dec(j) = adjustedVal;
        end
    end
end
