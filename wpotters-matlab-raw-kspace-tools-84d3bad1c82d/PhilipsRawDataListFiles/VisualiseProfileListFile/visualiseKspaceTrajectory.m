function varargout = visualiseKspaceTrajectory(varargin)
% VISUALISEKSPACETRAJECTORY MATLAB code for visualiseKspaceTrajectory.fig
%      VISUALISEKSPACETRAJECTORY, by itself, creates a new VISUALISEKSPACETRAJECTORY or raises the existing
%      singleton*.
%
%      H = VISUALISEKSPACETRAJECTORY returns the handle to a new VISUALISEKSPACETRAJECTORY or the handle to
%      the existing singleton*.
%
%      VISUALISEKSPACETRAJECTORY('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in VISUALISEKSPACETRAJECTORY.M with the given input arguments.
%
%      VISUALISEKSPACETRAJECTORY('Property','Value',...) creates a new VISUALISEKSPACETRAJECTORY or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before visualiseKspaceTrajectory_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to visualiseKspaceTrajectory_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help visualiseKspaceTrajectory

% Last Modified by GUIDE v2.5 05-Nov-2014 14:03:06

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @visualiseKspaceTrajectory_OpeningFcn, ...
                   'gui_OutputFcn',  @visualiseKspaceTrajectory_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before visualiseKspaceTrajectory is made visible.
function visualiseKspaceTrajectory_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to visualiseKspaceTrajectory (see VARARGIN)

% Choose default command line output for visualiseKspaceTrajectory
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes visualiseKspaceTrajectory wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = visualiseKspaceTrajectory_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function txtPlotSpeed_Callback(hObject, eventdata, handles)
% hObject    handle to txtPlotSpeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
persistent previousvalue
if isempty(previousvalue)
    previousvalue = 0;
end
newvalue = get(hObject,'Value');

if (round(newvalue) ~= previousvalue)
    set(hObject,'Value',round(newvalue))
    previousvalue = round(newvalue);
    set(handles.plotspeedShow,'String',['speed: ' num2str(round(1000*newvalue/length(handles.ky))/10) '%']);
end

% --- Executes during object creation, after setting all properties.
function txtPlotSpeed_CreateFcn(hObject, eventdata, handles)
% hObject    handle to txtPlotSpeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in uiLoadFile.
function uiLoadFile_Callback(hObject, eventdata, handles)
% hObject    handle to uiLoadFile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
persistent lastdirused
if isempty(lastdirused)
    lastdirused = cd;
end
[ filename, directoryding] = uigetfile({'*.list;*.dat','List or Dat file'},'Select a dat or a list file to visualise.',lastdirused);
lastdirused = directoryding;

[~,~,ext] = fileparts(fullfile(directoryding,filename));

switch ext
    case '.dat'
        try
            fid = fopen(fullfile(directoryding,filename));
            line = fgetl(fid);
            count = numel(sscanf(line,'%f'));
            frewind(fid);
            if (count) == 3
                data = textscan(fid,'%f %f %f');
                data = data(:,1:2);
            elseif (count) == 2
                data = textscan(fid,'%f %f');
            elseif (count) == 1
                data = textscan(fid,'%f');
            else
                disp('strange file format')
            end
            fclose(fid);
            set(handles.restart,'String','Start','Enable','On')
            
            
        catch err
            disp(['file loading failed: ' err.message])
            return;
        end
        
        if size(data,2) == 1
            ky = data{1};
            kz = zeros(size(ky));
        elseif size(data,2) == 2
            ky = data{1};
            kz = data{2};
        else
            error('unexpected file format')
        end

    case '.list'
        hwait = waitbar(0,'Loading list file...'); drawnow;
        kspace = loadListFile(fullfile(directoryding,filename));
        
        kspace = selectKspaceLines(kspace);

        ky = double(kspace.ky);
        waitbar(.9,hwait); drawnow;
        kz = double(kspace.kz);
        waitbar(1,hwait)
        if get(handles.ui_check_create_datfile,'Value')==1
            listfilelocation = fullfile(directoryding,filename);
            createDatFileFromCurrentData(ky,kz,listfilelocation);
        end
        try delete(hwait); end
    otherwise 
        error('wrong input file format')
end

handles.ky = ky;
handles.kz = kz;
guidata(handles.figure1,handles)
plotAnimation(handles)

function plotAnimation(handles)
set(handles.uiLoadFile,'Enable','off')
set(handles.stopbutton,'Enable','on')
cla(handles.plotAxis);
ky = handles.ky;
kz = handles.kz; 

plotspeed = round(get(handles.txtPlotSpeed,'value'));
if get(handles.txtPlotSpeed,'Value') == 1
    if floor(length(ky)/10) > 10
        set(handles.txtPlotSpeed,'Min',1,'Max',floor(length(ky)/10))
    else
        set(handles.txtPlotSpeed,'Min',1,'Max',length(ky))
    end
    newval = length(handles.ky)/200;
    if newval < get(handles.txtPlotSpeed,'Min') || newval > get(handles.txtPlotSpeed,'Max')
        newval = get(handles.txtPlotSpeed,'Min');
    end
    set(handles.txtPlotSpeed,'Value',newval)
    set(handles.txtPlotSpeed,'SliderStep',[.05 .15])
end

% 2D and 3D
axis(handles.plotAxis,[min(ky)-min(ky) max(ky)-min(ky)+1 min(kz)-min(kz) max(kz)-min(kz)+1])
xlabel(handles.plotAxis,'ky'); ylabel(handles.plotAxis,'kz');

set(handles.plotAxis,'fontsize',18)

hold on
ky_width = max(ky) - min(ky) + 1;
kz_width = max(kz) - min(kz) + 1;
kspace_image = zeros(kz_width,ky_width);

% precalculate
indices = sub2ind(size(kspace_image),kz-min(kz)+1,ky-min(ky)+1);
maxOccurences = max( histc( indices, [0:max(indices)] ) );

imghandle = imagesc(kspace_image); 
colormap(jet(256)); 
caxis([0 maxOccurences])
axis tight; 
cb = colorbar;
title(cb,'# measurements','FontSize',15)
set(cb,'FontSize',15)
% if numel(unique(kz))==1 % only for 2D
%     set(handles.plotAxis,'DataAspectRatio',[1/(max(ky)-min(ky)+1) 1 1])
% else
%     set(handles.plotAxis,'DataAspectRatio',[1 1 1])
% end
set(handles.plotAxis,'DataAspectRatio',[1/kz_width 1/ky_width 1])
set(handles.plotAxis,'XTick',linspace(1,size(kspace_image,2),10))
set(handles.restart,'String','Running...','Enable','Off')

if size(kspace_image,1) == 1
    set(handles.plotAxis,'YTick',unique(kz))
    title(handles.plotAxis,'2D kspace filling')
    
else
    set(handles.plotAxis,'YTick',linspace(1,size(kspace_image,1),10))
    title(handles.plotAxis,'3D kspace filling')
end

set(handles.plotAxis,'XTickLabel',num2str(round(get(handles.plotAxis,'XTick')+min(ky(:)-1))'))
set(handles.plotAxis,'YTickLabel',num2str(round(get(handles.plotAxis,'YTick')+min(kz(:)-1))'))

for i = 1:length(ky)
    kspace_image(kz(i)-min(kz)+1,ky(i)-min(ky)+1) = kspace_image(kz(i)-min(kz)+1,ky(i)-min(ky)+1) + 1;
    if rem(i,plotspeed) == 0
        plotspeed = round(get(handles.txtPlotSpeed,'value'));
        if ( get(handles.stopbutton,'Value') == 1 )
            set(handles.stopbutton,'Value',0)
            set(handles.stopbutton,'Enable','off')
            break;
        end
        set(imghandle,'cdata',kspace_image);
        drawnow;
    end
end
set(imghandle,'cdata',kspace_image);
drawnow;

set(handles.stopbutton,'Value',0)
set(handles.stopbutton,'Enable','off')
set(handles.restart,'String','Restart','Enable','On')
set(handles.uiLoadFile,'Enable','on')

guidata(handles.figure1,handles);

% --- Executes on button press in restart.
function restart_Callback(hObject, eventdata, handles)
% hObject    handle to restart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
plotAnimation(handles)


% --- Executes on button press in stopbutton.
function stopbutton_Callback(hObject, eventdata, handles)
% hObject    handle to stopbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of stopbutton


% --- Executes during object creation, after setting all properties.
function plotspeedShow_CreateFcn(hObject, eventdata, handles)
% hObject    handle to plotspeedShow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

function kspace = loadListFile(listfile)
%kspace = loadListfile(filepath)
headers = 'typ mix   dyn   card  echo  loca  chan  extr1 extr2 ky    kz    n.a.  aver  sign  rf    grad  enc   rtop  rr    size   offset';
headers = textscan(headers,'%s');
headers = headers{1}(:)';
[nrofheaderlines, kspace_properties] = getNrofheaderlines(listfile);

try 
    fid = fopen(listfile);
catch
    error('MATLAB:loadListFile:invalidFile','List file is invalid.');
end


list = textscan(fid,'%s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d',inf,'HeaderLines',nrofheaderlines,'MultipleDelimsAsOne',1);
fclose(fid);

% remove
while strcmp(list{:,1}(end),'#')
    for i = length(list):-1:1
        try
            list{:,i}(length(list{:,1})) = [];
        catch
            %ignore error
        end
    end
end

kspace = struct(); %create empty struct
%fill struct with information on klines
for i = 1:length(headers)
    eval(['kspace.' strrep(headers{i},'.','_') '= list{:,' num2str(i) '};'])
end
kspace.complexdata = [];
kspace.kspace_properties = kspace_properties;
function [nrofheaderlines,kspace_properties] = getNrofheaderlines(listfile)
fid = fopen(listfile);
nrofheaderlines = 0;
currentline = '#';
kspace_properties = struct();
while any(strcmp(currentline(1),{'#','.'}))
    currentline = fgetl(fid);
    nrofheaderlines = nrofheaderlines + 1;
    if strcmp(currentline(1),'.')
        % save property;
        C = textscan(currentline,'. %f %f %f %s : %f %f',1);
        fieldname = strrep(C{4}{1},'-','_');
        kspace_properties.(fieldname) = [C{5} C{6}];
    end
end
nrofheaderlines = nrofheaderlines - 1;
fclose(fid);

function kspace = selectKspaceLines(kspace)
% headers = 'typ mix   dyn   card  echo  loca  chan  extr1 extr2 ky    kz    n.a.  aver  sign  rf    grad  enc   rtop  rr    size   offset';
kspace_orig = kspace;
kspace = rmfield(kspace,{'complexdata','kspace_properties','offset','size','rr','rtop'});

properties = fieldnames(kspace)';
multiple_choices = {};
preselection = ones(length(kspace.aver),1);
for iprop = 1:length(properties)
    curprop = properties(iprop);
    count = numel(unique(kspace.(curprop{1})));
    if count > 1
        multiple_choices{end+1} = curprop{1}; %#ok<AGROW>
    else
        preselection = preselection & ( kspace.(curprop{1}) == unique(kspace.(curprop{1})) );
    end
end
multiple_choices(ismember(multiple_choices,{'ky','kz'})) = [];

for i = 1:length(multiple_choices)
    choices = unique(kspace.(multiple_choices{i}));

    switch class(choices)
        case {'int32','double','single'}
            newchoices = {};
            for j = 1:length(choices)
                newchoices{j} = num2str(choices(j));
            end
            choices = newchoices;
        case 'char'
            % do nothing
    end
    
    [selection,ok] = listdlg('PromptString',multiple_choices{i},...
                'SelectionMode','multi',...
                'ListString',choices');
    if ~ok
        error('Invalid selection')
    end
    
    selection = choices(selection);

    if isnumeric(kspace.(multiple_choices{i}))
        selection = cellfun(@(str) str2double(str),selection); %#ok<ST2NM> % DO NOT USE STR2DOUBLE
    end
    preselection = preselection & ismember(kspace.(multiple_choices{i}), selection);
    if sum(preselection) == 0
        disp(multiple_choices{i})
    end
end

kspace = kspace_orig;

properties = fieldnames(kspace)';
for iprop = 1:length(properties)
    if ~strcmp(properties{iprop},'complexdata') && ~strcmp(properties{iprop},'kspace_properties')
        kspace.(properties{iprop}) = kspace.(properties{iprop})(preselection);
    end
end

if isempty(kspace.typ)
   disp('Empty kspace was left')
   kspace = selectKspaceLines(kspace_orig);
end


function createDatFileFromCurrentData(ky,kz,listfilelocation)
all_klines = [ky kz];
[all_klines_plus_nsa] = addnsa_to_klines( all_klines );
[path,file,~] = fileparts(listfilelocation);
datfilelocation = fullfile(path,[file '.dat']);

% now create the *.dat file
try
    fid = fopen(datfilelocation, 'w' );
    fprintf( fid, '%d %d %d\n', all_klines_plus_nsa');
    fclose(fid);
catch
    error('saving dat file failed')
end

function [all_klines_plus_nsa] = addnsa_to_klines( all_klines )
% [all_klines_plus_nsa] = addnsa_to_klines( all_klines )

nsa_number = zeros(size(all_klines,1),1);
for iline = 1:size(all_klines,1)
    
   loc = find(all(all_klines == ones(size(all_klines,1),1) * all_klines(iline,:),2));
   nsa_number(iline) = find(loc == iline)-1;
   
end

all_klines_plus_nsa = [all_klines nsa_number];