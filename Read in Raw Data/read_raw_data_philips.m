function[AllData]=read_raw_data_philips(path,filename)

filepath=fullfile(char(path),char(filename));

P=loadRawKspace(filepath);

% Get number of signal averages
% Check complex data vector type if data is equal to 'STD', standard data
% vector (image data or spectroscopy data).
aver = unique( P.aver( strcmp( P.typ, 'STD' ) ) );
NumAverages = numel( aver );

% Function and variables to remove oversampling in frequency direction
if isfield(P.kspace_properties,'kx_oversample_factor'),
    kxOversamplePercent = ( P.kspace_properties.kx_oversample_factor - 1 ) / P.kspace_properties.kx_oversample_factor;
else
    kxOversamplePercent = 0;
end
remove_freq_oversampling = @( im, p ) im((floor(size(im,1)*p/2)+1):(floor(size(im,1)*(1-p/2))),:,:,:,:,:,:);
  
% Reformat for MOG per signal average
    % mog internal format, for reference:
    %   Data(Rows,Velocity Encodes).Times(Measured Cardiac Phases)
    %   Data(Rows,Velocity Encodes).KSpace(Columns, Coils, Measured Cardiac Phase)
for iAver = 1:NumAverages,

    % Preprocess

    indProfile              = find( strcmp( P.typ, 'STD' ) & P.aver == aver(iAver) );

    row                     = P.ky( indProfile ) - min( P.ky( indProfile ) ) + 1;
    coil                    = P.chan( indProfile ) + 1;
    velocityEncode          = P.extr1( indProfile ) + 1;
    cardiacPhase            = P.card( indProfile ) + 1;
    rrInterval              = P.rr( indProfile );
    profileTimeSinceTrigger = P.rtop( indProfile );
    
    newCardCycleIndex       = find( diff( profileTimeSinceTrigger ) < 0 ) + 1;

    triggerTimeSinceStart   = int32( zeros( size( indProfile ) ) );
    triggerTimeSinceStart( newCardCycleIndex ) = rrInterval( newCardCycleIndex );
    triggerTimeSinceStart   = cumsum( triggerTimeSinceStart );

    profileTimeSinceStart   = profileTimeSinceTrigger + triggerTimeSinceStart;

    % Create MOG data structure

    measuredCardiacPhase = nan( size( indProfile ) );

    Data( min(row):max(row), min(velocityEncode):max(velocityEncode) ) = struct( 'KSpace', [], 'Times', [] );

    allCoilNum = sort( unique ( coil ) );

    coilNum = nan( size( indProfile ) );

    for iP = 1:length( indProfile ),

        measuredCardiacPhase( iP ) = find( find( row==row(iP) & velocityEncode==velocityEncode(iP) & coil==coil(iP) ) == iP );
        coilNum( iP ) = find( allCoilNum == coil( iP ) );

        Data( row(iP), velocityEncode(iP) ).Times( measuredCardiacPhase(iP) ) = profileTimeSinceStart(iP);

        ky = P.complexdata{ indProfile( iP ) }';        

        Data( row(iP), velocityEncode(iP) ).KSpace( :, coilNum(iP), measuredCardiacPhase(iP) ) = ky;

    end
        
    for iD = 1:numel(Data)

        % MOG requires FFT in readout direction preproccessed
        kSpace = fftshift( ifft( Data( iD ).KSpace, [] , 1), 1);
        
        % Remove frequency oversampling
        if kxOversamplePercent > 0,
            kSpace = remove_freq_oversampling( kSpace, kxOversamplePercent );
        end
  
        % Replace k-Space
        Data( iD ).KSpace = kSpace;

    end
    
% Save to structure

    AllData(iAver).Data_Properties.Data             = Data;
    AllData(iAver).Data_Properties.KSpaceProperties = P.kspace_properties;

end