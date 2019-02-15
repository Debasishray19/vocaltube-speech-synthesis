% This code implements the following paper to illustrate the tube cross
% sectional area for the vowel sound - /i/
% Comparision of Magnetic resonance Imaging-Based vocal tract area function
% obtained from the same speaker in 1994 and 2002.

% We will be using 44 sections to generate the tube length
% Important: Sectional Length is different from spatial resolution (dx)

function [listenerX, listenerY, PV_N]...
         = eeCrossSectionTube(frameH, frameW, ds, cell_wall, cell_air, cell_excitation, cell_noPressure)
    
    % Define units
    meter = 1;
    centimeter = 1e-2*meter;
    
    % Intialize the variable 
    % Here PV_N will be used to store the cell type.
    % So, before defining any cells as cell_wall, intialize all the grid
    % cells as cell_air whose value is 1.
    PV_N(1:frameH, 1:frameW)  = cell_air;
    sectional_length = 0.00384; % in meter
    numSections = 44;
    
    % Tube section area in cm^2
    tubeSectionArea_incm2= [0.51 0.59 0.62 0.72 ...
                            1.24 2.30 3.30 3.59 ...
                            3.22 2.86 3.00 3.61 ...
                            4.39 4.95 5.17 5.16 ...
                            5.18 5.26 5.20 5.02 ...
                            4.71 4.13 3.43 2.83 ...
                            2.32 1.83 1.46 1.23 ...
                            1.08 0.94 0.80 0.67 ...
                            0.55 0.46 0.40 0.36 ...
                            0.35 0.35 0.38 0.51 ...
                            0.74 0.92 0.96 0.91];
    
    % Tube section area in m^2
    tubeSectionArea_inm2 = tubeSectionArea_incm2.*(centimeter*centimeter);
    
    % Tube section diameter
    tubeSectionDiameter = 2*sqrt(tubeSectionArea_inm2./pi);
    
    % Tube section diameter in terms of number of grid cell
    tubeSectionDiameterCells = round(tubeSectionDiameter./ds);
    
    % Change the tube diameter to 1 if it contains 0
    tubeSectionDiameterCells(tubeSectionDiameterCells==0)=1;
    
    %STEP1: Choose the best possible odd number from the Diameter array
    for diameterCounter = 1:numSections       
        % Verify if the cellsPerDiameter is odd or not
        if mod(tubeSectionDiameterCells(diameterCounter), 2) == 0
            
            % Find the difference between rounded and actual diameter value
            diff = tubeSectionDiameterCells(diameterCounter) - ...
                    (tubeSectionDiameter(diameterCounter)/ds);            
            
            if diff>0
                tubeSectionDiameterCells(diameterCounter) = ...
                    tubeSectionDiameterCells(diameterCounter)-1;
            else
                tubeSectionDiameterCells(diameterCounter)=...
                    tubeSectionDiameterCells(diameterCounter)+1;
            end
        end   
    end
       
    % STEP2: Find the total tube length and calculate the percentage error 
    % in the approximated tube length

    % Number of cells for total tube length
    actualTubeLength = 44*sectional_length;
    totalTubeLengthinCells = round(actualTubeLength/ds);
    approxTubeLength = totalTubeLengthinCells*ds;
    
    % Percentage error in total tube length
    totalTubeLengthError = abs(actualTubeLength - approxTubeLength)/...
                           (actualTubeLength);
    fprintf('Error percentage in approximated tube length = %.4f \n',totalTubeLengthError*100);
        
    % STEP2: Find the mid point in the frame
    midY = floor(frameH/2);
    midX = floor(frameW/2);
    
    % STEP3: Find the glottal end: Starting point of the tube
    tubeStartX = midX - round(totalTubeLengthinCells/2);
    tubeStartY = midY;
    tubeEndX   = tubeStartX + totalTubeLengthinCells-1;
    tubeEndY   = midY;
    
    % STEP4: Store the cummulative length of each tube section
    tubeCummSectionLength = zeros(1, numSections);
    for sectionCount = 1:numSections
        if sectionCount == 1
           tubeCummSectionLength(sectionCount) =  sectional_length;
        else
            tubeCummSectionLength(sectionCount) = sectional_length + tubeCummSectionLength(sectionCount-1);
        end
    end
    
    % STEP5: Draw the geometrical shape of the tube
    % Set a counter to traverse through tubeCummSectionLength
    sectionCounter = 1;
    
    % To join the walls along the vertical direction if there is gap.
    prevUpperY = 0;
    prevUpperX = 0;
    prevLowerY = 0;
    prevLowerX = 0;
    
    for tubeCellsCount = 1:totalTubeLengthinCells
        
        % Check the current length
        currTubeLength = tubeCellsCount*ds;
        
        % We are subtracting 1 as we'll assume that there is a middle
        % row of cells which will act like a morror.
        getRadius = (tubeSectionDiameterCells(sectionCounter)-1)/2;
            
        % Find the upper and lower wall coordinates
        upperX = tubeStartX + (tubeCellsCount-1);
        upperY = tubeStartY - getRadius - 1;           
        lowerX = tubeStartX + (tubeCellsCount-1);
        lowerY = tubeStartY + getRadius + 1;
        
        % Verify if the currTubeLength is more than the tubeCummSectionLength
        % for the current section counter
        
        % if small or equal then set the tube wall as expected-Normal Case
        if currTubeLength <= tubeCummSectionLength(sectionCounter)            
            % set the upper wall & lower wall
            PV_N(upperY, upperX) = cell_wall;
            PV_N(lowerY, lowerX) = cell_wall;
        else
        % If the currTubeLength is greater than the actual tubeCummSectionLength
            % Find the difference between currTubeLength and tubeCummSectionLength
            diffLength = currTubeLength - tubeCummSectionLength(sectionCounter);
            
            if diffLength>0.5 && sectionCounter~=numSections
                % Increase the section counter
                sectionCounter = sectionCounter+1;
                
                % Get the radius for that cross-section
                getRadius = (tubeSectionDiameterCells(sectionCounter)-1)/2;
                
                % Find the upper and lower wall coordinates
                upperX = tubeStartX + (tubeCellsCount-1);
                upperY = tubeStartY - getRadius - 1;           
                lowerX = tubeStartX + (tubeCellsCount-1);
                lowerY = tubeStartY + getRadius + 1;
                
                % Set the upper and lower wall
                PV_N(upperY, upperX) = cell_wall;
                PV_N(lowerY, lowerX) = cell_wall;
            else
                % Set the upper and lower wall
                PV_N(upperY, upperX) = cell_wall;
                PV_N(lowerY, lowerX) = cell_wall;
                
                % And then increase the section Counter
                sectionCounter = sectionCounter+1;
            end            
        end  % End of checking currTubeLength and tubeCummSectionLength
                
        % Find the difference in prevUpperY and current upperY
        differYwall = upperY - prevUpperY;
        if tubeCellsCount~=1
            if differYwall>1
                % Set upper wall
                PV_N(prevUpperY:upperY, upperX) = cell_wall;
                
                % Set lower wall
                PV_N(lowerY:prevLowerY, lowerX) = cell_wall;
            elseif differYwall < -1
                % Set upper wall
                PV_N(upperY:prevUpperY, prevUpperX) = cell_wall;
                
                % Set lower wall
                PV_N(prevLowerY:lowerY, prevLowerX) = cell_wall;
            end
        end
        
        prevUpperY = upperY;
        prevUpperX = upperX;
        prevLowerY = lowerY;  
        prevLowerX = lowerX;
    end % End of For loop
    
    % Set the source
    getRadius = (tubeSectionDiameterCells(1)-1)/2;
    
    excitationXstart = tubeStartX-1;
    excitationXend   = excitationXstart;
    
    excitationYstart = tubeStartY - getRadius;
    excitationYend   = tubeStartY + getRadius;
    
    PV_N(excitationYstart:excitationYend, excitationXstart:excitationXend) = ...
         cell_excitation;
    
    % Set the cells just above the source as the cell_wall
    PV_N(excitationYstart-1,excitationXstart) = cell_wall;
    PV_N(excitationYend+1,excitationXstart) = cell_wall;
    
    % Set the noPressure cell
    getRadius = (tubeSectionDiameterCells(44)-1)/2;
    
    noPressureXstart  = tubeEndX+1;
    noPressureXend    = noPressureXstart;
    noPressureYstart  = tubeEndY - getRadius -1;
    noPressureYend    = tubeEndY + getRadius +1;
    
    PV_N(noPressureYstart:noPressureYend, noPressureXstart:noPressureXend) = ...
         cell_noPressure;
     
    % Set the listener
    listenerX = tubeEndX;
    listenerY = tubeEndY;   
end