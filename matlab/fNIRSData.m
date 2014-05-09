classdef fNIRSData
    %Expects this structure: one time channel + the other data channels
    
    properties (GetAccess = 'private', SetAccess = 'private')
        channels = 0;
        wavelengths = [];
        FS = 0;
        samples = 0;
        rawData = [];
        rawTasks = [];
        FSDown = 0;
        detrendedData = [];
        downsampledData = [];
        downsampledTasks = [];
        filteredData = [];
        normalizedData = [];
        Hb = [];
        filtHd = 0;
    end
    
    properties (Hidden = true, GetAccess = 'private', SetAccess = 'private')
        filtA = 0;
        filtB = 0;
    end
    
    methods
        % Constructor       
        function obj = fNIRSData(channels,wavelengths,rawData,rawTasks)
           n = size(rawData,1);
           if(n ~= 0)
            sampleRate = n/(rawData(n,1)-rawData(1,1));
           else
            sampleRate = 0;
           end
           
           obj.channels = channels;
           obj.wavelengths = wavelengths;
           obj.FS = sampleRate;
           obj.samples = n;
           obj.rawData = rawData;
           obj.rawTasks = rawTasks;
           obj.filtHd = 0;
           obj.filtA = 0;
           obj.filtB = 0;
           obj.FSDown = 0;
           obj.detrendedData = [];
           obj.downsampledData = [];
           obj.downsampledTasks = [];
           obj.filteredData = [];
           obj.normalizedData = [];
           obj.Hb = [];
        end
        
        % Methods
        function b = store(obj)
            b.FS = obj.FS;
            b.samples = obj.samples;
            b.rawData = obj.rawData;
            b.rawTasks = obj.rawTasks;
            b.FSDown = obj.FSDown;
            b.detrendedData = obj.detrendedData;
            b.downsampledData = obj.downsampledData;
            b.downsampledTasks = obj.downsampledTasks;
            b.filteredData = obj.filteredData;
            b.normalizedData = obj.normalizedData;
            b.Hb = obj.Hb;
        end
        
        function obj = setSamplingData(obj,sampleRate,samples,rawData,rawTasks)
           obj.FS = sampleRate;
           obj.samples = samples;
           obj.rawData = rawData;
           obj.rawTasks = rawTasks;
        end
        
        function labels = getChannelLabels(obj)
            dataColumns = size(obj.rawData,2)-1; % All data channels including background measurement
            nonBackground = length(obj.wavelengths(c)); % All non-background channels
            
            labels = zeros(dataColumns);
            for c = 1:dataColumns
                if(c <= nonBackground)
                    labels(c) = {sprintf('%u nm',obj.wavelengths(c))};
                else % Remaining channel is background channel (not always present)
                    labels(c) = {'Background measurement'};
                end
            end
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
        
        function FS = getSamplingFrequency(obj)
            FS = obj.FS;
        end
        
        function [data, time] = getData(obj,type)
            time = [];
            data = [];
            switch type
                case 'raw'
                    if(size(obj.rawData,2) >= obj.channels+1)
                        time = obj.rawData(:,1);
                        data = obj.rawData(:,2:obj.channels+1);
                    end
                case 'detrended'
                    if(size(obj.detrendedData,2) >= obj.channels+1)
                        time = obj.detrendedData(:,1);
                        data = obj.detrendedData(:,2:obj.channels+1);
                    end
                case 'downsampled'
                    if(size(obj.downsampledData,2) >= obj.channels+1)
                        time = obj.downsampledData(:,1);
                        data = obj.downsampledData(:,2:obj.channels+1);
                    end
                case 'filtered'
                    if(size(obj.filteredData,2) >= obj.channels+1)
                        time = obj.filteredData(:,1);
                        data = obj.filteredData(:,2:obj.channels+1);
                    end     
                case 'normalized'
                    if(size(obj.normalizedData,2) >= obj.channels+1)
                        time = obj.normalizedData(:,1);
                        data = obj.normalizedData(:,2:obj.channels+1);
                    end
                case 'Hb'
                    if(size(obj.Hb,2) >= obj.channels+1)
                        time = obj.Hb(:,1);
                        data = obj.Hb(:,2:obj.channels+1);
                    end
            end
        end
        
       function bool = getTasksSet(obj)
           if(size(obj.rawTasks,1) > 1)
               bool = 1;
           else
               bool = 0;
           end
        end
        
        function tasks = getTasks(obj,type)
            switch type
                case 'raw'
                    tasks = obj.rawTasks;
                case 'downsampled'
                     tasks = obj.downsampledTasks;
                otherwise
                    tasks = 0;
            end
        end
        
        function channels = getNumberOfChannels(obj)
            channels = obj.channels;
        end
        
        function wavelengths = getWavelengths(obj)
            wavelengths = obj.wavelengths;
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
            %                         DETREND (REMOVE DRIFT)     
            % ----------------------------------------------------------------------- %          
            obj.detrendedData(:,1) = obj.detrendedData(:,1);
            obj.detrendedData(:,2) = detrend(obj.detrendedData(:,2));
            obj.detrendedData(:,3) = detrend(obj.detrendedData(:,3));
            obj.detrendedData(:,4) = detrend(obj.detrendedData(:,4));                                                                           
            
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
                obj.downsampledTasks = obj.rawTasks;
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
            obj.downsampledTasks = [];
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
                obj.downsampledTasks = zeros(ceil(size(obj.rawTasks,1)/resampleRatio),1);
                obj.downsampledTasks(:,1) = downsample(obj.rawTasks(:,1),resampleRatio);
            end
        end
        
        function obj = createFilter(obj)
            Fst1 = 0.001;   % Fstop (Hz)
            Fp1 = 0.01; % Fpass (Hz)
            Fp2  = 0.6; % Fpass (Hz)
            Fst2 = 0.7; % Fstop (Hz)
            % Fc = (Fp+Fst)/2;  Transition Width = Fst - Fp
            Ap  = 1; % Ripple in passband (allowed)
            Ast1 = 40;
            Ast2 = 40; % Attenuation stopband
            Fsample = obj.FSDown;

            FstHigh = 0.7;   % Fstop (Hz)
            FpHigh = 0.5; % Fpass (Hz)
            
            %D = fdesign.bandpass('Fst1,Fp1,Fp2,Fst2,Ast1,Ap,Ast2',Fst1,Fp1,Fp2,Fst2,Ast1,Ap,Ast2,Fsample);
            D = fdesign.lowpass('Fp,Fst,Ap,Ast',FpHigh,FstHigh,Ap,Ast1,Fsample);
