[SUBJECT] = string(GetSubDirsFirstLevelOnly(pwd));

% dlgtitle = 'Input';
% dims = [1 35];

% for i = 1:length(x)
%     orig_name = x(i);
%     prompt = 'Enter new folder name for: '
%     prompt = strcat(prompt, orig_name);
%     answer = string(inputdlg(prompt, dlgtitle, dims));
%     movefile(orig_name, answer);
% end

% clear;

% loop for segment
ANALYSIS = 'Segmentation';
for i = 1:length(SUBJECT)
    subj_folder = SUBJECT(i);
    fname = "*.txt";
    subfolder = "/t1/raw/";
    target_dir = strcat(subj_folder, subfolder, fname);
    file_arr = dir(target_dir);
    if size(file_arr)>0
        file = file_arr(1).name;
        do_stuff(file);
    end
    completed = (i/length(SUBJECT))*100;
    disp([ANALYSIS ': Completed ' num2str(completed) '%']);
end

function [subDirsNames] = GetSubDirsFirstLevelOnly(parentDir)
    % Get a list of all files and folders in this folder.
    files = dir(parentDir);
    names = {files.name};
    % Get a logical vector that tells which is a directory.
    dirFlags = [files.isdir] & ~strcmp(names, '.') & ~strcmp(names, '..');
    % Extract only those that are directories.
    subDirsNames = names(dirFlags);
end

function do_stuff(file)
    disp("wooooo");
end
