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

% Last Modified by GUIDE v2.5 27-Mar-2014 20:23:41


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


% --- Outputs from this function are returned to the command line.
function varargout = GUI_fNIRS_OutputFcn(~, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% Realtime plot
 function realtime_plot(handles)
     n = 1;
     x = 0;
     y1 = 0;
     y2 = 0;
     y3 = 0;
     y4 = 0; % Training output
     
     global trainingData;
     global trainingIndex;
     global networkCreated;
     
     trainingData = [];
     trainingIndex = 1;
    try
        % Open serial connection
        s = serial('COM3', 'BaudRate', 19600); % Select COM port and set baud rate to 115200
        set(s, 'terminator', 'LF'); % Set terminator to LF (line feed)

        % Don't show warning
        warning('off','MATLAB:serial:fscanf:unsuccessfulRead');
        fopen(s); % Open connection.
        pause(2) % Arduino auto-resets at new connection! Give time to initialize. 

%         figureHandle = figure('NumberTitle','off','Name','Realtime data','Visible','off');
%         axesHandle = axes('Parent',figureHandle,'YGrid','on','XGrid','on');
        
        axesHandle = handles.axesRealTime;
        hold on;

        plotHandle = plot(axesHandle,x,y1,x,y2,x,y3,x,y4,'LineWidth',2);

        % Create xlabel
        xlabel('Time (s)');

        % Create ylabel
        ylabel('Amplitude');

        % Create title
        title('Realtime data');
           
%       set(figureHandle,'Visible','on');        

        fprintf(s,'s\n') % Write start command to Arduino.
        fscanf(s,'%c') % Receive return message (confirmation) (%c = all chars, including whitespace)

        %        while(get(handles.radioRealTime,'Value') == 1)
        while(1)
           % Read input as CSV, ignoring the commas (unsigned int = %u, text = %*c).
            sampledData(1,1:4) = fscanf(s,'%u%*c');
        
            x(n) = sampledData(1,1)/1000; % ms to s
            y1(n) = sampledData(1,2);
            y2(n) = sampledData(1,3);
            y3(n) = sampledData(1,4);
            y4(n) = 0;
            set(plotHandle,{'YData'},{y1;y2;y3;y4},'Xdata',x);
            drawnow;
            set(handles.textSamplingSpeed,'String',num2str(n/(x(n)-x(1))));
            n = n + 1;
            if(get(handles.radioRealTime,'Value') == 0)
               delete(plotHandle);
               fprintf(s,'e\n') % Write stop command to Arduino.
               break;
            elseif(get(handles.toggleTraining,'Value') == 1)
                task = get(handles.menuTrainState,'Value');
                trainingData(trainingIndex,1:4) = [sampledData(2:4) task]
                trainingIndex = trainingIndex + 1
            elseif(networkCreated == 1)
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
                performance = perform(net,targets,outputs)

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
                net(sampledData(2:4),'useParallel','yes')
            end
        end
        fclose(s);
    catch exception % In case of error, always close connection first.
        fprintf(s,'e\n') % Write stop command to Arduino.
        fclose(s);
        throw(exception);
    end

% Makes radio buttons mutually exclusive
 function mutual_exclude(off)
	set(off,'Value',0);
    

% --- Executes on button press in radioRealTime.
function radioRealTime_Callback(hObject, eventdata, handles)
% hObject    handle to radioRealTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radioRealTime
off = [handles.radioSamples;handles.radioTasks];
mutual_exclude(off);
set(handles.editSamples,'Visible','off');
set(handles.panelTasks,'Visible','off');
set(handles.panelRealTime,'Visible','on');
set(handles.textSamplingSpeed,'Visible','on');
set(handles.menuTrainState,'Visible','on');
set(handles.toggleTraining,'Visible','on');
set(handles.toggleNetwork,'Visible','on');
realtime_plot(handles);
    
% --- Executes on button press in radioTasks.
function radioTasks_Callback(hObject, eventdata, handles)
% hObject    handle to radioTasks (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radioTasks
off = [handles.radioSamples;handles.radioRealTime];
mutual_exclude(off);
set(handles.editSamples,'Visible','off');
set(handles.panelTasks,'Visible','on');
set(handles.panelRealTime,'Visible','off');
set(handles.textSamplingSpeed,'Visible','off');
set(handles.menuTrainState,'Visible','off');
set(handles.toggleTraining,'Visible','off');
set(handles.toggleNetwork,'Visible','off');

% --- Executes on button press in radioSamples.
function radioSamples_Callback(hObject, eventdata, handles)
% hObject    handle to radioSamples (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radioSamples
off = [handles.radioTasks;handles.radioRealTime];
mutual_exclude(off);
set(handles.editSamples,'Visible','on');
set(handles.panelTasks,'Visible','off');
set(handles.panelRealTime,'Visible','off');
set(handles.textSamplingSpeed,'Visible','off');
set(handles.menuTrainState,'Visible','off');
set(handles.toggleTraining,'Visible','off');
set(handles.toggleNetwork,'Visible','off');

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


% --- Executes on button press in buttonAddTask.
function buttonAddTask_Callback(hObject, eventdata, handles)
% hObject    handle to buttonAddTask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    % Get selected task and add it to array
    index = str2num(get(handles.editIndex,'String'));
    temp = get(handles.arrayTasks,'Data');
    task = get(handles.listTasks,'Value');
    duration = str2num(get(handles.editTaskDuration,'String'));
    
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

% Hints: get(hObject,'String') returns contents of editTaskDuration as text
%        str2double(get(hObject,'String')) returns contents of editTaskDuration as a double


% --- Executes on button press in buttonStart.
function buttonStart_Callback(hObject, eventdata, handles)
% hObject    handle to buttonStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if(get(handles.radioSamples,'Value') == 1)
    numberSamples = str2num(get(handles.editSamples,'String'));
    if(numberSamples > 0)
        ReceiveDataFromArduino(numberSamples, [], 0);
    end
elseif(get(handles.radioTasks,'Value'))
    amountTasks = str2num(get(handles.editIndex,'String')) - 1
    tasks = get(handles.arrayTasks,'Data')
    if(amountTasks > 0)
        ReceiveDataFromArduino(0, tasks, amountTasks);
    else
        
    end
end


function editSamples_Callback(hObject, eventdata, handles)
% hObject    handle to editSamples (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editSamples as text
%        str2double(get(hObject,'String')) returns contents of editSamples as a double


% --- Executes during object creation, after setting all properties.
function axesRealTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axesRealTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate axesRealTime


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


% --- Executes on button press in togglebutton5.
function togglebutton5_Callback(hObject, eventdata, handles)
% hObject    handle to togglebutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of togglebutton5


% --- Executes on selection change in menuTrainState.
function menuTrainState_Callback(hObject, eventdata, handles)
% hObject    handle to menuTrainState (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns menuTrainState contents as cell array
%        contents{get(hObject,'Value')} returns selected item from menuTrainState


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

global trainingData;
global trainingIndex;
global networkCreated;

if(get(hObject,'Value') == 0)
    set(hObject,'String','Create network');
    networkCreated = 0;
else
    networkCreated = 0;
    set(hObject,'String','Reset training');
    trainingData = [];
    trainingIndex = 1;
    networkCreated = 1;
end
