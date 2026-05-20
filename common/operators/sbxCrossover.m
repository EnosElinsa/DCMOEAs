function [off1, off2] = sbxCrossover(parent1, parent2, proC, disC)
% sbxCrossover - Simulated Binary Crossover for real-encoded variables.
%   [off1, off2] = sbxCrossover(parent1, parent2, proC, disC) applies SBX.
%   Inputs:
%       parent1 - [N/2 x D] decision variables for the first parent group.
%       parent2 - [N/2 x D] decision variables for the second parent group.
%       proC    - Probability of crossover occurring for a given parameter.
%       disC    - Distribution index (eta_c) for SBX.
%   Outputs:
%       off1    - [N/2 x D] first half of the generated offspring.
%       off2    - [N/2 x D] second half of the generated offspring.
%
%   Note: Both parents must have identical dimensions [N/2 x D].
    
    [N, D] = size(parent1);
    
    % Allocate beta spread distribution
    beta  = zeros(N, D);
    mu    = rand(N, D);
    
    % Apply standard SBX formula thresholding
    beta(mu <= 0.5) = (2 * mu(mu <= 0.5)).^(1 / (disC + 1));
    beta(mu > 0.5)  = (2 - 2 * mu(mu > 0.5)).^(-1 / (disC + 1));
    beta = beta .* (-1).^randi([0, 1], N, D);
    
    % Probability logic: do not cross over parameters based on proC
    beta(rand(N, D) < 0.5) = 1;
    beta(repmat(rand(N, 1) > proC, 1, D)) = 1;
    
    % Generate the two symmetric offspring
    off1 = (parent1 + parent2) / 2 + beta .* (parent1 - parent2) / 2;
    off2 = (parent1 + parent2) / 2 - beta .* (parent1 - parent2) / 2;
end
