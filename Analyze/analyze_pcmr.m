function varargout = analyze_pcmr( patchedMatFilePath, dx, dy, nFrames, doRectify, doAlignSystole )
%ANALYSE_PCMR 
% 

% jfpva (joshua.vanamerom@kcl.ac.uk)


%% Initialise

% Input Arguments

if ~exist( 'patchedMatFilePath', 'var' ),
   [ patchedMatFileName, patchedMatFileDir ] = uigetfile( '*_patched.mat', 'Select patched data file' );
   patchedMatFilePath = fullfile( patchedMatFileDir, patchedMatFileName );
end

while exist( patchedMatFilePath, 'file' ) ~= 2,
    [ patchedMatFileName, patchedMatFileDir ] = uigetfile( '*_patched.mat', 'Select patched data file' );
    patchedMatFilePath = fullfile( patchedMatFileDir, patchedMatFileName );
end
    
if ~exist( 'dx', 'var' ),
    dx = NaN;
end

if ~exist( 'dy', 'var' ),
    dy = NaN;
end

if ~exist( 'nFrames', 'var' ),
    nFrames = NaN;  
end

if ~exist( 'doRectify', 'var' )
    doRectify = true;  
end

if ~exist( 'doAlignSystole', 'var' )
    doAlignSystole = true;  
end

% Output Arguments
if nargout > 0
    varargout = cell( 0 );
end


%% Load Data

M = matfile( patchedMatFilePath );

try
    
    Data_Properties = M.Data_Properties;
    RWaveTimes      = M.RWaveTimes;

catch errMException,

    warning( 'Could not read Data_Properties and RWaveTimes from %s', patchedMatFilePath ),
    rethrow( errMException )

end

[ ~, protocolTxtFileName ] = fileparts(patchedMatFilePath);


%% Get Missing Information

% Voxel Dimensions

if isnan(dx),

    dx = 1;
    dy = 1;
    
    if strcmp( Data_Properties.Protocol, '.list File' ),
   
        % Read voxel dimensions from .txt scan protocol file
        [ protocolTxtFileName, protocolTxtFileDir ] = uigetfile( '*.txt', 'Select protocol file' );
        protocolTxtFilePath = fullfile( protocolTxtFileDir, protocolTxtFileName );

        try

            protocolText = fileread(protocolTxtFilePath);
            X            = regexp( protocolText, 'Voxel size   RL \(mm\) =\s+(?<dx>\w[0-9.]+);', 'names' );
            Split        = regexp( protocolText, 'Voxel size   RL \(mm\) =\s+(?<dx>\w[0-9.]+);', 'split' );
            Y            = regexp( Split{2}, '.+AP \(mm\) =\s+(?<dy>\w[0-9.]+);', 'names' );
            dx = str2double(X.dx);
            dy = str2double(Y.dy);

        catch

            warning('Voxel dimensions cannot be read from %s\n   using dx = %g and dy = %g\n\n',protocolTxtFilePath,dx,dy),

        end
    
    else
        
        warning('Voxel dimensions not specified\n   using dx = %g and dy = %g\n\n',dx,dy),
        
    end
    
end

if isnan(dy),
    
    % Assume dy is the same as dx
    dy = dx;
    warning('Voxel dimension dy not specified\n   using dy = %g\n\n',dy),

end


%% Reconstruct PC MR Images

P = reconstruct_pcmr( Data_Properties, RWaveTimes, nFrames );

im = mean(P.Magnitude,3);

nFrames = size(P.Magnitude,3);


%% Get User ROI(s)

hFig = figure;

hFig.MenuBar        = 'none';
hFig.ToolBar        = 'figure';
hFig.NumberTitle    = 'off';
hFig.Name           = 'ROI Selection';

graphicsToRemove = { 'Save Figure', 'New Figure', 'Open File', ...
                     'Print Figure', 'Edit Plot', 'Rotate 3D', ...
                     'Show Plot Tools and Dock Figure', 'Hide Plot Tools', ...
                     'Insert Legend', 'Insert Colorbar', 'Link Plot', ...
                     'Brush/Select Data', 'Data Cursor' };
for iG = 1:length(graphicsToRemove),
    set(findall(findall(hFig),'ToolTipString',graphicsToRemove{iG}),'Visible','Off');
end

imshow( im, [] ),

hAx = gca;

title( 'draw region around vessel of interest' )

isRegionOk = false;

while ~isRegionOk

    hRoi = imfreehand( hAx );
       
    roiMask = hRoi.createMask;
    
    isRegionOk = strcmp( 'Use', questdlg( 'Use ROI?', 'ROI', 'Use', 'Redraw', 'Redraw' ) );
    
    hRoi.delete;
    
end

close( hFig ),


%% Compute Velocity and Flow

% TODO: ensure units handled properly

voxelArea = dx * dy;  % mm^2

time = P.FrameTimes;  % ms

rr = max(diff(RWaveTimes));  % ms

dt = [ diff(time), rr-time(end) ];  % ms

for iT = 1:length(time), 
    velMap = P.Velocity(:,:,iT); 
    velVal(:,iT) = velMap(roiMask);  % cm/s
end

if ( doRectify ),
    velVal = sign( sum( velVal(:) ) ) * velVal; 
end

velMean = mean(velVal); 

if ( doAlignSystole ),
    systoleCardiacPhaseFraction = 0.3;
    targetSystoleFrameNo        = round( systoleCardiacPhaseFraction * nFrames );
    maxVelocityFrameNo          = find( abs(velMean) == max(abs(velMean)), 1 );
    nFrameShift                 = targetSystoleFrameNo - maxVelocityFrameNo;
    velVal                      = circshift(velVal,[0,nFrameShift]);
