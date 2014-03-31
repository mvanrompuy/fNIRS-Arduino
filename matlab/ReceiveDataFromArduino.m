function var = ReceiveDataFromArduino(numberSamples, tasks, amountTasks)
% ----------------------------------------------------------------------- %
%                 fNIRS DATA COLLECTION AND PROCESSING
%
%                       Maarten Van Rompuy
%
% TODO: - Rewrite to realtime? -> Sliding windows and work on frames
%       - Look at detrending algo's
%       - Wavelet transform
% ----------------------------------------------------------------------- %

% ----------------------------------------------------------------------- %
%                      CLEAR MATLAB ENVIRONMENT
% ----------------------------------------------------------------------- %

%clc;
%clear;
%close all;

% ----------------------------------------------------------------------- %
%                              VARIABLES
% ----------------------------------------------------------------------- %

%Tasks
currTask = 0;
timeNextTask = 0;
taskArray = tasks;

channels = 3; % Baseline (LED1 & LED2 off), LED1 on, LED2 on
samples = numberSamples; % Samples per channel
sampledData = zeros(samples,channels+2); % Initialize array (column for each channel + time column (Arduino))
sampledTask = zeros(samples,1);

resampleRatio = 2; % See improving ADC resolution from 10 to 12 bit
downsampledData = zeros(ceil(samples/resampleRatio),channels+1);
downsampledTask = zeros(ceil(samples/resampleRatio),1);

window = hamming(samples);

% Subplots matrix dimensions
mPlots = 4; % Rows
nPlots = 12; % Columns

i = 1;
n = 1;

% ----------------------------------------------------------------------- %
%                      CONNECT TO ARDUINO AND SAMPLE
% ----------------------------------------------------------------------- %

% Open serial connection
s = serial('COM3', 'BaudRate', 19200); % Select COM port and set baud rate to 115200
set(s, 'terminator', 'LF'); % Set terminator to LF (line feed)
% Don't show warning
warning('off','MATLAB:serial:fscanf:unsuccessfulRead');
fopen(s); % Open connection.
pause(2) % Arduino auto-resets at new connection! Give time to initialize.
try
    if(samples == 0)
        currTask = taskArray(1,1)
        timeNextTask = taskArray(1,2)
        
        samples = 10000;
        sampledData = zeros(samples,channels+2); % Initialize array (column for each channel + time column (Arduino))
        sampledTask = zeros(samples,1);
        downsampledData = zeros(ceil(samples/resampleRatio),channels+1);
        downsampledTask = zeros(ceil(samples/resampleRatio),1);      
        
        fprintf(s,'s\n') % Write start command to Arduino.
        fscanf(s,'%c') % Receive return message (confirmation) (%c = all chars, including whitespace)

        while(i <= amountTasks)
            % Read input as CSV, ignoring the commas (unsigned int = %u, text = %*c).
            sampledData(n,1:4) = fscanf(s,'%u%*c');
            sampledTask(n,1) = currTask;
                %Store current task and signal user of task switch
                if(floor(sampledData(n,1)/(timeNextTask*1000)) >= 1)
                    beep();
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
        beep();
        fprintf(s,'e\n') % Write stop command to Arduino.
        
        % Update to real number of samples
        samples = n - 1;
        sampledData = sampledData(1:n-1,1:4);
        sampledTask = sampledTask(1:n-1,1);
        downsampledData = zeros(ceil(samples/resampleRatio),channels+1);
        downsampledTask = zeros(ceil(samples/resampleRatio),1);
    else
        fprintf(s,'%u\n',samples) % Write number of samples to Arduino.
        fscanf(s,'%c') % Receive return message (confirmation) (%c = all chars, including whitespace)

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
    
for c = 1:channels+1
    downsampledData(:,c) = decimate(sampledData(:,c),resampleRatio);
