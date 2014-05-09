% Based on
% http://nmr.mgh.harvard.edu/ext/optics/resources/homer2/HOMER2_UsersGuide_121129.pdf
% and OverLapping.m from HOMer toolbox

function saveAsNIRS(obj)
    SD.Lambda = getWavelengths(obj);
    SD.SrcPos(1,:) = [-3 0 0]; % X Y Z
    SD.nSrcs = 1;
    SD.DetPos(1,:) = [0 0 0]; % X Y Z
    SD.nDets = 1;
    
    % MeasList describes how each dataset was captured -> using which
    % source-detector pair
    % The columns describe each data row. 
    
    MeasList = [1 1 1 1]; % Source index, Detector index, Modulation frequency, Wavelength index
    
    for i = 2:length(SD.Lambda) % Add configuration for other wavelengths
        temp = MeasList;
        temp(:,4) = i;
        MeasList = [MeasList;temp];
    end
    
    SD.MeasList = MeasList;
    
%     SD.MeasListAct =
%     SD.MeasListVis = 

    NIRSFile.SD = SD;
    
    % Get raw data
    [rawData,time] = getData(obj,'raw');
    
    NIRSFile.d = rawData(:,2:3); % Store channel data
    NIRSFile.t = time; % Store time
    NIRSFile.s =  zeros(size(NIRSFile.t)); % Stimulus (1 = stimulus, 0 = no stimulus)
    if(getTasksSet(obj) == 1) % Auxiliary signal on same timebase
        NIRSFile.aux = getTasks(obj,'raw');
    else
        NIRSFile.aux = zeros(size(NIRSFile.t));
    end
    NIRSFile.ml = SD.MeasList; % Duplicate list of source-detector pairs
    
    % Save to file
    datetime = datestr(now,'yyyymmdd_HHMMSS');
    str = strcat(datetime ,'_fNIRS_VAR.NIRS');
    save(str,'-struct','NIRSFile','-MAT')
    
    % Check if background channel needs to be saved
    selection = questdlg('NIRS doesn''t support a background channel. Do you want to save it in a seperate file?',...
      'Background channel export',...
      'Yes','No','Yes'); 
    switch selection
        case 'Yes' % Continue
            backgrChannel = rawData(:,1);
            str = strcat(datetime ,'_fNIRS_VAR.backgr'); % Background channel not supported by NIRS, save in seperate file
            save(str,'backgrChannel','-MAT')
        case 'No' % Do nothing
    end
end

