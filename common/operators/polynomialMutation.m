function mutatedDecs = polynomialMutation(popDecs, domain, proM, disM)
% polynomialMutation - Applies Polynomial Mutation (PM) mapping.
%   mutatedDecs = polynomialMutation(popDecs, domain, proM, disM)
%   Inputs:
%       popDecs - [N x D] decision variable matrix to be mutated.
%       domain  - [D x 2] or [2 x D] bounds. [Lower, Upper].
%       proM    - Mutation probability (applied externally per parameter).
%       disM    - Distribution index (eta_m) for PM mapping.
%   Outputs:
%       mutatedDecs - [N x D] decision variables post-mutation.
    
    [N, D] = size(popDecs);
    
    % Ensure domain mapping aligns to [N x D] bounding matrices
    if size(domain, 1) == 2 && size(domain, 2) == D
        % Domain is [2 x D], transpose to align with repmat dimensions
        domainLower = domain(1, :)';
        domainUpper = domain(2, :)';
    else
        domainLower = domain(:, 1);
        domainUpper = domain(:, 2);
    end
    
    lowerBound = repmat(domainLower', N, 1);
    upperBound = repmat(domainUpper', N, 1);
    
    % Identify mutation loci
    site  = rand(N, D) < proM;
    mu    = rand(N, D);
    
    % Clip out-of-bounds individuals before mutation to ensure ratio stability
    mutatedDecs = min(max(popDecs, lowerBound), upperBound);
    
    %% Small Mutation Range Logic (mu <= 0.5)
    mutateSmall = site & mu <= 0.5;
    
    % Calculate the scaled delta fraction for boundaries
    rangeDivSmall = (mutatedDecs(mutateSmall) - lowerBound(mutateSmall)) ./ ...
                    (upperBound(mutateSmall) - lowerBound(mutateSmall));
                
    mappedDeltasSmall = (2 .* mu(mutateSmall) + (1 - 2 .* mu(mutateSmall)) .* ...
                        (1 - rangeDivSmall).^(disM + 1)).^(1 / (disM + 1)) - 1;
                    
    mutatedDecs(mutateSmall) = mutatedDecs(mutateSmall) + ...
        (upperBound(mutateSmall) - lowerBound(mutateSmall)) .* mappedDeltasSmall;
        
    %% Large Mutation Range Logic (mu > 0.5)
    mutateLarge = site & mu > 0.5;
    
    rangeDivLarge = (upperBound(mutateLarge) - mutatedDecs(mutateLarge)) ./ ...
                    (upperBound(mutateLarge) - lowerBound(mutateLarge));
                
    mappedDeltasLarge = 1 - (2 .* (1 - mu(mutateLarge)) + 2 .* (mu(mutateLarge) - 0.5) .* ...
                        (1 - rangeDivLarge).^(disM + 1)).^(1 / (disM + 1));
                    
    mutatedDecs(mutateLarge) = mutatedDecs(mutateLarge) + ...
        (upperBound(mutateLarge) - lowerBound(mutateLarge)) .* mappedDeltasLarge;
        
    % Post-mutation clipping fallback
    mutatedDecs(mutatedDecs < lowerBound) = lowerBound(mutatedDecs < lowerBound);
    mutatedDecs(mutatedDecs > upperBound) = upperBound(mutatedDecs > upperBound);
end
