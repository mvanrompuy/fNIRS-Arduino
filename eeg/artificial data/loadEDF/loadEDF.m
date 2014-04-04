function [header, signal] = loadEDF( fileName )
%loadEDF load EDF(+) files
%   EDF specification:  http://www.edfplus.info/specs/edf.html
%   EDF+ specification: http://www.edfplus.info/specs/edfplus.html

[fid, msg] = fopen(fileName,'r');

if fid == -1
    error(msg)
end

try
    %Header
    idCode = strtrim(fread(fid,8,'*char')');
    
    if ~strcmp(idCode, '0')
        error('Bad edf(+) format');
    end
    
    header.subjectId = strtrim(fread(fid,80,'*char')');
    header.recordingId = strtrim(fread(fid,80,'*char')');
    header.startDate = strtrim(fread(fid,8,'*char')');
    header.startTime = strtrim(fread(fid,8,'*char')');
    header.bytesInHeader = str2double(strtrim(fread(fid,8,'*char')'));
    header.formatVersion = strtrim(fread(fid,44,'*char')');
    header.numberOfRecords = str2double(strtrim(fread(fid,8,'*char')'));
    header.durationOfRecords = str2double(strtrim(fread(fid,8,'*char')'));
    header.numberOfChannels = str2double(strtrim(fread(fid,4,'*char')'));

    %Channels info
    header.channelLabels = strtrim(readBulkASCII(fid, 16, header.numberOfChannels));
    header.transducerTypes = strtrim(readBulkASCII(fid, 80, header.numberOfChannels));
    header.dimensions = strtrim(readBulkASCII(fid, 8, header.numberOfChannels));
    header.minInUnits = readBulkDouble(fid, 8, header.numberOfChannels);
    header.maxInUnits = readBulkDouble(fid, 8, header.numberOfChannels);
    header.digitalMin = readBulkDouble(fid, 8, header.numberOfChannels);
    header.digitalMax = readBulkDouble(fid, 8, header.numberOfChannels);
    header.prefilterings = strtrim(readBulkASCII(fid, 80, header.numberOfChannels));
    header.numberOfSamples = readBulkDouble(fid, 8, header.numberOfChannels);
    
    %reserved information, should be throwed
    fread(fid, 32*header.numberOfChannels); 
    
    annotationIndex = -1;
    if strfind(header.formatVersion, 'EDF+') == 1     
        for i = 1:header.numberOfChannels
            if strcmp(header.channelLabels(i), 'EDF Annotations')
				annotationIndex = i;
            end
        end 
        if annotationIndex ~= -1
            annotationData = zeros(header.numberOfRecords * header.numberOfSamples{annotationIndex}, 1);
        end
    end
    
    %Signal parsing
    signal = cell(header.numberOfChannels, 1);
    unitsInDigit = zeros(header.numberOfChannels, 1);
    zeroInUnits = zeros(header.numberOfChannels, 1);
    for i = 1:header.numberOfChannels
        signal{i} = zeros(header.numberOfRecords * header.numberOfSamples{i}, 1);
        unitsInDigit(i) = (header.maxInUnits{i} - header.minInUnits{i}) / (header.digitalMax{i} - header.digitalMin{i});
        zeroInUnits(i) = header.maxInUnits{i} - unitsInDigit(i) * header.digitalMax{i};
    end
    
    for i = 1:header.numberOfRecords
        for j = 1:header.numberOfChannels
            if j == annotationIndex
                data = fread(fid, header.numberOfSamples{j}*2, '*int8');
                for k = 1:length(data)
                    annotationData(header.numberOfSamples{j} * 2 * (i - 1) + k) = data(k);
                end
            else
                s = signal{j};
                data = fread(fid, header.numberOfSamples{j}, 'short');
                for k = 1:header.numberOfSamples{j}
                    s(header.numberOfSamples{j} * (i - 1) + k) = data(k) * unitsInDigit(j) + zeroInUnits(j);
                end
                signal{j} = s;
            end
        end
    end
    
    %Annotation reading
    if annotationIndex ~= -1
        %remove annotated signal
        header.numberOfChannels = header.numberOfChannels - 1;
		header.channelLabels(annotationIndex) = [];
        header.transducerTypes(annotationIndex) = [];
        header.dimensions(annotationIndex) = [];
        header.minInUnits(annotationIndex) = [];
        header.maxInUnits(annotationIndex) = [];
        header.digitalMin(annotationIndex) = [];
        header.digitalMax(annotationIndex) = [];
        header.prefilterings(annotationIndex) = [];
        
        signal(annotationIndex) = [];
        
        %parse annotationData
        j = 1;
        onSetIndex = 1;
        durationIndex = -1;
        annotationIndex = -2;
        endIndex = -3;
        for i = 1:length(annotationData) - 1
            if annotationData(i) == 21
                durationIndex = i;
            elseif annotationData(i) == 20 && onSetIndex > annotationIndex
                annotationIndex = i;
            elseif annotationData(i) == 20 && annotationData(i + 1) == 0
                endIndex = i;
            elseif annotationData(i) ~= 0 && onSetIndex < endIndex
                if durationIndex > onSetIndex
                    annotation.onSet = strtrim(char(annotationData(onSetIndex:durationIndex - 1))');
                    annotation.duration  = strtrim(char(annotationData(durationIndex:annotationIndex  - 1))');
                else
                    annotation.onSet = strtrim(char(annotationData(onSetIndex:annotationIndex - 1))');
					annotation.duration = '';
                end
                annotation.annotation = strtrim(char(annotationData(annotationIndex:endIndex - 1))'); 
                header.annotations(j) = annotation;
                onSetIndex = i;
                j = j + 1;
            end
        end
    end
    
catch e
    fclose(fid);
    rethrow(e);
end

fclose(fid);
end

function result = readBulkDouble(fid, size, length)
    result = cell(length, 1);
    for i = 1:length
        result{i} = str2double(strtrim(fread(fid, size ,'*char')'));
    end
end

function result = readBulkASCII(fid, size, length)
    result = cell(length, 1);
    for i = 1:length
        result{i} = strtrim(fread(fid, size ,'*char')');
    end
end

