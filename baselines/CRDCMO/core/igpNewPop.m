function offDec = igpNewPop(pop, domain)
% igpNewPop - IGP-based prediction of decisions for objective-anchored sampling.
% For each individual, samples a "desired"
% objective vector via a Gaussian centred at its current objectives and biased
% toward the ideal point, then uses per-dimension IGP regression to map the
% desired objectives back to a decision vector.
%
% Inputs:
%   pop    - Solution object array providing decs() and objs()
%   domain - [D x 2] decision variable bounds [lower, upper]
% Outputs:
%   offDec - [N x D] predicted decision matrix (out-of-bound entries replaced
%            by uniform-random samples; missing rows padded uniformly)

    sigmaJitter = 0.01;
    popObj = pop.objs();
    popDec = pop.decs();
    [N, ~] = size(popObj);
    idealP = min(popObj, [], 1);

    %% Sample "desired" objectives biased toward the ideal point
    popDesired = zeros(N, size(popObj, 2));
    for i = 1:N
        sigmaDiff = diag(abs(popObj(i, :) - idealP + sigmaJitter));
        popDesired(i, :) = mvnrnd(popObj(i, :), sigmaDiff);
    end

    nP = size(popDesired, 1);
    D = size(popDec, 2);

    %% Per-dimension IGP regression mapping objectives -> decision values
    offDec = zeros(nP, D);
    for d = 1:D
        [yMu, ~] = igp(popObj, popDec(:, d), popDesired, sigmaJitter);
        offDec(:, d) = yMu;
    end

    %% Replace out-of-bound entries with uniform-random fallback
    lower = repmat(domain(:, 1)', nP, 1);
    upper = repmat(domain(:, 2)', nP, 1);
    randDec = unifrnd(lower, upper);
    invalid = offDec < lower | offDec > upper;
    offDec(invalid) = randDec(invalid);

    %% Pad to N rows if needed
    restN = N - nP;
    if restN > 0
        lowerRest = repmat(domain(:, 1)', restN, 1);
        upperRest = repmat(domain(:, 2)', restN, 1);
        offDec(end+1:N, :) = unifrnd(lowerRest, upperRest);
    end
end
