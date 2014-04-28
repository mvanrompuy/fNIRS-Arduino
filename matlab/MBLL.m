% https://www.biopac.com/Manuals/fnirsoft%20user%20manual.pdf
% http://omlc.ogi.edu/spectra/hemoglobin/moaveni.html
% http://omlc.ogi.edu/news/jan98/wray.html
% http://iopscience.iop.org/0031-9155/40/2/007/pdf/0031-9155_40_2_007.pdf
% http://otg.downstate.edu/Publication/PiperNI14.pdf
% Calculation: http://www.omicsonline.org/parallel-effect-of-nicotine-and-mk-on-brain-metabolism-an-in-vivo-non-invasive-nearinfrared-spectroscopy-analysis-in-rats-2332-0737.1000101.pdf
% Calculation: % http://www.jneuroengrehab.com/content/10/1/4
% Phantom http://europepmc.org/articles/PMC3866520/reload=0;jsessionid=ZnBLipWoV28gJGvEVox6.6
% Artificial fNIRS data: http://www.academia.edu/766759/Functional_Near_Infrared_Spectroscopy_fNIRS_synthetic_data_generation#

% CODE: https://mail.nmr.mgh.harvard.edu/pipermail//homer-users/2006-July/000124.html

% Differential pathlength factor: http://iopscience.iop.org/0031-9155/47/12/306/pdf/0031-9155_47_12_306.pdf
% MBLL: http://bisp.kaist.ac.kr/lectures/BiS351_09Spring/BiS351_HW4.pdf

% TO READ: http://books.google.be/books?id=MEtHw5gJDQ8C&pg=PA346&lpg=PA346&dq=modified+beer+lambert+law+code&source=bl&ots=KpCCJVTcmt&sig=q_vfnq7Sg-ACNNkI0-cywUBTdzw&hl=nl&sa=X&ei=YtEhU86aKtPX7Aa-joGQBg&ved=0CGsQ6AEwBQ#v=onepage&q=modified%20beer%20lambert%20law%20code&f=false
            % http://books.google.be/books?id=mBBYKllGwZYC&pg=PA143&lpg=PA143&dq=modified+beer+lambert+law+code&source=bl&ots=o5Sj6VYPe2&sig=M-1yJDr7IIZuLcpEYp_NFfzQ-dI&hl=nl&sa=X&ei=YtEhU86aKtPX7Aa-joGQBg&ved=0CH4Q6AEwCA#v=onepage&q=modified%20beer%20lambert%20law%20code&f=false
% Modified Beer Lambert Law
% Calculate changes in concentration of chromophores by doing baseline
% measurement (rest) and one during activity.


function Hb = MBLL(dataArray)

% VARIABLES

% Test arrays
% dataArray = [0.1 0.1 0.2 0.3;
%               0.2 0.4 0.5 0.6;
%               0.3 0.7 0.8 0.9]

% Wavelength 1 = 765 nm (trough-hole LED)
% Wavelength 5 = 850 nm (SMD LED)

% Extinction coefficients (cm mM)^?1 from HOMER, GetExtinctions.m (earlier used these:
% ExHbO1 = 645.5;
% ExHbR1 = 1669.0;
% ExHbO2 = 1097.0;
% ExHbR2 = 781.0;
% from http://otg.downstate.edu/Publication/PiperNI14.pdf)

% GetExtinctions.m file (HOMER application)

ext = GetExtinctions([765,850]);

ExHbO1 = ext(1,1);
ExHbR1 = ext(1,2);
ExHbO2 = ext(2,1);
ExHbR2 = ext(2,2);

% Wavelength-specific differential pathlength-factors array (from
% http://otg.downstate.edu/Publication/PiperNI14.pdf)
DPF1 = 7.15;
DPF2 = 5.98;

lp = 3.5 % Source detector distance in cm (measurement geometry -> chord distance)? 

% CALCULATION

extCoef = [ExHbO1 ExHbR1; ExHbO2 ExHbR2]        % Extinction coefficients array

deltaODArray = zeros(size(dataArray));
dataArray = dataArray + 0.5; % Move from [0 1] to [0.5 1.5] to avoid log(0) (undefined)

% for i = 1:size(dataArray,1)-1 % Rows
%     for j = 2:size(dataArray,2) % Columns (containing measurements)
%         tNow = dataArray(i,j);
%         tNext = dataArray(i+1,j);
%         deltaODArray(i,j) = -log(tNext/tNow); % Calculate and store delta OD
%     end
% end
% dataArray
for i = 1:size(dataArray,1)-1 % Rows
    for j = 1:size(dataArray,2) % Columns (containing measurements)
        deltaODArray(i,j) = -log(dataArray(i,j)/mean(dataArray(:,j))); % Calculate and store delta OD
    end
end
% deltaODArray

% Based on https://mail.nmr.mgh.harvard.edu/pipermail//homer-users/2006-July/000124.html

deltaODArray(:,1) = deltaODArray(:,1)/(lp*DPF1);
deltaODArray(:,2) = deltaODArray(:,2)/(lp*DPF2);

extInv = inv(extCoef'*extCoef)*extCoef'; %Linear inversion operator

% Sum temporal changes to get time course -> NEEDED OR NOT?
for j = 1:size(deltaODArray,2) % Columns (containing measurements)
    temp = 0;
    for i = 1:size(deltaODArray,1) % Rows
        deltaODArray(i,j) = temp + deltaODArray(i,j);
        temp = deltaODArray(i,j);
    end
end

Hb = extInv*deltaODArray(:,1:2)'; % Find HbO and HbR
HbT = Hb(1,:) + Hb(2,:);

Hb = [Hb',HbT'];

% processed = temporalChanges;

% HbR
% HbO
% HbTotal = HbR - HbR

% Processing steps: LP filtered (0.8 Hz), normalize data, HP (0.01 Hz),
% negative ln
% (http://www.academia.edu/766759/Functional_Near_Infrared_Spectroscopy_fNIRS_synthetic_data_generation#)
