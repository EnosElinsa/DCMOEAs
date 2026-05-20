classdef Solution
% Solution - Individual-level solution class.
% Each Solution object represents a single individual in the population.
% A population is a Solution object array: pop(i).dec accesses individual i.
% Bulk access uses pop.decs() -> [N x D] matrix.
% Properties:
% dec - [1 x D] decision variables for this individual
% obj - [1 x M] objective values
% con - [1 x K] raw constraint values
% cv - scalar, summed constraint violation
% add - [1 x ?] additional info (optional)

    properties
        dec   % [1 x D] decision variables for this individual
        obj   % [1 x M] objective values
        con   % [1 x K] raw constraint values
        cv    % scalar  summed constraint violation
        add   % [1 x ?] additional info (optional)
    end

    methods
        function d = decs(pop)
            % decs - Get decision variables of all individuals as [N x D] matrix.
            if numel(pop) == 0
                d = [];
            else
                d = cat(1, pop.dec);
            end
        end

        function o = objs(pop)
            % objs - Get objective values of all individuals as [N x M] matrix.
            if numel(pop) == 0
                o = [];
            else
                o = cat(1, pop.obj);
            end
        end

        function c = cons(pop)
            % cons - Get constraint values of all individuals as [N x K] matrix.
            if numel(pop) == 0
                c = [];
            else
                c = cat(1, pop.con);
            end
        end

        function v = cvs(pop)
            % cvs - Get constraint violation scalars as [N x 1] vector.
            if numel(pop) == 0
                v = [];
            else
                v = [pop.cv]';
            end
        end
    end

    methods (Static)
        function pop = fromDecs(decMatrix)
            % fromDecs - Create Solution array from decision matrix.
            %
            % Input:
            %   decMatrix - [N x D] decision variable matrix (row-per-individual)
            %
            % Output:
            %   pop - [1 x N] Solution object array with .dec populated
            %         (.obj, .con, .cv, .add are left as empty [])

            % Validate input is a 2-D numeric matrix
            if ~isnumeric(decMatrix) || ~ismatrix(decMatrix)
                error('Solution:fromDecs:invalidInput', ...
                    'Input must be a 2-D numeric matrix.');
            end

            N = size(decMatrix, 1);

            % Handle empty matrix (0 rows)
            if N == 0
                pop = Solution.empty();
                return;
            end

            % Preallocate Solution array and assign each row to .dec
            pop = repmat(Solution(), 1, N);
            for i = 1:N
                pop(i).dec = decMatrix(i,:);
            end
        end
    end
end
