function [sampledData,sampledTask,channels,samples,FS] = ReceiveDataFromArduino(samples, taskArray, amountTasks)

channels = 3; % Baseline (LED1 & LED2 off), LED1 on, LED2 on
com = 'COM3';
baud = 28800;

i = 1;
n = 1;

% ----------------------------------------------------------------------- %
%                      CONNECT TO ARDUINO AND SAMPLE
% ----------------------------------------------------------------------- %

% Open serial connection
s = serial(com, 'BaudRate', baud); % Select COM port and set baud rate to 115200
set(s, 'terminator', 'LF'); % Set terminator to LF (line feed)
% Don't show warning
warning('off','MATLAB:serial:fscanf:unsuccessfulRead');
fopen(s); % Open connection.
fscanf(s,'%u');  % Reads config data or add pause(2) -> Arduino auto-resets at new connection! Give time to initialize.

% try
    if(samples == 0)
        currTask = taskArray(1,1);
        timeNextTask = taskArray(1,2);
        
        samples = 10000; % Initial size
        sampledData = zeros(samples,channels+1); % Initialize array (column for each channel + time column (Arduino))
        sampledTask = zeros(samples,1);
        
        fprintf(s,'s\n') % Write start command to Arduino.
        fscanf(s,'%c') % Receive return message (confirmation) (%c = all chars, including whitespace)

        while(i <= amountTasks)
            % Read input as CSV, ignoring the commas (unsigned int = %u, text = %*c).
            sampledData(n,1:4) = fscanf(s,'%u%*c');
            sampledTask(n,1) = currTask;
                %Store current task and signal user of task switch
                if(floor(sampledData(n,1)/(timeNextTask*1000)) >= 1)
                    beep();     % Signal task switch (beep sound)
                    i = i + 1;
                    if(i <= amountTasks)
                        currTask = taskArray(i,1);
                        timeNextTask = timeNextTask + taskArray(i,2);
                    end
                end
            %Apply windowing function to suppress discontinuities
            sampledData(n,2:4) = sampledData(n,2:4); %*window(i,1);
            n = n + 1;
        end
        beep();beep();          % Signal end (double beep sound)
        fprintf(s,'e\n')        % Write stop command to Arduino.
        
        % Update to real number of samples
        samples = n - 1;
        sampledData = sampledData(1:n-1,1:4);
        sampledTask = sampledTask(1:n-1,1);
    else
        fprintf(s,'%u\n',samples) % Write number of samples to Arduino.
        fscanf(s,'%c') % Receive return message (confirmation) (%c = all chars, including whitespace)

        sampledData = zeros(samples,channels+2); % Initialize array (column for each channel + time column (Arduino))
        sampledTask = [];                        % No tasks recorded in this mode
        
        for i = 1:samples
            % Read input as CSV, ignoring the commas (unsigned int = %u, text = %*c).
            sampledData(i,1:4) = fscanf(s,'%u%*c');

            %Apply windowing function to suppress discontinuities
            sampledData(i,2:4) = sampledData(i,2:4); %*window(i,1);
        end
    end
    fclose(s);    
    
    % Remove time offset (first sample)
    sampledData(:,1) = sampledData(:,1) - sampledData(1,1);
     
    % Sampling frequency
    Tavg = (sampledData(samples,1)-sampledData(1,1))/(samples*1000) % Sampling time (converted to seconds)
    FS  = 1/Tavg  %Sampling frequency of each channel (=> Real frequency = fs*channels)

% catch exception % In case of error, always close connection first.
%     fclose(s);
%     throw(exception);
% end
                                                                % NEEDS LOWPASS FILTER, CURRENTLY TESTING WITH DECIMATE    
                                                                % % ----------------------------------------------------------------------- %
                                                                % %          IMPROVE ADC RESOLUTION FROM 10 TO 12 BIT (OVERSAMPLING)     
                                                                % %   
                                                                % %   Average oversampled data to improve ADC resolution (not accuracy)
                                                                % %   -> 16 samples added and result shifted by 2 bit -> ADC from 10 bit 
                                                                % %    to 12 bit + improves SNR
                                                                % % ----------------------------------------------------------------------- %
                                                                % 
                                                                % for i = 1:samples
                                                                %         if(mod(i,16) == 0) % Every 16th sample
                                                                %             % Determine current position in array
                                                                %             index = floor(i/resampleRatio); % Should be 16!
                                                                %             
                                                                %             % Sum the last 16 samples and shift out the two LSB to get the
                                                                %             % correct result.
                                                                %             % Averaging is LP filter (rectangular, sinc in f-domain))
                                                                %             downsampledData(index,2:4) = sum(sampledData(i-15:i,2:4))/resampleRatio;
                                                                % 
                                                                %             % Set the time of samples in downSampledArray
                                                                %             downsampledData(index,1) = sampledData(i-15,1);
                                                                %         end
                                                                %     end