%% This function is for testing loading of Raw Kspace using Phase Contrast data
%% Clear workspace; close all images
clc; clear all; close all;
addpath('../../My Repositories/Matlab raw kspace tools/PhilipsRawDataListFiles/LoadListDataFiles')

% Load Raw Data from file
[FileName,PathName] = uigetfile({'*.list;*.data'});
kspace = loadRawKspace(fullfile(PathName,FileName));

%% Short script to show all unique tags on command line.
% Get Unique values for All parameters and save them as 'varname'_unique
for cur_prop = fieldnames(kspace)'
    if ~iscell(eval(['kspace.' cur_prop{1}])) && ~isstruct(eval(['kspace.' cur_prop{1}]))
        eval([cur_prop{1} '_unique = unique(kspace.' cur_prop{1} ');'])
        if length(eval([cur_prop{1} '_unique'])) < 50 && ~(length(eval([cur_prop{1} '_unique'])) == 1)
            eval([cur_prop{1} '_unique'])
        end
    end
end

%% Now collect the kspaces for the different mixes
kspace_filled = zeros( kspace.kspace_properties.kx_range(2) - kspace.kspace_properties.kx_range(1)+1,... kx size
    max(kspace.ky)-min(kspace.ky)+1,... ky size
    max(kspace.kz)-min(kspace.kz)+1,... kz size
    numel(chan_unique),... coils
    numel(mix_unique),... mixes
    numel(dyn_unique) ); % dynamics

selection_proper_lines = strcmp(kspace.typ,'STD');

% this loop can be slow for many lines.
tic
for index = find(selection_proper_lines)';
    kspace_filled(  :,... fill entire kx (readout dir.)
        kspace.ky(index) - min(kspace.ky) + 1,... ky coordinate - min(ky) + 1 % start at 1
        kspace.kz(index) - min(kspace.kz) + 1,... kz coordinate - min(kz) + 1
        kspace.chan(index) + 1,... coil id + 1
        kspace.mix(index) + 1,... mix id + 1
        kspace.dyn(index) + 1) ... Dynamics id
        = kspace.complexdata{index};
    if rem(index,round(sum(selection_proper_lines)/40)) == 0
        disp(['Progress: ' num2str(round((index/sum(selection_proper_lines))*100)) ' %']);
    end
end
toc