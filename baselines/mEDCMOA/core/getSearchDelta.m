function delta = getSearchDelta(domain)
% getSearchDelta - Per-variable search step sizes for coordinate search (mEDCMOA).
%
% Inputs:
%   domain - [D x 2] decision variable bounds
%
% Outputs:
%   delta - [D x 1] step size vector for each decision variable

    D = size(domain, 1);

    % Check if domain matches UAVHAP layout (D = 2 + 4*I, I integer)
    I = (D - 2) / 4;
    if I == floor(I) && I >= 1
        % UAVHAP-specific step sizes
        delta = ones(D, 1);
        delta(1) = 50;              % HAP x
        delta(2) = 50;              % HAP y
        % sigma: delta=1 (default)
        % hover positions: moderate step
        delta(2+I+1:2+3*I) = 50;   % hover x,y
        % bandwidth: proportional to total (upper bound of bw variable = bTotal,
        % expressed in MHz, so a 10% step is O(1) MHz).
        bMax = domain(2+3*I+1, 2);
        if bMax > 0
            delta(2+3*I+1:2+4*I) = bMax / 10;
        else
            delta(2+3*I+1:2+4*I) = 1;   % 1 MHz fallback
        end
    else
        % Generic problem: use 10% of variable range as step size
        ranges = domain(:, 2) - domain(:, 1);
        delta = max(ranges / 10, 1e-6);
    end
end
