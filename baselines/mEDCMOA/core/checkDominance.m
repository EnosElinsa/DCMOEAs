function flag = checkDominance(f1, cv1, f2, cv2)
% checkDominance - Check dominance relation between two individuals.
% Inputs:
% f1, f2 - objective vectors
% cv1, cv2 - constraint violation values
% Outputs:
% flag - 1 if f1 dominates f2, -1 if f2 dominates f1, 0 otherwise

    if cv1 == 0 && cv2 == 0
        if all(f1 <= f2) && any(f1 < f2)
            flag = 1;
        elseif all(f2 <= f1) && any(f2 < f1)
            flag = -1;
        else
            flag = 0;
        end
    elseif cv1 == 0 && cv2 > 0
        flag = 1;
    elseif cv1 > 0 && cv2 == 0
        flag = -1;
    else
        if cv1 < cv2
            flag = 1;
        elseif cv1 > cv2
            flag = -1;
        else
            flag = 0;
        end
    end
end
