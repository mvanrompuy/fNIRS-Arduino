classdef fNIRSData
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (GetAccess = 'private', SetAccess = 'private')
        FS = 0;
        samples = 0;
        rawData = [];
        rawTasks = [];
        FSDown = 0;
        detrendedData = [];
        downsampledData = [];
        downsampledTask = [];
        filteredData = [];
        normalizedData = [];
        Hb = [];
    end
    
    properties (Hidden = true, GetAccess = 'private', SetAccess = 'private')
        filtHd = 0;
        filtA = 0;
        filtB = 0;
    end
    
    methods
        % Constructor       
        function obj = fNIRSData(sampleRate,samples,rawData,rawTasks)
           obj.FS = sampleRate;
           obj.samples = samples;
           obj.rawData = rawData;
           obj.rawTasks = rawTasks;
           obj.filtHd = 0;
           obj.filtA = 0;
           obj.filtB = 0;
           obj.FSDown = 0;
           obj.detrendedData = [];
           obj.downsampledData = [];
           obj.downsampledTask = [];
           obj.filteredData = [];
           obj.normalizedData = [];
           obj.Hb = [];
        end
        
        % Methods
        function obj = setSamplingData(obj,sampleRate,samples,rawData,rawTasks)
           obj.FS = sampleRate;
           obj.samples = samples;
           obj.rawData = rawData;
           obj.rawTasks = rawTasks;
        end
        
        function [sampledData,sampledTasks,samples,channels,FS,tasksSet] = getSamplingData(obj)
            sampledData = obj.rawData;
            sampledTasks = obj.rawTasks;
            samples = obj.samples;
            channels = size(sampledData,2)-1;
            FS = obj.FS;
            tasksSet = getTasksSet(obj);
        end
        
        function samples = getNumberOfSamples(obj)
            samples = obj.samples;
        end
        
        function channels = getNumberOfChannels(obj)
            columns = size(obj.rawData,2);
            if(columns > 0)
                channels = size(obj.rawData,2)-1;
            else % Sampling not run yet
                channels = -1;
            end
        end
        
        function bool = getTasksSet(obj)
           if(size(obj.rawTasks,1) > 1)
               bool = 1;
           else
               bool = 0;
           end
        end
        
        function [bool,obj,msg] = preProcess(obj,resampleRatio)
            % ----------------------------------------------------------------------- %
            %                         REMOVE BACKGROUND LIGHT     
            % ----------------------------------------------------------------------- %
            obj.detrendedData = zeros(size(obj.rawData));
            
            obj.detrendedData(:,1:2) = obj.rawData(:,1:2);
            obj.detrendedData(:,3) = obj.rawData(:,3) - mean(obj.rawData(:,2));
            obj.detrendedData(:,4) = obj.rawData(:,4) - mean(obj.rawData(:,2));                                                                

            % ----------------------------------------------------------------------- %
            %                         DOWNSAMPLE DATA     
            % ----------------------------------------------------------------------- %
            minSamples = 3*8; % Default filter order of decimate = 8.
            if(resampleRatio > 1)
                if(ceil(size(obj.rawData,1)/resampleRatio) > minSamples)
                    msg = '';
                    obj = downsampleData(obj,'detrended',getNumberOfChannels(obj),resampleRatio);
                else
                    bool = 0;
                    msg = sprintf('Warning: provide at least %u samples of input data or decrease resample ratio to enable downsampling of data!',minSamples*resampleRatio+1);
                    return;
                end
            else % No downsampling
                obj.downsampledData = obj.rawData;
                obj.FSDown = obj.FS;
            end

            % ----------------------------------------------------------------------- %
            %                         CREATE FILTER     
            % ----------------------------------------------------------------------- %  
            obj = createFilter(obj);

            % ----------------------------------------------------------------------- %
            %                      CHECK IF PROCESSABLE  
            %
            % Check if enough samples have been captured to run ther filter and
            % if the filter coefficients are set.
            % ----------------------------------------------------------------------- % 

            nmbr = max(numel(obj.filtA),numel(obj.filtB));
            minSamples = 3*((nmbr-1));
            if(ceil(size(obj.rawData,1)/resampleRatio) > minSamples)
                bool = 1;
                msg = '';
            else
                bool = 0;
                msg = sprintf('Warning: provide at least %u samples of input data or decrease resample ratio to enable processing of data!',minSamples*resampleRatio+1);
            end
        end
        
        function obj = downsampleData(obj,dataSource,channels,resampleRatio)
            obj.downsampledData = zeros(ceil(obj.samples/resampleRatio),channels+1);
            obj.downsampledTask = [];
            
            switch dataSource
               case 'raw'
                    for c = 1:channels+1
                        obj.downsampledData(:,c) = decimate(obj.rawData(:,c),resampleRatio);
                    end
                case 'detrended'                    
                    for c = 1:channels+1
                        obj.downsampledData(:,c) = decimate(obj.detrendedData(:,c),resampleRatio);
                    end
            end
            
            % Downsampled signal sampling frequency
            lastIndex = size(obj.downsampledData,1);
            TDownavg = (obj.downsampledData(lastIndex,1)-obj.downsampledData(1,1))/(length(obj.downsampledData)); % Sampling time (converted to seconds)
            obj.FSDown = 1/TDownavg;  %Sampling frequency of each channel (=> Real frequency = fs*channels)            

            if(getTasksSet(obj) == 1)
                obj.downsampledTask = zeros(ceil(size(data,1)/resampleRatio),1);
                obj.downsampledTask(:,1) = downsample(obj.sampledTask(:,1),resampleRatio);
            end
        end
        
        function obj = createFilter(obj)
            Fst1 = 0.001;   % Fstop (Hz)
            Fp1 = 0.01; % Fpass (Hz)
            Fp2  = 0.5; % Fpass (Hz)
            Fst2 = 0.7; % Fstop (Hz)
            % Fc = (Fp+Fst)/2;  Transition Width = Fst - Fp
            Ap  = 1; % Ripple in passband (allowed)
            Ast1 = 40;
            Ast2 = 40; % Attenuation stopband
            Fsample = obj.FSDown;

            D = fdesign.bandpass('Fst1,Fp1,Fp2,Fst2,Ast1,Ap,Ast2',Fst1,Fp1,Fp2,Fst2,Ast1,Ap,Ast2,Fsample);
            obj.filtHd = design(D,'butter');
            [obj.filtB,obj.filtA] = sos2tf(obj.filtHd.sosMatrix,obj.filtHd.ScaleValues); % When using filtfilt -> Can give wrong filter characteristics due to numerical errors
        end
        
        function [A,B] = getFilterCoefficients(obj)
            A = obj.filtA;
            B = obj.filtB;
            measure(obj.filtHd) % Return performance of filter
                        %     zplane(B,A) % To check stability of filter
        end
        
        function obj = filter(obj)
            % Copy time & background channel
            obj.filteredData(:,1) = obj.downsampledData(:,1);
            obj.filteredData(:,2) = obj.downsampledData(:,2);
            
            % Data channels
            for c = 3:(2+getNumberOfChannels(obj)-1)
                obj.filteredData(:,c) = filtfilt(obj.filtB,obj.filtA,obj.downsampledData(:,c));
                obj.filteredData(:,c) = filtfilt(obj.filtB,obj.filtA,obj.downsampledData(:,c));
            end
        end
        
        function completed = processData(obj)
        % ----------------------------------------------------------------------- %
        %                              VARIABLES
        % ----------------------------------------------------------------------- %

        completed = 0; % 0: not complete, 1: completed, -1: error

        % Subplots matrix dimensions
        mPlots = 4; % Rows
        nPlots = 12; % Columns

        % ----------------------------------------------------------------------- %
        %                            GET DATA
        % ----------------------------------------------------------------------- %

        [sampledData,sampledTasks,samples,channels,FS,tasksSet] = getSamplingData(obj);

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
        %               OUTPUT PLOT OF DOWNSAMPLED (AVERAGED) DATA     
        % ----------------------------------------------------------------------- %
            subplot(mPlots,nPlots,[13 18]);
            hold on;
            for p = 3:4
                plot(obj.downsampledData(:,1),obj.downsampledData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
            end

            if(tasksSet == 1)
                xValue = 0;
                for n = 1:amountTasks
                    xValue = xValue + tasks(n,2);
                    line([xValue xValue], [min(min(obj.downsampledData(:,2:channels+1))) max(max(obj.downsampledData(:,2:channels+1)))]); % Set lines on  task switch (height equal range min - max value on data channels
                end
            end

        % ----------------------------------------------------------------------- %
        %                                  FILTERING     
        % ----------------------------------------------------------------------- %
        
            obj = filter(obj);     

            subplot(mPlots,nPlots,[19 24]);
            hold on;
            for p = 3:4
                plot(obj.filteredData(:,1),obj.filteredData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
            end

        % ----------------------------------------------------------------------- %
        %                       OUTPUT PLOT OF NORMALIZED DATA     
        % ----------------------------------------------------------------------- %   
            obj.normalizedData = zeros(size(obj.filteredData));
            obj.normalizedData(:,1) = obj.filteredData(:,1);

            % Normalize background light seperately (not used in further
            % calculations)
            temp = obj.downsampledData(:,2);
            obj.normalizedData(:,2) = (temp + abs(min(temp(:))))/(max(temp(:)) + abs(min(temp(:))));

            % Normalize LED 1 & 2 data
            temp = obj.filteredData(:,3:4);
            obj.normalizedData(:,3:4) = (temp + abs(min(temp(:))))/(max(temp(:)) + abs(min(temp(:))));

            subplot(mPlots,nPlots,[25 36]);
            hold on;
            for p = 3:4
                plot(obj.normalizedData(:,1),obj.normalizedData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
            end

        % ----------------------------------------------------------------------- %
        %                        FAST FOURIER TRANSFORM
        %                   -> To find frequency components
        % ----------------------------------------------------------------------- %   

            % Channel 2 - FFT (single-sided)
            subplot(mPlots,nPlots,[37 42]);
            X=fft(obj.filteredData(:,3));
            plot([0:length(X)/2-1]/length(X)*obj.FSDown,20*log10(abs(X([1:length(X)/2],1))))	 

            % Channel 3 - FFT (single-sided)
            subplot(mPlots,nPlots,[43 48]);
            X=fft(obj.filteredData(:,4));
            plot([0:length(X)/2-1]/length(X)*obj.FSDown,20*log10(abs(X([1:length(X)/2],1))))	 

        %     tightfig();

            % Visualize used LP filter
            fvtool(obj.filtHd);
            %fvtool(B,A); % When using filtfilt -> sos2ft

        % ----------------------------------------------------------------------- %
        %                        MODIFIED BEER-LAMBERT LAW
        % ----------------------------------------------------------------------- %
            obj.Hb(:,1) = obj.normalizedData(:,1); % time
            obj.Hb(:,2:4) = MBLL(obj.normalizedData(:,3:4));
            obj.Hb(:,1:4)
            figure(4);
            hold on;
            for p = 2:4              
                plot(obj.Hb(:,1),obj.Hb(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
            end

            figure(6);
            X=fft(obj.Hb(:,2));
            plot([0:length(X)/2-1]/length(X)*obj.FSDown,20*log10(abs(X([1:length(X)/2],1))))	

            return; % REMOVE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        % ----------------------------------------------------------------------- %
        %                             CLASSIFICATION
        % ----------------------------------------------------------------------- %    

        mlData = obj.Hb(:,2:4);
        Machine_learning(mlData,obj.downsampledTask)

        % ----------------------------------------------------------------------- %
        %                           SAVE ALL VARIABLES TO FILE
        % ----------------------------------------------------------------------- %    

        % save(datestr(now,'yyyymmdd_HHMMSS_fNIRS_VAR'))
        end
    end
end