%             % For blood tests

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
            obj.filteredData = zeros(size(obj.downsampledData));
            
            % Copy time & background channel
            obj.filteredData(:,1) = obj.downsampledData(:,1);
            obj.filteredData(:,2) = obj.downsampledData(:,2);
            
            % Data channels
            for c = 3:(2+getNumberOfChannels(obj)-1)
                obj.filteredData(:,c) = filtfilt(obj.filtB,obj.filtA,obj.downsampledData(:,c));
                obj.filteredData(:,c) = smooth(obj.filteredData(:,c));
            end
        end
        
        function [completed,obj] = processData(obj)
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
        if(tasksSet == 1)
            tasks = getTasks(obj,'raw');
        end        
        
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
            plot([0:length(X)/2-1]/length(X)*FS,20*log10(abs(X([1:length(X)/2],1))));
            hold off;
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
                tempTask = obj.downsampledTasks(1);
                for n = 1:length(obj.downsampledTasks)
                    if(tempTask ~= obj.downsampledTasks(n))
                        tempTask = obj.downsampledTasks(n); % Update temp variable
                        xValue = obj.downsampledData(n,1); % Calculate position on x-axis
                        line([xValue xValue], [min(min(obj.downsampledData(:,2:channels+1))), max(max(obj.downsampledData(:,2:channels+1)))]); % Set lines on  task switch (height equal range min - max value on data channels
                    end
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
            hold off;
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
            temp = obj.filteredData(:,3);
            obj.normalizedData(:,3) = (temp + abs(min(temp(:))))/(max(temp(:)) + abs(min(temp(:))));

            temp = obj.filteredData(:,4);
            obj.normalizedData(:,4) = (temp + abs(min(temp(:))))/(max(temp(:)) + abs(min(temp(:))));
            
            subplot(mPlots,nPlots,[25 36]);
            hold on;
            for p = 3:4
                plot(obj.normalizedData(:,1),obj.normalizedData(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
            end
            hold off;
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
            obj.Hb = zeros(size(obj.normalizedData));
        
            obj.Hb(:,1) = obj.normalizedData(:,1); % time
            obj.Hb(:,2:4) = MBLL(obj.normalizedData(:,3:4));
            figure(4);
            hold on;
            for p = 2:4              
                plot(obj.Hb(:,1),obj.Hb(:,p),'color',colorMap(p-1,:)) % Plot all channels in different colors
            end
            hold off;
            figure(6);
            X=fft(obj.Hb(:,2));
            plot([0:length(X)/2-1]/length(X)*obj.FSDown,20*log10(abs(X([1:length(X)/2],1))))	

        % ----------------------------------------------------------------------- %
        %                             CLASSIFICATION
        % ----------------------------------------------------------------------- %    

%         mlData = obj.Hb(:,2:4);
%         Machine_learning(mlData,obj.downsampledTasks)

        completed = 1;

        end
    end
end

