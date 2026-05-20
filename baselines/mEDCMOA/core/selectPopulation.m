function NP = selectPopulation(FT, DIT, NIT, N)
% selectPopulation - Tribe-aware population selection for mEDCMOA.
% Refactored from mEDCMOA/populationSelection.m.
% Priority: FT first, then NIT, then DIT.
% Inputs:
% FT, DIT, NIT - Solution object arrays for each tribe
% N - target population size
% Outputs:
% NP - Solution object array of size N

    nFT = numel(FT);
    if nFT < N
        NP = FT;
        nNIT = numel(NIT);
        remaining = N - nFT;
        if nNIT > remaining
            fitnessNIT = computeFitness(NIT, 'Eqa5');
            selectedNIT = selectElites(NIT, fitnessNIT, remaining);
            NP = [NP, selectedNIT];
        elseif nNIT == remaining
            NP = [NP, NIT];
        else
            NP = [NP, NIT];
            fitnessDIT = computeFitness(DIT, 'Eqa6');
            required = N - numel(NP);
            selectedDIT = selectElites(DIT, fitnessDIT, required);
            NP = [NP, selectedDIT];
        end
    elseif nFT == N
        NP = FT;
    else
        fitnessFT = computeFitness(FT, 'Eqa6');
        NP = selectElites(FT, fitnessFT, N);
    end
end
