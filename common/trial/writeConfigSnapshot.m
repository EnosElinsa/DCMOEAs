function snapshot = writeConfigSnapshot(resultsDir, config, metadata)
% writeConfigSnapshot - Persist experiment configuration and run metadata.
%
% Writes a single human-readable YAML file to resultsDir:
%   config_snapshot.yaml

    if nargin < 3
        metadata = struct();
    end
    if ~exist(resultsDir, 'dir')
        mkdir(resultsDir);
    end

    snapshot = struct();
    snapshot.createdAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    snapshot.config = config;
    snapshot.metadata = metadata;
    snapshot.source = getSourceInfo(metadata);

    yamlFile = fullfile(resultsDir, 'config_snapshot.yaml');
    yamlText = encodeYaml(snapshot);
    removeStaleSnapshot(fullfile(resultsDir, 'config_snapshot.mat'));
    removeStaleSnapshot(fullfile(resultsDir, 'config_snapshot.json'));

    fid = fopen(yamlFile, 'w');
    if fid < 0
        error('writeConfigSnapshot:openFailed', ...
            'Cannot open snapshot YAML for writing: %s', yamlFile);
    end
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, yamlText, 'char');
end

function removeStaleSnapshot(filename)
    if isfile(filename)
        delete(filename);
    end
end

function yamlText = encodeYaml(value)
    lines = valueToYaml(value, 0);
    yamlText = strjoin(lines, newline);
    yamlText = [yamlText, newline];
end

function lines = valueToYaml(value, indent)
    lines = {};

    if isstruct(value)
        if numel(value) == 1
            fields = fieldnames(value);
            for i = 1:numel(fields)
                field = fields{i};
                fieldValue = value.(field);
                lines = [lines, fieldToYaml(field, fieldValue, indent)]; %#ok<AGROW>
            end
        else
            for i = 1:numel(value)
                prefix = repmat(' ', 1, indent);
                lines{end+1} = sprintf('%s-', prefix); %#ok<AGROW>
                lines = [lines, valueToYaml(value(i), indent + 2)]; %#ok<AGROW>
            end
        end
        return;
    end

    if iscell(value)
        for i = 1:numel(value)
            prefix = repmat(' ', 1, indent);
            item = value{i};
            if isstruct(item) || iscell(item)
                lines{end+1} = sprintf('%s-', prefix); %#ok<AGROW>
                lines = [lines, valueToYaml(item, indent + 2)]; %#ok<AGROW>
            else
                lines{end+1} = sprintf('%s- %s', prefix, scalarToYaml(item)); %#ok<AGROW>
            end
        end
        return;
    end

    prefix = repmat(' ', 1, indent);
    lines{end+1} = sprintf('%s%s', prefix, scalarToYaml(value));
end

function lines = fieldToYaml(fieldName, value, indent)
    prefix = repmat(' ', 1, indent);
    if isstruct(value) || iscell(value)
        lines = {sprintf('%s%s:', prefix, fieldName)};
        lines = [lines, valueToYaml(value, indent + 2)];
    else
        lines = {sprintf('%s%s: %s', prefix, fieldName, scalarToYaml(value))};
    end
end

function text = scalarToYaml(value)
    if ischar(value) || (isstring(value) && isscalar(value))
        text = quoteYamlString(char(value));
    elseif isstring(value)
        text = inlineList(cellstr(value));
    elseif isnumeric(value)
        if isempty(value)
            text = '[]';
        elseif isscalar(value)
            text = num2str(value, 17);
        else
            text = inlineList(num2cell(value(:)'));
        end
    elseif islogical(value)
        if isscalar(value)
            text = lower(string(value));
            text = char(text);
        else
            text = inlineList(num2cell(value(:)'));
        end
    else
        text = quoteYamlString(evalc('disp(value)'));
    end
end

function text = inlineList(values)
    parts = cell(1, numel(values));
    for i = 1:numel(values)
        parts{i} = scalarToYaml(values{i});
    end
    text = ['[', strjoin(parts, ', '), ']'];
end

function text = quoteYamlString(value)
    if isempty(value)
        text = '""';
        return;
    end
    if ~isempty(regexp(value, '^[A-Za-z0-9_./-]+$', 'once'))
        text = value;
        return;
    end
    value = strrep(value, '\', '\\');
    value = strrep(value, '"', '\"');
    value = strrep(value, newline, '\n');
    text = ['"', value, '"'];
end

function source = getSourceInfo(metadata)
    source = struct('gitCommit', '', 'gitDirty', false, 'gitStatus', '');

    if isfield(metadata, 'repoDir') && ~isempty(metadata.repoDir)
        repoDir = metadata.repoDir;
    else
        repoDir = pwd;
    end

    oldDir = pwd;
    cleanup = onCleanup(@() cd(oldDir));
    try
        cd(repoDir);
        [commitCode, commitText] = system('git rev-parse HEAD');
        if commitCode == 0
            source.gitCommit = strtrim(commitText);
        end

        [statusCode, statusText] = system('git status --short');
        if statusCode == 0
            source.gitStatus = strtrim(statusText);
            source.gitDirty = ~isempty(source.gitStatus);
        end
    catch
        source.gitStatus = 'unavailable';
        source.gitDirty = false;
    end
end
