% Based on
% http://nmr.mgh.harvard.edu/ext/optics/resources/homer2/HOMER2_UsersGuide_121129.pdf
% and OverLapping.m from HOMer toolbox

function [fNIRS,samples,sampleRate] = loadNIRSFile(path, filename)
    imported = load(fullfile(path,filename) ,'-mat');
        
    lambda = imported.SD.Lambda;
    srcPos = imported.SD.SrcPos;
    nSrcs = imported.SD.nSrcs;
    DetPos = imported.SD.DetPos;
    nDets = imported.SD.nDets;
  
    measList = imported.SD.MeasList;
    
%     SD.MeasListAct
%     SD.MeasListVis
        
    rawData(:,3:4) = imported.d; % Store channel data
    rawData(:,1) = imported.t; % Store time
    s = imported.s; % Stimulus (1 = stimulus, 0 = no stimulus)
    if(any(imported.aux) == 1) % Check if any element is nonzero (tasks set)
        rawTasks = imported.aux; % Auxiliary signal on same timebase
    else
        rawTasks = [];
    end
    ml = imported.ml; % Duplicate list of source-detector pairs

    % Check if background channel is available
    fileStr = strsplit(filename,'.');
    backgrFilename = strcat(fileStr{1},'.backgr');
    if(exist(fullfile(path,backgrFilename),'file') == 2) % Check if file exists
        selection = questdlg('NIRS doesn''t support a background channel, but a seperate .backgr file was found. Do you want to load the background channel?',...
          'Background channel export',...
          'Yes','No','Yes'); 
        switch selection
            case 'Yes' % Continue
                importedBackgr = load(fullfile(path,backgrFilename),'-mat');
                rawData(:,2) = importedBackgr.backgrChannel;
            case 'No' % Do nothing
        end
    end
    
    % Construct and fill fNIRS data object
    fNIRS = fNIRSData((size(rawData,2)-1),lambda,rawData,rawTasks);
    samples = size(rawData,1);
    if(samples ~= 0)
        sampleRate = samples/(rawData(samples,1)-rawData(1,1));
    else
        sampleRate = 0;
    end
end