end

velMean = mean(velVal); 
velStd  = std(velVal);  

roiArea = voxelArea * nnz( roiMask ) * ones( size( velMean ) );  % mm^2

vel2flow = @( v, a ) ( v ) .* ( a * 1e-2 );  % ml/s

flow = vel2flow( velMean, roiArea );

flowMean = mean( flow ) * 60; % ml/min

strokeVolume = sum( flow .* dt );  % ml


%% Tabulate

formatSpecTitle  = '%-12s    %-12s    %-12s    %-12s    %-12s\n\n';
formatSpecValues = '% 12i    % 12.1f    % 12.1f    % 12.1f    % 12.1f\n';

resultTable = cell( 0 );

resultTable{1} = sprintf( formatSpecTitle, 'Frame', 'Time (ms)', 'Area (mm^2)', 'Vel. (cm/s)', 'Flow (ml/s)' );

for iT = 1:length(time),
    
    resultTable{end+1} = sprintf( formatSpecValues, iT, time(iT), roiArea(iT), velMean(iT), flow(iT) );
    
end


%% Print Results

resultStr    = cell(0);
resultStr{1} = sprintf( 'Analyse MOG PC MR\n' );
resultStr{2} = sprintf( '=================\n\n' );
resultStr{3} = sprintf( 'Source: %s\n\n', patchedMatFilePath );
resultStr{4} = sprintf( 'R-R Interval:  %8.1f ms\n', rr );
resultStr{5} = sprintf( 'Mean Flow:     %8.1f ml/min\n', flowMean );
resultStr{6} = sprintf( 'Stroke Volume: %8.1f ml\n\n', strokeVolume );
resultStr    = [ resultStr, resultTable ];
disp( cell2mat( resultStr ) )


%% Display Results

screenSize = get( 0, 'screensize' );

hFig = figure;
hFig.NumberTitle    = 'off';
hFig.Name = [ 'Analyse MOG PC MR', ':  ', protocolTxtFileName ];
hFig.ToolBar = 'none';
hFig.Position(1) = 0.05 * screenSize(3);
hFig.Position(3) = 0.9 * screenSize(3);
hFig.Position(2) = 0.1 * screenSize(4);
hFig.Position(4) = 0.8 * screenSize(4);

subplot( 3, 6, [ 1 2 3 7 8 9] );
imshow( mean( P.Magnitude, 3 ), [] );  % TODO: add velocity colourmap overlay?
B = bwboundaries( roiMask );
hLine = line( B{1}(:,2), B{1}(:,1), 'Color', 'b' );

subplot( 3, 6, 13 ),
plot( time, roiArea, 'b', 'LineWidth', 2 ), 
xlabel( 'Times (ms)' ), 
ylabel( 'Area (mm^2)')

subplot( 3, 6, 14 ),
c = [ 0.7 0.8 0.9 ] ;
x = [time,flip(time,2)];
y = [velMean+velStd,flip(velMean-velStd,2)].';
patch(x,y,c.^0.5,'EdgeColor',c,'LineWidth',0.1),
line( time, velMean, 'Color', 'b', 'LineWidth', 2 ), 
xlabel( 'Times (ms)' ), 
ylabel( 'Velocity (cm/s)'),
hAx = gca;
hAx.Box = 'on';

subplot( 3, 6, 15 ),
c = [ 0.7 0.9 0.8 ] ;
x = [time,flip(time,2)];
y = [flow+vel2flow(velStd,roiArea),flip(flow-vel2flow(velStd,roiArea),2)].';
patch(x,y,c.^0.5,'EdgeColor',c,'LineWidth',0.1),
line( time, flow, 'Color', c/2 , 'LineWidth', 2 ), 
xlabel( 'Times (ms)' ), 
ylabel( 'Flow (ml/s)'),
hAx = gca;
hAx.Box = 'on';

hTextbox = annotation( 'textbox', ...
    'String', strrep( resultStr, '_', '\_' ), ...
    'FontName', 'Courier', ...
    'Position', [ 1/2+0.05 0.05 1/2-0.1 0.90 ], ...
    'LineStyle', 'none', ...
    'Margin', 0, ...
    'FitBoxToText', 'on' );


%% Save Results and Assign Output

% TODO: save results
% TODO: assign output

if nargout > 0,
    varargout{1} = hFig;
    if nargout > 1,
        varargout{2} = resultStr;
    end
end


end  % analyse_pcmr()


%% Sub-Function: reconstruct_pcmr()
function P = reconstruct_pcmr(Data_Properties,RWaveTimes,nFrames)

    if ~isfield(Data_Properties,'EncodingVelocity') || isnan(Data_Properties.EncodingVelocity),
        venc = 1;
        warning( 'No encoding velocity specified; using %g cm/s', venc )
    else
        venc = Data_Properties.EncodingVelocity;
    end

    dt = mode(diff(Data_Properties.Data(1,1).Times));
    rr = max(diff(RWaveTimes));  % NOTE: using longest R-R interval 

    nFramesTrue = round( rr / dt );

    if ~exist('nFrames','var') || isnan(nFrames),
        nFrames = nFramesTrue;
    end

    KSpace = resort_data_vectorized(Data_Properties.Data, RWaveTimes, nFrames );
    KSpace = permute(KSpace,[3 1 4 5 2]);
    P = reconstruct_images(Data_Properties,KSpace);
    
    P.Velocity = venc * P.Phase / (pi/2);

    P = rmfield( P, 'Phase' );

    frameTimes = linspace( 0, rr, nFrames + 1 );

    P.FrameTimes = frameTimes( 1:(end-1) );

end