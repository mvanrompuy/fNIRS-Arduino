
% haltExecution:
%     -1 - Exit GUI
%     0 - Continue sampling
%     1 - Stop sampling
%     2 - Send updated values to Arduino on next run

function varargout = GUI_fNIRS(varargin)
% GUI_FNIRS MATLAB code for GUI_fNIRS.fig
%      GUI_FNIRS, by itself, creates a new GUI_FNIRS or raises the existing
%      singleton*.
%
%      H = GUI_FNIRS returns the handle to a new GUI_FNIRS or the handle to
%      the existing singleton*.
%
%      GUI_FNIRS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_FNIRS.M with the given input arguments.
%
%      GUI_FNIRS('Property','Value',...) creates a new GUI_FNIRS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_fNIRS_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_fNIRS_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_fNIRS

% Last Modified by GUIDE v2.5 24-Apr-2014 20:57:20


% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_fNIRS_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_fNIRS_OutputFcn, ...
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


% --- Executes just before GUI_fNIRS is made visible.
function GUI_fNIRS_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_fNIRS (see VARARGIN)

% Choose default command line output for GUI_fNIRS
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes GUI_fNIRS wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% Run custom initialization
initialization(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = GUI_fNIRS_OutputFcn(~, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;




% -------------------------------------------------------------------------
%                               FUNCTIONS
% -------------------------------------------------------------------------

% Custom initialization
function initialization(hObject, handles)
        % Close any open serial connections
        closeAllSerialConnections();
        
        % Add shared parameters to GUIDATA
        handles.serialConnection = 0;
        handles.configADC = 0;
        handles.haltExecution = 1;
        handles.trainingData = [];
    	handles.trainingIndex = 0;
        handles.networkCreated = 0;
        
        % Store the new GUIDATA structure
        guidata(hObject,handles)

function s = openSerialConnection(handles,com,baud)  
    s = serial(com, 'BaudRate', baud); % Select COM port and set baud rate to 115200
    set(s, 'terminator', 'LF'); % Set terminator to LF (line feed)

    % Don't show warning
    warning('off','MATLAB:serial:fscanf:unsuccessfulRead');
    fopen(s); % Open connection.
    configADC = fscanf(s,'%u');  % or pause(2) % Arduino auto-resets at new connection! Give time to initialize.
    samplingDelay = fscanf(s,'%u');
        
    set(handles.textADCConfiguration,'String',dec2bin(configADC,8)); % Receive ADC configuration register setting
    setSamplingDelayGUI(handles,samplingDelay);
    
    % Update shared variable
    handles.configADC = configADC;
    handles.serialConnection = s;
    guidata(gcbo,handles);
    
function closeSerialConnection(s)
    if(s ~= 0)
        try
            fprintf(s,'e\n');
            fclose(s);

            % Update shared variable
            handles = guidata(gcbo);
            handles.serialConnection = 0;
            guidata(gcbo,handles);
        catch exception
            throw(exception)
        end
    end
    
% Realtime plot
 function realtime_plot(handles)
    n = 1;
    x = 0;
    y1 = 0;
    y2 = 0;
    y3 = 0;
    y4 = 0; % Training output

    refreshTime = 0; % Refresh time (samples) for FFT
    frameSize = 100; % Amount of samples to use for FFT
    frame = zeros(frameSize,3);
    
    trainingData = handles.trainingData;
    trainingIndex = handles.trainingIndex;
    networkCreated = handles.networkCreated;
    s = handles.serialConnection;
    
    % Update shared variables
    handles.haltExecution = 0;
    handles.trainingIndex = 1;
    handles.networkCreated = 0;
    guidata(gcbo,handles);
    
    % Setup FFT axes
    set(handles.output,'CurrentAxes',handles.axesFFT); % Set as current output axes
    handles.plotFFTHandle = plot(x,y1,x,y2,x,y3,'LineWidth',2);
    guidata(handles.output, handles); % Update handles structure

    xlabel('Frequency (Hz)'); % Create xlabel  
    ylabel('Amplitude'); % Create ylabel
    title('Realtime FFT'); % Create title

    % Setup plot axes
    set(handles.output,'CurrentAxes',handles.axesRealTime);
    handles.plotHandle = plot(x,y1,x,y2,x,y3,x,y4,'LineWidth',2);
    guidata(handles.output, handles); % Update handles structure

    xlabel('Time (s)'); % Create xlabel
    ylabel('Amplitude'); % Create ylabel
    title('Realtime data'); % Create title 
     
    try
        fprintf(s,'s\n'); % Write start command to Arduino.
        set(handles.textStatus,'String',fscanf(s,'%c')); % Receive return message (confirmation) (%c = all chars, including whitespace)

        %        while(get(handles.radioRealTime,'Value') == 1)
        while(getExecutionState() == 0)
           % Read input as CSV, ignoring the commas (unsigned int = %u, text = %*c).
            sampledData(1,1:4) = fscanf(s,'%u%*c');
        
            x(n) = sampledData(1,1)/1000; % ms to s
            y1(n) = sampledData(1,2);
            y2(n) = sampledData(1,3);
            y3(n) = sampledData(1,4);
            y4(n) = 0;
            set(handles.plotHandle,{'YData'},{y1;y2;y3;y4},'Xdata',x);
            drawnow;
            FS = n/(x(n)-x(1));
            set(handles.textSamplingSpeed,'String',num2str(FS));
                        
            if(get(handles.radioRealTime,'Value') == 0)
               break; % Halt execution on deselection
            elseif(get(handles.toggleTraining,'Value') == 1)
                task = get(handles.menuTrainState,'Value');
                trainingData(trainingIndex,1:4) = [sampledData(2:4) task]
                trainingIndex = trainingIndex + 1
            elseif(networkCreated == 1)
                clearvars inputs targets outputs net tr;
                
                inputs = trainingData(:,1:3)';
                targets = trainingData(:,4)';

                % Create a Pattern Recognition Network
                hiddenLayerSize = 10;
                net = patternnet(hiddenLayerSize);

                % Setup Division of Data for Training, Validation, Testing
                net.divideParam.trainRatio = 70/100;
                net.divideParam.valRatio = 15/100;
                net.divideParam.testRatio = 15/100;

                % Train the Network
                [net,tr] = train(net,inputs,targets,'useParallel','yes');

                outputs = net(inputs);
                
                % Test the Network
                errors = gsubtract(targets,outputs);
                performance = perform(net,targets,outputs);

                % View the Network
                view(net)
                outputs = net(inputs,'useParallel','yes');

                % Plots
                % Uncomment these lines to enable various plots.
                  figure, plotperform(tr)
                  figure, plottrainstate(tr)
                % figure, plotconfusion(targets,outputs)
                  figure, plotroc(targets,outputs)
                % figure, ploterrhist(errors)
                
                networkCreated = 2;
            elseif(networkCreated == 2)
                y4 = net(y3,'useParallel','yes')
            end
            
            % Calculate FFT
            refreshTime = ceil(FS); % Refresh every second
            if(n > frameSize)
                if(rem(n,refreshTime) == 0) % calculate FFT every "refreshTime" (when enough samples have been gathered)
                    frame(:,1:3) = [y1(n-frameSize+1:n)' y2(n-frameSize+1:n)' y3(n-frameSize+1:n)'];
                    calculateFFT(frame,1,handles);
                end
            end
            
            n = n + 1;
        end
        fprintf(s,'e/n'); % Stop sampling
        
                % cla(handles.axesRealTime);
                % cla(handles.axesFFT);
        stopSamplingGUIUpdate(handles);
        if(getExecutionState() == -1) % GUI close request function has run
            closeSerialConnection(s);
            delete(gcf);
        end
    catch exception % In case of error, always close connection first.
        closeSerialConnection(s);
        throw(exception);
    end
    
%
function calculateFFT(data,window,handles)
colorMap = hsv(size(data,2)); %Create color for each channel
L = size(data,1);
FS = str2double(get(handles.titleSamplingSpeed,'String'));

switch(window)
    case 1
        W = hamming(L);
    otherwise
        W = ones(L,1);
end

data(:,1:3) = bsxfun(@times,data,W); % Apply window
X(:,1:3) = fft(data(:,1:3));         % Calculate FFT

set(handles.output,'CurrentAxes',handles.axesFFT); % Set axesFFT as plot output
X = 20*log10(abs(X([1:L/2],1:3)));
set(handles.plotFFTHandle,{'YData'},{X(:,1);X(:,2);X(:,3)},'XData',[0:L/2-1]/L*FS);
drawnow;
% for p = 1:3
%     plot([0:L/2-1]/L*FS,20*log10(abs(X([1:L/2],p))),'color',colorMap(p,:)) % Plot all channels in different colors
% end 
    
% Update GUI on stop sampling
function stopSamplingGUIUpdate(handles)
    set(handles.buttonStart,'Value',0);

% Makes radio buttons mutually exclusive
function mutual_exclude(off)
	set(off,'Value',0);

% Update slider value and text on GUI
function setSamplingDelayGUI(handles,samplingDelay)
    set(handles.sliderSamplingDelay,'Value',samplingDelay);
    str = sprintf('%u milliseconds',samplingDelay);
    set(handles.textSamplingDelay,'String',str);

% Get current execution state value from GUIDATA
function int = getExecutionState()
    try
        handles = guidata(gcbo);
        int = handles.haltExecution;
    catch % if figure was closed, before this function was executed the reference to haltExecution will be lost.
        int = 1;
    end
    
% Empty serial buffer
function flushSerialBuffer(handles)
    s = handles.serialConnection;

    while(get(s,'BytesAvailable') ~= 0)
        fscanf(s);
    end
    fprintf(s,'f\n');

    set(handles.textStatus,'String','Serial buffer flushed!');
    
% Send samplingDelay to Arduino
function sendSamplingDelay(handles)
    s = handles.serialConnection;
    
    newDelay = get(handles.sliderSamplingDelay,'Value');
    setSamplingDelayGUI(handles,newDelay);
    updateDelayStr = sprintf('d%u\n',newDelay);
    fprintf(s,updateDelayStr);
	set(handles.textStatus,'String',fscanf(s,'%c'));




% -------------------------------------------------------------------------
%                         CALLBACK FUNCTIONS
% -------------------------------------------------------------------------
    
% --- Executes on button press in radioRealTime.
function radioRealTime_Callback(hObject, eventdata, handles)
% hObject    handle to radioRealTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radioRealTime
off = [handles.radioSamples;handles.radioTasks];
mutual_exclude(off);
% set(handles.editSamples,'Visible','off');
% set(handles.panelTasks,'Visible','off');
% set(handles.panelRealTime,'Visible','on');
% set(handles.titleSamplingSpeed,'Visible','on');
% set(handles.textSamplingSpeed,'Visible','on');
% set(handles.menuTrainState,'Visible','on');
% set(handles.toggleTraining,'Visible','on');
% set(handles.toggleNetwork,'Visible','on');
% set(handles.textADCConfiguration,'Visible','on');
% set(handles.titleADCConfiguration,'Visible','on');
% set(handles.titleADCGain,'Visible','on');
% set(handles.menuADCGain,'Visible','on');
% set(handles.menuADCGain,'Value',1); % Set gain to initial value (Gain 1)
% realtime_plot(handles);
    
% --- Executes on button press in radioTasks.
function radioTasks_Callback(hObject, eventdata, handles)
% hObject    handle to radioTasks (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radioTasks
off = [handles.radioSamples;handles.radioRealTime];
mutual_exclude(off);
% set(handles.editSamples,'Visible','off');
% set(handles.panelTasks,'Visible','on');
% set(handles.panelRealTime,'Visible','off');
% set(handles.titleSamplingSpeed,'Visible','off');
% set(handles.menuTrainState,'Visible','off');
% set(handles.toggleTraining,'Visible','off');
% set(handles.toggleNetwork,'Visible','off');
% set(handles.titleADCConfiguration,'Visible','off');
% set(handles.titleADCGain,'Visible','off');
% set(handles.menuADCGain,'Visible','off');

% --- Executes on button press in radioSamples.
function radioSamples_Callback(hObject, eventdata, handles)
% hObject    handle to radioSamples (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radioSamples
off = [handles.radioTasks;handles.radioRealTime];
mutual_exclude(off);
% set(handles.editSamples,'Visible','on');
% set(handles.panelTasks,'Visible','off');
% set(handles.panelRealTime,'Visible','off');
% set(handles.titleSamplingSpeed,'Visible','off');
% set(handles.menuTrainState,'Visible','off');
% set(handles.toggleTraining,'Visible','off');
% set(handles.toggleNetwork,'Visible','off');
% set(handles.titleADCConfiguration,'Visible','off');
% set(handles.titleADCGain,'Visible','off');
% set(handles.menuADCGain,'Visible','off');

% --- Executes on button press in buttonAddTask.
function buttonAddTask_Callback(hObject, eventdata, handles)
% hObject    handle to buttonAddTask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    % Get selected task and add it to array
    index = str2double(get(handles.editIndex,'String'));
    temp = get(handles.arrayTasks,'Data');
    task = get(handles.listTasks,'Value');
    duration = str2double(get(handles.editTaskDuration,'String'));
    
    if(size(task,2) > 1)
        set(handles.textStatus,'String','Please select exactly 1 task!');
    else
        if(index == 1)
            set(handles.arrayTasks,'Data',[task duration]);
        else
            set(handles.arrayTasks,'Data',[temp;task duration]);
        end

        set(handles.editIndex,'String',num2str(index + 1));
    end
 
% --- Executes on selection change in listTasks.
function listTasks_Callback(hObject, eventdata, handles)
% hObject    handle to listTasks (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listTasks contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listTasks

function editTaskDuration_Callback(hObject, eventdata, handles)
% hObject    handle to editTaskDuration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes on button press in buttonTrainRest.
function buttonTrainRest_Callback(hObject, eventdata, handles)
% hObject    handle to buttonTrainRest (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

set(handles.buttonTrainRest,'String','off');
set(handles.buttonTrainTask,'Visible','off');

% --- Executes on button press in buttonTrainTask.
function buttonTrainTask_Callback(hObject, eventdata, handles)
% hObject    handle to buttonTrainTask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes on selection change in menuTrainState.
function menuTrainState_Callback(hObject, eventdata, handles)
% hObject    handle to menuTrainState (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns menuTrainState contents as cell array
%        contents{get(hObject,'Value')} returns selected item from menuTrainState

% --- Executes on button press in toggleTraining.
function toggleTraining_Callback(hObject, eventdata, handles)
% hObject    handle to toggleTraining (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of toggleTraining

if(get(hObject,'Value') == 0)
    set(hObject,'String','Start training');
    set(hObject, 'BackgroundColor',[0 1 0]);
else
    set(hObject,'String','Stop training');
    set(hObject, 'BackgroundColor',[1 0 0]);
end

% --- Executes on button press in radioTaskAlert.
function radioTaskAlert_Callback(hObject, eventdata, handles)
% hObject    handle to radioTaskAlert (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radioTaskAlert

% --- Executes on button press in toggleNetwork.
function toggleNetwork_Callback(hObject, eventdata, handles)
% hObject    handle to toggleNetwork (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of toggleNetwork

if(get(hObject,'Value') == 0)
    set(hObject,'String','Create network');
    % Update shared variable
    handles.trainingData = [];
    handles.trainingIndex = 1;
    handles.networkCreated = 0;
    guidata(gcbo,handles);
else
    set(hObject,'String','Reset training');
    % Update shared variable
    handles.networkCreated = 1;
    guidata(gcbo,handles);
end

% --- Executes on selection change in menuADCGain.
function menuADCGain_Callback(hObject, eventdata, handles)
% hObject    handle to menuADCGain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns menuADCGain contents as cell array
%        contents{get(hObject,'Value')} returns selected item from menuADCGain

% Get shared variables
configADC = handles.configADC;
s = handles.serialConnection;

gainSetting = get(hObject,'Value');

switch gainSetting
    case 1 % Gain 1 - 00
        configADC = bitset(configADC,1,0);
        configADC = bitset(configADC,2,0);
    case 2 % Gain 2 - 01
        configADC = bitset(configADC,1,1);
        configADC = bitset(configADC,2,0);
    case 3 % Gain 4 - 10
        configADC = bitset(configADC,1,0);
        configADC = bitset(configADC,2,1);
    case 4 % Gain 8 - 11
        configADC = bitset(configADC,1,1);
        configADC = bitset(configADC,2,1);
end

set(handles.textADCConfiguration,'String',dec2bin(configADC,8));
updateGainStr = sprintf('c%u\n',configADC);
fprintf(s,updateGainStr);

% Update shared variable
handles.configADC = configADC;
guidata(gcbo,handles);

% --- Executes on slider movement.
function sliderSamplingDelay_Callback(hObject, eventdata, handles)
% hObject    handle to sliderSamplingDelay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Update shared variable
handles.haltExecution = 2; % Sampling delay is updated on next run
guidata(gcbo,handles)

roundedValue = round(get(hObject,'Value'));
setSamplingDelayGUI(handles,roundedValue);

% --- Executes on button press in buttonStartSerial.
function buttonStartSerial_Callback(hObject, eventdata, handles)
% hObject    handle to buttonStartSerial (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

s = handles.serialConnection;

COM = 'COM3';
baudRate = 28800;

if(get(hObject,'Value') == 1)
    % Open serial connection to Arduino
    try
        openSerialConnection(handles,COM,baudRate);
        set(handles.textStatus,'String','Connected to Arduino!');
    catch exception
        set(handles.textStatus,'String','Check connection with Arduino!');
        set(hObject,'Value',0); % Unset button
        throw(exception);
    end
elseif(get(handles.buttonStart,'Value') == 1)
    set(handles.textStatus,'String','First stop sampling!');
    set(hObject,'Value',1); % Reset button
else
    closeSerialConnection(s);
    set(handles.textStatus,'String','Disconnected from Arduino!');
end

% --- Executes on button press in buttonStart.
function buttonStart_Callback(hObject, eventdata, handles)
% hObject    handle to buttonStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

s = handles.serialConnection;

try
    if(strcmp(get(s,'Status'),'open'))
        if(get(hObject,'Value') == 1)
            % Confirm start of capture
            selection = questdlg('Overwrite previous measurement?',...
              'Start new data capture',...
              'Yes','No','Yes'); 
            switch selection 
              case 'Yes' % Continue
                % Empty serial buffer
                flushSerialBuffer(handles);

                if(getExecutionState() == 2)
                    sendSamplingDelay(handles);
                end

                % Update shared variable
                handles.haltExecution = 0;
                guidata(gcbo,handles)

                if(get(handles.radioRealTime,'Value') == 1)
                    realtime_plot(handles);
                elseif(get(handles.radioSamples,'Value') == 1)
                    numberSamples = str2double(get(handles.editSamples,'String'));
                    if(numberSamples > 0)
                        fNIRS(numberSamples, [], 0);
                    end
                elseif(get(handles.radioTasks,'Value'))
                    amountTasks = str2double(get(handles.editIndex,'String')) - 1
                    tasks = get(handles.arrayTasks,'Data')
                    if(amountTasks > 0)
                        fNIRS(0, tasks, amountTasks);
                    end
                else
                    set(handles.textStatus,'String','Select a mode!');
                    set(hObject,'Value',0); % Unset button
                end
              case 'No' % Abort
                set(hObject,'Value',0); % Unset button
                return;
            end
        else
             % Update shared variable
             handles.haltExecution = 1;
             guidata(gcbo,handles);
        end
    else
        set(handles.textStatus,'String','First connect to Arduino!');
        set(hObject,'Value',0); % Unset button
    end
catch exception
    set(handles.textStatus,'String','First connect to Arduino!');
    set(hObject,'Value',0); % Unset button
    %throw(exception)
end




% -------------------------------------------------------------------------
%                           CREATE FUNCTIONS
% -------------------------------------------------------------------------

% --- Executes during object creation, after setting all properties.
function listTasks_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listTasks (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editSamples_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editSamples (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'String','1000');

% --- Executes during object creation, after setting all properties.
function editTaskDuration_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editTaskDuration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'String','Task duration (seconds)');

% --- Executes during object creation, after setting all properties.
function editIndex_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editIndex (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'String','1');

% --- Executes during object creation, after setting all properties.
function axesRealTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axesRealTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate axesRealTime
cla(hObject);

% --- Executes during object creation, after setting all properties.
function menuTrainState_CreateFcn(hObject, eventdata, handles)
% hObject    handle to menuTrainState (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function menuADCGain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to menuADCGain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'Value',1);

% --- Executes during object creation, after setting all properties.
function sliderSamplingDelay_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sliderSamplingDelay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

min = 0;
max = 100;

set(hObject, 'SliderStep', [1,10]/(max - min)); % Step size when click on arrow and when on background (percent change)
set(hObject, 'Min', min);
set(hObject, 'Max', max);
set(hObject, 'Value', 25);

% --- Executes during object creation, after setting all properties.
function buttonStart_CreateFcn(hObject, eventdata, handles)
% hObject    handle to buttonStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'Value',0);

% --- Executes during object creation, after setting all properties.
function textStatus_CreateFcn(hObject, eventdata, handles)
% hObject    handle to textStatus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'String','');

% --- Executes during object creation, after setting all properties.
function textSamplingSpeed_CreateFcn(hObject, eventdata, handles)
% hObject    handle to textSamplingSpeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'String','');

% --- Executes during object creation, after setting all properties.
function textADCConfiguration_CreateFcn(hObject, eventdata, handles)
% hObject    handle to textADCConfiguration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

set(hObject,'String','');

% --- Executes during object creation, after setting all properties.
function buttonStartSerial_CreateFcn(hObject, eventdata, handles)
% hObject    handle to buttonStartSerial (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

set(hObject,'Value',0);

% --- Executes during object creation, after setting all properties.
function axesFFT_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axesFFT (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
cla(hObject);




% -------------------------------------------------------------------------
%                           CLOSE REQUEST FUNCTIONS
% -------------------------------------------------------------------------

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% handles % Display GUIDATA content for debugging

% Display a question dialog box
   selection = questdlg('Close this program?',...
      'Close Request Function',...
      'Yes','No','Yes'); 
    switch selection 
        case 'Yes'
        if(getExecutionState() == 0)
         % Give running functions time to exit cleanly.
         % Update shared variable
         handles.haltExecution = -1;
         guidata(gcbo,handles)
        else
        delete(gcf);
        end
        case 'No'
        return 
   end