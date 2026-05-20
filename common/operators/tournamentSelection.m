function index = tournamentSelection(K, N, varargin)
% tournamentSelection - Tournament selection.
% P = tournamentSelection(K,N,fitness1,fitness2,...) returns the indices
% of N solutions by K-tournament selection based on their fitness values.
% In each selection, the candidate having the minimum fitness1 value will
% be selected; if multiple candidates have the same minimum value of
% fitness1, then the one with the smallest fitness2 value is selected,
% and so on.
% Example:
% P = tournamentSelection(2, 100, frontNo)

    varargin    = cellfun(@(S)reshape(S,[],1),varargin,'UniformOutput',false);
    [fit,~,loc] = unique([varargin{:}],'rows');
    [~,rank]    = sortrows(fit);
    [~,rank]    = sort(rank);
    parents     = randi(length(varargin{1}),K,N);
    [~,best]    = min(rank(loc(parents)),[],1);
    index       = parents(best+(0:N-1)*K);
end
