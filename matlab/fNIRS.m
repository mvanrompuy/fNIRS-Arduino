function fNIRS(numberSamples, tasks, amountTasks)
% ----------------------------------------------------------------------- %
%                 fNIRS DATA COLLECTION AND PROCESSING
%
%                       Maarten Van Rompuy
%
% TODO: - Rewrite to realtime? -> Sliding windows and work on frames
%       - Look at detrending algo's
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

resampleRatio = 2; % See improving ADC resolution from 10 to 12 bit

% Subplots matrix dimensions
mPlots = 4; % Rows
nPlots = 12; % Columns

% ----------------------------------------------------------------------- %
%                      CONNECT TO ARDUINO AND SAMPLE
% ----------------------------------------------------------------------- %

[sampledData,sampledTask,channels,samples,FS] = ReceiveDataFromArduino(numberSamples, tasks, amountTasks);

% ----------------------------------------------------------------------- %
%                       SECONDS -> MILLISECONDS     
% ----------------------------------------------------------------------- %    
    sampledData(:,1) = sampledData(:,1)/1000;

% % ----------------------------------------------------------------------- %
% %                             CREATE WINDOWS     
% % ----------------------------------------------------------------------- %     
%     window = hamming(samples);
    
% ----------------------------------------------------------------------- %
%                OUTPUT PLOT AND FFT OF SAMPLED DATA     
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
    subplot(mPlots,nPlots,[7 12]);
    X=fft(sampledData(:,3));
    plot([0:length(X)/2-1]/length(X)*FS,20*log10(abs(X([1:length(X)/2],1))))
    
% ----------------------------------------------------------------------- %
%                         REMOVE BACKGROUND LIGHT     
% ----------------------------------------------------------------------- %
    sampledData(:,3) = sampledData(:,3) - mean(sampledData(:,2));
    sampledData(:,4) = sampledData(:,4) - mean(sampledData(:,2));                                                                

% ----------------------------------------------------------------------- %
%                         DOWNSAMPLE DATA     
% ----------------------------------------------------------------------- %  
    downsampledData = zeros(ceil(samples/resampleRatio),channels+1);
        
    for c = 1:channels+1
        downsampledData(:,c) = decimate(sampledData(:,c),resampleRatio);
    end

    % Downsampled signal sampling frequency
    TDownavg = (downsampledData(length(downsampledData),1)-downsampledData(1,1))/(length(downsampledData)) % Sampling time (converted to seconds)
    FSDown  = 1/TDownavg  %Sampling frequency of each channel (=> Real frequency = fs*channels)            
    
    if(amountTasks > 0)
        downsampledTask = zeros(ceil(samples/resampleRatio),1);
        downsampledTask(:,1) = downsample(sampledTask(:,1),resampleRatio);
    end
