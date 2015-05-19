function sortRawDataFiles(varargin)
% SORTRAWDATAFILES() asks user for a folder.
% all list/data files combinations in this folder
% are renamed to match the name in the list file.
%
% --- Author information
% Wouter Potters
% Academic Medical Center, Amsterdam, The Netherlands
% w.v.potters@amc.nl
% Date: 26-June-2014 

persistent path_to_data;
prev_path_data = path_to_data;

% make sure that path_to_data is not invalid
if ~isempty(path_to_data) && isnumeric(path_to_data) && (path_to_data == 0)
    path_to_data = [];
end

if nargin == 1
    path_to_data = varargin{1};
end
if isempty(path_to_data)
    switch computer
        case 'MACI64'
            path_to_data = uigetdir('~');
        otherwise
            path_to_data = uigetdir('C:/');
    end
else
    switch computer
        case 'MACI64'
            path_to_data = uigetdir(path_to_data);
        otherwise
            path_to_data = uigetdir(path_to_data);
    end
end

if isnumeric(path_to_data) && path_to_data == 0
    warning('User aborted folder selection - invalid folder')
    path_to_data = prev_path_data; % restore previous (valid) folder.
    return
end

files = dir(path_to_data);
files = files(arrayfun(@(files) length(files.name)>4 & ~files.isdir, files));
files = files(arrayfun(@(files) strcmp(regexp(files.name,'\w+$','match'),'list'),files));

for ifile = 1:length(files)
    file_path = fullfile(path_to_data,files(ifile).name);
    fid = fopen(file_path);
    line = fgetl(fid);
    while isempty(regexp(line,'^# Scan name   : \w+','once')); line = fgetl(fid); end
    file_path_list = file_path;
    file_path_data = [ file_path(1:end-4) 'data' ];
    
    % create new file name based on name in list file
    [~,newfilename] = regexp(line,'^# Scan name   : (?<match>.*$)','match','tokens','once');
    line = fgetl(fid);
    [~,rawdatasetname] = regexp(line,'^# Dataset name: (?<match>.*$)','match','tokens','once');
    
    if ~isempty(newfilename) % avoid copying to a file with an empty name
        
        if (exist(file_path_list,'file') == 2) && (exist(file_path_data,'file') == 2)
            % ONLY RENAME FILE IF BOTH LIST AND DATA FILE EXIST
            
            file_iterator = '';
            file_path_list_new = fullfile(path_to_data,[rawdatasetname{1} '_' newfilename{1} file_iterator '.list']);
            file_path_data_new = fullfile(path_to_data,[rawdatasetname{1} '_' newfilename{1} file_iterator '.data']);
            
            if ~strcmp(file_path_list,file_path_list_new) % only copy if the current filename is incorrect
                
                % Make sure that the new filename does not overwrite
                % another existing file.
                while (exist(file_path_list_new,'file') == 2) || ...
                        (exist(file_path_data_new,'file') == 2)
                    if isnan(str2double(file_iterator))
                        file_iterator = '2';
                    else
                        file_iterator = num2str(str2double(file_iterator) + 1);
                    end
                    file_path_list_new = fullfile(path_to_data,[rawdatasetname{1} '_' newfilename{1} file_iterator '.list']);
                    file_path_data_new = fullfile(path_to_data,[rawdatasetname{1} '_' newfilename{1} file_iterator '.data']);
                end
                
                % RENAME FILES
                [status1,message1,~] = movefile(file_path_list, file_path_list_new);
                if (status1 == 0)
                    warning(['Copying data file failed: ' file_path_list_new ' : ' message1 ])
                else
                    disp(['Renamed ''' file_path_list ''' to ''' file_path_list_new ''''])
                    
                    % ONLY RENAME SECOND FILE IF FIRST FILE WAS SUCCESFUL
                    [status2,message2,~] = movefile(file_path_data, file_path_data_new);
                    if (status2 == 0)
                        warning(['Copying data file failed: ' file_path_data_new ' : ' message2 ])
                    else
                        disp(['Renamed ''' file_path_data ''' to ''' file_path_data_new ''''])
                    end
                    
                end
            else
                disp(['Filename ''' file_path_list_new ''' is correct already.'])
            end % only copy if the current filename is incorrect
        end % list and data file should exist
    else % isempty new filename
        warning(['Could not find valid file name in ''' file_path_list '''']);
    end % isempty new filename
end % for loop over all list files

% avoid any open files after this script
% might not work?
try  %#ok<TRYNC>
    fclose('all');
end
