% Process Physionet eemnmidb database to a usable format in matlab

function fullData = processPhysionetData(subj)

taskID = [];

fullData = [];
lastTime = 0;

lastFS = 0; % To check difference in sampling speed between files

for m = 1:14
    % Parse file name and read file
    filename = sprintf('S%03uR%02u.edf',subj,m)
    [hdr, record] = loadEDF(filename);

    % Read sampling rate
    FS = hdr.numberOfSamples{1,1}
    
    if(lastFS ~= hdr.numberOfSamples{1,1} && lastFS ~= 0)
        error('FS is not equal accross files!');
    end;
    
    %Keep channels 9 (C3), 11 (Cz) and 13 (C4) -> best for sensorimotor classification
    % + channel 65 -> contains task annotation
    currBlock = [record{9,1} record{11,1} record{13,1}];
    
    % Add time data
    time = [0:1/FS:((size(currBlock,1)-1)/FS)]' + lastTime; % Continue from time last block
    currBlock = [time,currBlock];
       
    % Add annotations
    % Clean hdr.annotation (remove empty rows)
    n = 1;
    while n <= length(hdr.annotations)
        %Clean up strings and convert to double
        if( isempty(hdr.annotations(n).duration) == 1)
            hdr.annotations(n) = [];   
        else
            onSet = str2double(hdr.annotations(n).onSet) + lastTime;
            duration = str2double(strtrim(hdr.annotations(n).duration(2:end)));
            switch hdr.annotations(n).annotation(2:end)
                case 'T0'
                    annotation = 0;
                case 'T1'
                    annotation = 1;
                case 'T2'
                    annotation = 2;
                otherwise
                    error('Task not recognized.');
            end
                % Note: % (2:end) to remove first character -> formatting error edf file (tab?)?
            annotations(n,1:3) = [onSet duration annotation];
            n = n+1;
        end
    end
    
    % Add annotation of tasks to matrix that contains measurements
    currTask = 1;
    taskDesc = annotations(currTask,3);
 
    for n=1:size(currBlock,1)
        % Check if more task changes are possible
        if(currTask < size(annotations,1));
            % Check if current task has changed
            if(currBlock(n,1) >= annotations(currTask+1,1))
                currTask = currTask + 1;
                taskDesc = annotations(currTask,3);
            end
        end
        % Store task
        currBlock(n,5) = taskDesc;
    end
    
    % Add block to full dataset
    fullData = [fullData;currBlock];
    
    % Update time for next block
    lastTime = time(end)
    end



