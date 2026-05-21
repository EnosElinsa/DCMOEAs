function offspring = sbxPm(parents, domain, op, mode)
% sbxPm - SBX crossover followed by polynomial mutation.
%   offspring = sbxPm(parents, domain, op, mode) applies simulated binary
%   crossover (SBX) to paired parents, then polynomial mutation to the
%   crossed offspring. Bundles sbxCrossover + polynomialMutation with the
%   shared operatorParams convention (per-bit probability = op.proM/D).
%
%   Inputs:
%       parents - [M x D] decision variable matrix. Rows 1:floor(M/2) are
%                 paired with rows floor(M/2)+1:2*floor(M/2).
%       domain  - [D x 2] or [2 x D] variable bounds [lower, upper].
%       op      - operatorParams struct with fields proC, disC, proM, disM.
%       mode    - (optional) 'full' (default) returns both offspring halves
%                 [2*half x D]; 'firstHalf' returns only the first half
%                 [half x D].
%   Outputs:
%       offspring - Mutated offspring decision variables.

    if nargin < 4 || isempty(mode), mode = 'full'; end

    [~, D] = size(parents);
    half = floor(size(parents, 1) / 2);
    p1 = parents(1:half, :);
    p2 = parents(half+1:2*half, :);

    %% Simulated binary crossover
    [off1, off2] = sbxCrossover(p1, p2, op.proC, op.disC);

    %% Select offspring based on mode
    switch mode
        case 'full'
            crossed = [off1; off2];
        case 'firstHalf'
            crossed = off1;
        otherwise
            error('sbxPm:invalidMode', ...
                'mode must be ''full'' or ''firstHalf'', got ''%s''', mode);
    end

    %% Polynomial mutation (rate form: per-bit probability = op.proM/D)
    offspring = polynomialMutation(crossed, domain, op.proM/D, op.disM);
end
