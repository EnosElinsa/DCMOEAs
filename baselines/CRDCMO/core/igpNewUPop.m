function offDec = igpNewUPop(currentPop, prevPop, domain, NP)
% igpNewUPop - Centroid-shift diversity compensation for the unconstrained
% archive in CRDCMO's TDC change response.
% Samples NP individuals from the current
% population and perturbs their decisions along the centroid-shift vector
% between the previous and current environment populations; reflects out-of-
% bound entries back into the feasible domain. Falls back to uniform-random
% sampling when no previous-environment population is available.
%
% Inputs:
%   currentPop - Solution object array (current environment pop)
%   prevPop    - Solution object array (previous environment pop, may be empty)
%   domain     - [D x 2] decision variable bounds
%   NP         - target number of decisions to generate
% Outputs:
%   offDec     - [NP x D] decision matrix

    decs = currentPop.decs();
    N = size(decs, 1);
    sampledDec = decs(randi(N, NP, 1), :);

    if ~isempty(prevPop)
        cenPrev = mean(prevPop.decs(), 1);
        cenCurr = mean(decs, 1);
        interval = cenCurr - cenPrev;

        lower = repmat(domain(:, 1)', NP, 1);
        upper = repmat(domain(:, 2)', NP, 1);

        sampledDec = sampledDec + unifrnd( ...
            repmat(min(interval, 0), NP, 1), ...
            repmat(max(interval, 0), NP, 1));

        % Reflective bound repair
        sampledDec(sampledDec < lower) = 2 * lower(sampledDec < lower) - sampledDec(sampledDec < lower);
        sampledDec(sampledDec > upper) = 2 * upper(sampledDec > upper) - sampledDec(sampledDec > upper);

        % Final clamp in case reflection still left some entries OOB.
        sampledDec = min(max(sampledDec, lower), upper);

        offDec = sampledDec;
    else
        lower = repmat(domain(:, 1)', NP, 1);
        upper = repmat(domain(:, 2)', NP, 1);
        offDec = unifrnd(lower, upper);
    end
end
