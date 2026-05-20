function [val, idx] = medianIdx(x)
% medianIdx - Return the value and index of the median element.
% Uses ceil mid-index convention so all callers (saveVisualization,
% printSummaryTables, plotHVCurve) reference the same run.
%
% Inputs:
%   x   - numeric vector
% Outputs:
%   val - median element value
%   idx - index of the median element in the original vector

    [sorted, order] = sort(x);
    midIdx = ceil(length(x) / 2);
    val = sorted(midIdx);
    idx = order(midIdx);
end