end
    downsampledTask(:,1) = downsample(sampledTask(:,1),resampleRatio);

    % Downsampled signal sampling frequency
    TDownavg = (downsampledData(length(downsampledData),1)-downsampledData(1,1))/(length(downsampledData)*1000) % Sampling time (converted to seconds)
    FSDown  = 1/TDownavg  %Sampling frequency of each channel (=> Real frequency = fs*channels)            

    
    
    % Remove background light
%     downsampledData(2,:) = downsampledData(2,:) - mean(downsampledData(1,:));
%     downsampledData(3,:) = downsampledData(3,:) - mean(downsampledData(1,:));
    
% ----------------------------------------------------------------------- %
%                OUTPUT PLOT AND FFT OF OVERSAMPLED DATA     
% ----------------------------------------------------------------------- %
    figure(1);
    subplot(mPlots,nPlots,[1 6]);
    colorMap = hsv(channels); %Create color for each channel
    hold on;
    for p = 2:4
     plot(sampledData(:,1),sampledData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
    end
    title('Acquired signal')
    xlabel('time (milliseconds)')
    
    
    %FFT at normal sampling rate (wide FFT)
%     figure(2);
    subplot(mPlots,nPlots,[7 12]);
    X=fft(sampledData(:,3));
    plot([0:length(X)/2-1]/length(X)*FS,20*log10(abs(X([1:length(X)/2],1)))) 
    
% ----------------------------------------------------------------------- %
%               OUTPUT PLOT OF DOWNSAMPLED (AVERAGED) DATA     
% ----------------------------------------------------------------------- %

%     figure(3);
    subplot(mPlots,nPlots,[13 18]);
    hold on;
    for p = 2:4
        plot(downsampledData(:,1),downsampledData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
    end
    
    xValue = 0;
    for n = 1:amountTasks
        xValue = xValue + taskArray(n,2)*1000;
        line([xValue xValue], [0 1024]);
    end

% ----------------------------------------------------------------------- %
%                       OUTPUT PLOT OF NORMALIZED DATA     
% ----------------------------------------------------------------------- %   

    normalizedData(:,1) = downsampledData(:,1);
    % Normalize each channel
    for c = 2:4
        normalizedData(:,c) = downsampledData(:,c)/norm(downsampledData(:,c));
    end
    
%     figure(4);
    subplot(mPlots,nPlots,[19 24]);
    hold on;
    for p = 2:4
        plot(normalizedData(:,1),normalizedData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
    end

% ----------------------------------------------------------------------- %
%                                  FILTERING     
% ----------------------------------------------------------------------- %
    
    for c = 1:channels+1
        if(c == 1)            
                    %             %Calculate bandpass filter (shows heart
                    %             rate frequencies)
                    %             Wp = [0.01 1]/(FSDown/2);    % Passband (normalized frequencies)
                    %             Ws = [0.001 4]/(FSDown/2);    % Stopband (normalized frequencies
                    %             Rp = 1;                 % Passband ripple (dB)
                    %             Rs = 40;                % Attenuation in stopbands (dB)
                    %             [n,Wn] = buttord(Wp,Ws,Rp,Rs);
                    %             [b,a] = butter(n,Wn,'bandpass');
                    %             figure(10);
                    %             freqz(b,a,100,FSDown); % Show filter response
                    
                    Fp  = 0.6; % Fpass (Hz)
                    Fst = 0.8; % Fstop (Hz)
                    % Fc = (Fp+Fst)/2;  Transition Width = Fst - Fp
                    Ap  = 0.5; % Ripple in passband (allowed)
                    Ast = 60; % Attenuation stopband
                    Fsample = FSDown;
                    D = fdesign.lowpass('Fp,Fst,Ap,Ast',Fp,Fst,Ap,Ast,Fsample);
                    Hd = design(D,'equiripple','StopBandShape','linear','StopBandDecay',20);
                    % Visualization is output later in code to not break
                    % figure 1 subplots up into 2 figures.

        else
            %normalizedData(:,c) = filtfilt(b,a,normalizedData(:,c));
            %normalizedData(:,c) = IIRButterworthFilterData(normalizedData(:,c));
            normalizedData(:,c) = filtfilt(Hd.Numerator,1,normalizedData(:,c));
        end
    end
    
%     figure(6);
    subplot(mPlots,nPlots,[25 36]);
    hold on;
    for p = 2:4
        plot(normalizedData(:,1),normalizedData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
    end
        
% ----------------------------------------------------------------------- %
%                        FAST FOURIER TRANSFORM
%                   -> To find frequency components
% ----------------------------------------------------------------------- %
    
    % Channel 1 - FFT (single-sided)
%     figure(7);
    subplot(mPlots,nPlots,[37 40]);
    X=fft(normalizedData(:,2));
    plot([0:length(X)/2-1]/length(X)*FSDown,20*log10(abs(X([1:length(X)/2],1))))

    % Channel 2 - FFT (single-sided)
%     figure(8);
    subplot(mPlots,nPlots,[41 44]);
    X=fft(normalizedData(:,3));
    plot([0:length(X)/2-1]/length(X)*FSDown,20*log10(abs(X([1:length(X)/2],1))))	 

    % Channel 3 - FFT (single-sided)
%     figure(9);
    subplot(mPlots,nPlots,[45 48]);
    X=fft(normalizedData(:,4));
    plot([0:length(X)/2-1]/length(X)*FSDown,20*log10(abs(X([1:length(X)/2],1))))	 

%     tightfig();

    % Visualize used LP filter
    fvtool(Hd);

catch exception % In case of error, always close connection first.
    fclose(s);
    throw(exception);
end

% ----------------------------------------------------------------------- %
%                        MODIFIED BEER-LAMBERT LAW
% ----------------------------------------------------------------------- %

Hb = MBLL(normalizedData);

figure(4);
hold on;
for p = 1:2
    plot(normalizedData(:,1),Hb(p,:)','color',colorMap(p,:)) % Plot all channels in different colors
end

    figure(5);
    HbT = Hb(1,:) - Hb(2,:);
    plot(normalizedData(:,1),HbT')

    figure(6);
    X=fft(Hb(:,4));
    plot([0:length(X)/2-1]/length(X)*FSDown,20*log10(abs(X([1:length(X)/2],1))))	

% ----------------------------------------------------------------------- %
%                             CLASSIFICATION
% ----------------------------------------------------------------------- %    
    
mlData = normalizedData(:,2:4);
Machine_learning(mlData,downsampledTask)

% ----------------------------------------------------------------------- %
%                           SAVE ALL VARIABLES TO FILE
% ----------------------------------------------------------------------- %    

save(datestr(now,'yyyymmdd_HHMMSS_fNIRS_VAR'))



% ----------------------------------------------------------------------- %
%                        EXTRA/DEBUGGING CODE
% ----------------------------------------------------------------------- %

%         % Moving average of 10 last values
%         if(i == 1)
%             movingAverage(:,1) = repmat(sampledData(1,2),[10 1]); % Fill array with first sampled value
%         else % Update array and average
%             movingAverage = circshift(movingAverage,-1); % Shift up
%             movingAverage(10,1) = sampledData(i,2); % Add latest value to bottom
%             temp = mean(movingAverage);
%             sampledData(i,3:4) = sampledData(i,3:4) - temp; 
%         end
    
    
%  %Overwrite channel 1 with 2 mixed sine (for debugging)
%  for i = 1:samples
%         sinef = 0.001; % 1 Hz
%         ti = [0:sampledData(samples,1)/samples:sampledData(samples,1)]';
%         sampledData(i,2) = 100*sin(2*pi*sinef*ti(i,1));
%         sinef = 0.005; % 5 Hz
%         sampledData(i,2) = sampledData(i,2) + 300*sin(2*pi*sinef*ti(i,1));
%         sampledData(i,2) = sampledData(i,2)*window(i,1);
%  end