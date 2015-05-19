%% This function is for testing loading of Raw Kspace using Phase Contrast data
% $Rev:: 196           $:  Revision of last commit
% $Author:: wvpotters  $:  Author of last commit
% $Date:: 2013-01-29 1#$:  Date of last commit
%% Clear workspace; close all images
clc; clear all; close all;

% Load Raw Data from file
[FileName,PathName] = uigetfile({'*.list;*.data'});
kspace = loadRawKspace(fullfile(PathName,FileName));

% Short script to show all unique selection parameters on command line.
% Get Unique values for All parameters and save them as varname_unique
for cur_prop = fieldnames(kspace)'
    if ~iscell(eval(['kspace.' cur_prop{1}]))
        eval([cur_prop{1} '_unique = unique(kspace.' cur_prop{1} ');'])
        if length(eval([cur_prop{1} '_unique'])) < 50 && ~(length(eval([cur_prop{1} '_unique'])) == 1)
            eval([cur_prop{1} '_unique'])
        end
    end
end

Nflowdirections = length(extr1_unique); % extr1 contains information if PC scan is velocity encoded or not.
Ncardiac = 60%kspace.kspace_properties.number_of_cardiac_phases;
Nchannels = length(chan_unique);

% Check if cardiac phases are already binned into Ncardiac heartphases
if Ncardiac ~= length(card_unique)
    disp('Cardiac phases are not yet binned; probably used retrospective gating.')
    disp('Attempting to bin cardiac phases...')
    kspace.card = binCardiacPhases(Ncardiac,kspace.rtop,kspace.rr);
    disp('Binning cardiac phases finished...')
end

% Fill in the kspace for each 
disp(['calculating for ' num2str(Nflowdirections) ' flow directions, ' num2str(Nchannels) ' channels, ' num2str(Ncardiac) ' cardiac phases directions'])

kspace_cine = cell(numel(extr1_unique),numel(chan_unique),Ncardiac);
for flow = extr1_unique' % for all flowencoded and nonflowencoded images
    for ch = chan_unique' % for all coil elements
        disp(['calculating flowdir ' num2str(flow) ' and coil ' num2str(ch)]);
        for c = 0:Ncardiac-1 % for all cardiac phases
            selection_kline = find( kspace.extr1 == flow & kspace.chan == ch & kspace.card == c & strcmp(kspace.typ,'STD'));  % select flowencoding, coil no, cardiac phase and standard k-line type.
            
            current_full_kspace = zeros(sum(abs(kspace.kspace_properties.kx_range(:)))+1,sum(abs(kspace.kspace_properties.ky_range(:)))+1,numel(kz_unique)); % make empty kspace
            if ~isempty(selection_kline)
                for n = selection_kline'
                    if length(kspace.complexdata{n}) == size(current_full_kspace,1)
                        current_full_kspace(:,kspace.ky(n)-min(kspace.ky)+1,kspace.kz(n)-min(kspace.kz)+1) = kspace.complexdata{n};
                    else
                        error('kspaceline longer or shorter then expected')
                    end
                end
            end
            kspace_cine{flow+1,ch+1,c+1} = current_full_kspace;
        end
    end
end

%% PLOT KSAPCE AND RECONS
kspace_img = kspace_cine{1,1,20};
subplot(2,2,1); imshow(real(kspace_img),[]); colorbar; axis equal tight
subplot(2,2,2); imshow(imag(kspace_img),[]); colorbar; axis equal tight
%%
recon_img = (ifft2(ifftshift(kspace_img)))
subplot(2,2,3); imshow(abs(recon_img((-154:153)+size(recon_img,1)/2,(-288:-1)+289),[]); colorbar;  axis equal tight
subplot(2,2,4); imshow(angle(recon_img),[]); colorbar;  axis equal tight


%%
size(kspace_img)

%% Save all variables
save all_variables_after_runnning_load_PhaseContrast.mat