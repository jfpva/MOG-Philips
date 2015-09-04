function mog_example()
%EXAMPLE  usage of metric optimzed gating functions
%
% * read philips raw data (.data/.list), 
% * perform metric optimized gating, and
% * analyze flow
% 


%% Configure 

% Path to MOG toolbox
mogToolboxPath = fileparts( which( mfilename ) );


%% Add Dependencies

origPaths = path;

addpath( genpath( mogToolboxPath ) );

resetPath = onCleanup( @() path( origPaths ) );


%% Metric Optimized Gating

MOG_Tool,


%% Analyse Flow

analyze_pcmr,


end  % mog_example(...)
