function file = find_files_for_python_engine(path, search)
    % this is a helper fcn to return a file name in the python matlab
    % engine as it cannot handle structs or cell arrays.
    % can be expanded to return a delimited string and then parse in python
    files = dir(fullfile(path, search));
    if length(files) > 1
        warning('Many files found in %s for the given search term %s\nSending files back as a comma-delimited string.', path, search);
        file = '';
        for idx = 1:length(files)
            file = fullfile(files(1).folder, strcat(file, files(idx).name, ','));
        end
    else
        file = fullfile(files(1).folder, files(1).name);
    end
end