function [searchSet, state, responseMaxFES] = coordinateSearch(searchSet, problem, state, domain, delta, responseMaxFES)
% coordinateSearch - Coordinate-wise local search for mEDCMOA response.
% Adjusts each solution dimension-by-dimension using delta step size.
% Inputs:
% searchSet - Solution object array to search-improve
% problem - DynamicProblem instance
% state - mutable runtime state
% domain - [D x 2] variable bounds
% delta - [D x 1] step sizes per dimension
% responseMaxFES - remaining FES budget for response
% Outputs:
% searchSet - improved Solution object array
% state - updated runtime state
% responseMaxFES - updated remaining FES budget

    D = size(domain, 1);
    for i = 1:numel(searchSet)
        x = searchSet(i).dec;  % [1 x D]
        for j = 1:D
            flag = 0;
            while flag < 2
                y = x;
                if flag == 0
                    y(j) = y(j) + delta(j);
                else
                    y(j) = y(j) - delta(j);
                end

                if y(j) <= domain(j, 2) && y(j) >= domain(j, 1)
                    if responseMaxFES <= 0
                        return;
                    end
                    tempSol = Solution();
                    tempSol.dec = y;
                    [tempSol, state] = evaluatePopulation(problem, tempSol, state);
                    responseMaxFES = responseMaxFES - 1;

                    if searchSet(i).cv == 0
                        if tempSol.cv == 0 && checkDominance(tempSol.obj, tempSol.cv, searchSet(i).obj, searchSet(i).cv) == 1
                            x = y;
                            searchSet(i) = tempSol;
                        else
                            flag = flag + 1;
                        end
                    else
                        if tempSol.cv < searchSet(i).cv || (tempSol.cv == 0 && all(tempSol.obj < searchSet(i).obj))
                            x = y;
                            searchSet(i) = tempSol;
                        else
                            flag = flag + 1;
                        end
                    end
                else
                    flag = flag + 1;
                end
            end
        end
    end
end