% ----------------------------------------------------------------------- %
%               OUTPUT PLOT OF DOWNSAMPLED (AVERAGED) DATA     
% ----------------------------------------------------------------------- %
    subplot(mPlots,nPlots,[13 18]);
    hold on;
    for p = 3:4
        plot(downsampledData(:,1),downsampledData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
    end
    
    xValue = 0;
    for n = 1:amountTasks
        xValue = xValue + tasks(n,2);
        line([xValue xValue], [min(min(downsampledData(:,2:channels+1))) max(max(downsampledData(:,2:channels+1)))]); % Set lines on  task switch (height equal range min - max value on data channels
    end

% ----------------------------------------------------------------------- %
%                                  FILTERING     
% ----------------------------------------------------------------------- %
    filteredData = downsampledData(:,1);

                % %Calculate bandpass filter (shows heart rate frequencies)
                % Wp = [0.01 1]/(FSDown/2);    % Passband (normalized frequencies)
                % Ws = [0.001 4]/(FSDown/2);    % Stopband (normalized frequencies
                % Rp = 1;                 % Passband ripple (dB)
                % Rs = 40;                % Attenuation in stopbands (dB)
                % [n,Wn] = buttord(Wp,Ws,Rp,Rs);
                % [b,a] = butter(n,Wn,'bandpass');
                % figure(10);
                % freqz(b,a,100,FSDown); % Show filter response

    Fst1 = 0.001;   % Fstop (Hz)
    Fp1 = 0.01; % Fpass (Hz)
    Fp2  = 0.5; % Fpass (Hz)
    Fst2 = 0.7; % Fstop (Hz)
    % Fc = (Fp+Fst)/2;  Transition Width = Fst - Fp
    Ap  = 1; % Ripple in passband (allowed)
    Ast1 = 40;
    Ast2 = 40; % Attenuation stopband
    Fsample = FSDown;
    D = fdesign.bandpass('Fst1,Fp1,Fp2,Fst2,Ast1,Ap,Ast2',Fst1,Fp1,Fp2,Fst2,Ast1,Ap,Ast2,Fsample);
    Hd = design(D,'butter');
    [B,A]= sos2tf(Hd.sosMatrix,Hd.ScaleValues); % When using filtfilt -> Can give wrong filter characteristics due to numerical errors
    measure(Hd) % Return performance of filter
    % Visualization is output later in code to not break
    % figure 1 subplots up into 2 figures.

            %filteredData(:,c) = filtfilt(b,a,downsampledData(:,c));
            %filteredData(:,c) = IIRButterworthFilterData(downsampledData(:,c));
            %filteredData(:,c) = filter(Hd,downsampledData(:,c));

    filteredData(:,3) = filtfilt(B,A,downsampledData(:,3));
    filteredData(:,4) = filtfilt(B,A,downsampledData(:,4));

%     zplane(B,A) % To control stability of filter
    
    subplot(mPlots,nPlots,[19 24]);
    hold on;
    for p = 3:4
        plot(filteredData(:,1),filteredData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
    end

% ----------------------------------------------------------------------- %
%                       OUTPUT PLOT OF NORMALIZED DATA     
% ----------------------------------------------------------------------- %   
    normalizedData = zeros(size(filteredData));
    normalizedData(:,1) = filteredData(:,1);
    
    % Normalize background light seperately (not used in further
    % calculations)
    temp = filteredData(:,2);
    normalizedData(:,2) = (temp + abs(min(temp(:))))/(max(temp(:)) + abs(min(temp(:))));

    % Normalize LED 1 & 2 data
    temp = filteredData(:,3:4);
    normalizedData(:,3:4) = (temp + abs(min(temp(:))))/(max(temp(:)) + abs(min(temp(:))));

    subplot(mPlots,nPlots,[25 36]);
    hold on;
    for p = 3:4
        plot(normalizedData(:,1),normalizedData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
    end
    
% ----------------------------------------------------------------------- %
%                        FAST FOURIER TRANSFORM
%                   -> To find frequency components
% ----------------------------------------------------------------------- %   
%     % Channel 1 - FFT (single-sided)
%     subplot(mPlots,nPlots,[37 40]);
%     X=fft(filteredData(:,2));
%     plot([0:length(X)/2-1]/length(X)*FSDown,20*log10(abs(X([1:length(X)/2],1))))

    % Channel 2 - FFT (single-sided)
    subplot(mPlots,nPlots,[37 42]);
    X=fft(filteredData(:,3));
    plot([0:length(X)/2-1]/length(X)*FSDown,20*log10(abs(X([1:length(X)/2],1))))	 

    % Channel 3 - FFT (single-sided)
    subplot(mPlots,nPlots,[43 48]);
    X=fft(filteredData(:,4));
    plot([0:length(X)/2-1]/length(X)*FSDown,20*log10(abs(X([1:length(X)/2],1))))	 

%     tightfig();

    % Visualize used LP filter
    fvtool(Hd);
    %fvtool(B,A); % When using filtfilt -> sos2ft

% ----------------------------------------------------------------------- %
%                        MODIFIED BEER-LAMBERT LAW
% ----------------------------------------------------------------------- %
    time = normalizedData(:,1);
    Hb = MBLL(normalizedData(:,3:4));
    Hb(:,1:3)
    figure(4);
    hold on;
    for p = 1:3
        plot(time,Hb(:,p),'color',colorMap(p,:)) % Plot all channels in different colors
    end

    figure(6);
    X=fft(Hb(:,2));
    plot([0:length(X)/2-1]/length(X)*FSDown,20*log10(abs(X([1:length(X)/2],1))))	
    
    return; % REMOVE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% ----------------------------------------------------------------------- %
%                             CLASSIFICATION
% ----------------------------------------------------------------------- %    
    
mlData = Hb;
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