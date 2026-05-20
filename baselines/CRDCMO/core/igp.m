function [muPred, sigmaPred] = igp(xTrain, yTrain, xTest, noiseVar)
% igp - Linear-kernel Gaussian Process regression with Cholesky factorization.
% Single-output regression that maps
% objective-space anchor points (xTrain) to one decision dimension (yTrain),
% then predicts the decision value at desired objective points (xTest).
%
% Inputs:
%   xTrain   - [N x M] training inputs (population objectives)
%   yTrain   - [N x 1] training outputs (one decision dimension)
%   xTest    - [P x M] test inputs (desired/sampled objectives)
%   noiseVar - scalar measurement noise standard deviation
% Outputs:
%   muPred    - [P x 1] predictive mean at xTest
%   sigmaPred - [P x P] predictive covariance at xTest

    linearKernel = @(x1, x2) x1 * x2';

    K = linearKernel(xTrain, xTrain);
    K = K + noiseVar^2 * eye(size(xTrain, 1));

    Kstar = linearKernel(xTrain, xTest);
    KstarStar = linearKernel(xTest, xTest);

    n = size(K, 1);
    epsilon = 1e-3;
    K = K + epsilon * eye(n);

    L = chol(K, 'lower');
    alpha = L' \ (L \ yTrain);

    muPred = Kstar' * alpha;
    v = L \ Kstar;
    sigmaPred = KstarStar - v' * v;
end
