% Process Physionet eemnmidb database to a usable format in matlab
    % Source: http://www.physionet.org/pn4/eegmmidb/
    % In summary, the experimental runs were:
    % 1 Baseline, eyes open
    % 2 Baseline, eyes closed
    % 3 Task 1 (open and close left or right fist)
    % 4 Task 2 (imagine opening and closing left or right fist)
    % 5 Task 3 (open and close both fists or both feet)
    % 6 Task 4 (imagine opening and closing both fists or both feet)
    % 7 Task 1
    % 8 Task 2
    % 9 Task 3
    % 10 Task 4
    % 11 Task 1
    % 12 Task 2
    % 13 Task 3
    % 14 Task 4
    %
    % The data are provided here in EDF+ format (containing 64 EEG signals, each sampled at 160 samples per second, and an annotation channel). For use with PhysioToolkit software, rdedfann generated a separate PhysioBank-compatible annotation file (with the suffix .event) for each recording. The .event files and the annotation channels in the corresponding .edf files contain identical data.
    %
    % Each annotation includes one of three codes (T0, T1, or T2):
    %
    % T0 corresponds to rest
    % T1 corresponds to onset of motion (real or imagined) of
    %     the left fist (in runs 3, 4, 7, 8, 11, and 12)
    %     both fists (in runs 5, 6, 9, 10, 13, and 14)
    % T2 corresponds to onset of motion (real or imagined) of
    %     the right fist (in runs 3, 4, 7, 8, 11, and 12)
    %     both feet (in runs 5, 6, 9, 10, 13, and 14)
    %
    % In the BCI2000-format versions of these files, which may be available from the contributors of this data set, these annotations are encoded as values of 0, 1, or 2 in the TargetCode state variable.
    %
    % The EEGs were recorded from 64 electrodes as per the international 10-10 system (excluding electrodes Nz, F9, F10, FT9, FT10, A1, A2, TP9, TP10, P9, and P10), as shown below (and in this PDF figure). The numbers below each electrode name indicate the order in which they appear in the records; note that signals in the records are numbered from 0 to 63, while the numbers in the figure range from 1 to 64.
    %
    % This data set was created and contributed to PhysioBank by Gerwin Schalk (schalk at wadsworth dot org) and his colleagues at the BCI R&D Program, Wadsworth Center, New York State Department of Health, Albany, NY. W.A. Sarnacki collected the data. Aditya Joshi compiled the dataset and prepared the documentation. D.J. McFarland and J.R. Wolpaw were responsible for experimental design and project oversight, respectively. This work was supported by grants from NIH/NIBIB ((EB006356 (GS) and EB00856 (JRW and GS)).

function [fullData,FS] = processPhysionetData(subj)

taskID = [];

fullData = [];
lastTime = 0;

lastFS = 0; % To check difference in sampling speed between files

% Select which trials to include
activeTrials = [1,2,4,8,12] % Baseline and Task 2 (imagine opening and closing left or right fist)

for trial = 1:size(activeTrials,2)
    % Parse file name and read file
    filename = sprintf('S%03uR%02u.edf',subj,activeTrials(1,trial))
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
                    annotation = 1;
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
    
    % Find last non-zero row
    lastRow = -1;
    for n = 2:4
        lastIndex = find(currBlock(:,n),1,'last');
        if(lastRow < lastIndex)
            lastRow = lastIndex;
        end
    end

    % Trim matrix to last non-zero rows
    currBlock = currBlock(1:lastRow,:);
    
    % Add block to full dataset
    fullData = [fullData;currBlock];
    
    % Update time for next block
    lastTime = time(end)
end


