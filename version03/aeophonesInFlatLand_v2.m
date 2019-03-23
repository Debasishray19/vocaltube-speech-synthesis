% Author: Debasish Ray Mohapatra
% Date: 20 March, 2019
% A special thanks to Victor Zappi who helped me to understand and
% implement this code. To visit Victor Zappi's website: http://toomuchidle.com/

% Source Implementation
% To implement Sinusoidal wave or Impulse source, use: excitationV
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% INITIALIZE MATLAB ENVIRONMENT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
close all; 
clear;
clc;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DEFINE UNITS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
meter = 1;
centimeter  =1e-2 * meter;

second    = 1;
milisecond = 1e-3 * second;
hertz     = 1/second;
kilohertz = 1e3 * hertz;
megahertz = 1e6 * hertz;
gigahertz = 1e9 * hertz;

gram      = 1e-3;
kilogram  = 1e3*gram;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DEFINE CONSTANTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Toggle this variable to switch to 2.5D
% if set2D=1, then the 2D simulator will run otherwise 2.5D
simulation2D = input('Enter 1 for 2D simulation or 0 for 2.5D simulation: ');
rho = 1.140*kilogram/(meter^3);   % Air density  [kg/m^3]
srate_mul = input('Enter the sample rate multiplier: ');                     % srate multiplier
c   = 350*meter/second;            % Sound speed in air [m/s]
maxSigmadt = 0.5;                  % Attenuation coefficient at the PML layer
alpha = 0.008;                     % Reflection coefficient
srate = 44100*srate_mul;           % Sample frequency
z_inv = 1 / (rho*c*( (1+sqrt(1-alpha))/(1-sqrt(1-alpha)) ));
pmlLayer = 6; % Number of PML layers

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DASHBOARD
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dt = 1/srate;                      % Temporal resolution/ sample time period
dx = dt*c*sqrt( 2.0 );             % Spatial resolution along x-direction: CFL Condition
dy = dt*c*sqrt( 2.0 );             % Spatial resolution along x-direction: CFL Condition
AudioTime = 50*milisecond;         % Total audio signal time
kappa = rho*c*c;                   % Bulk modulus
ds = dx;                           % Spatial resolution(ds) = dx = dy

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SIMULATION TIME
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
t = 0:dt:AudioTime-dt;            % time steps
STEPS = length(t);                % Total time steps
Pr_Audio = zeros(1, STEPS);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SOURCE PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
excitationF = 440;        % Source frequency      
srcAmplitude =25;
exeT = linspace(1, STEPS, STEPS);
% excitationV = srcAmplitude * sin(2*pi*excitationF*dt*(exeT(:)-1));
excitationV = impulseResponse(srate, 10000, 2, 22000);

% Define source propagation direction
% srcDirection index mean: 1 = Left  = -1
%                          2 = Down  = -1
%                          3 = Right = 1
%                          4 = Up    = 1

srcDirection = [0 0 1 0]; % For all the direction

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DEFINE CELL TYPE [Not going to use 'cell_dynamics']
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cell_wall       = 0;
cell_air        = 1;
cell_excitation = 2;
% Note: This need to be changed - Number of PML layers as a variable(Is it necessary??)
cell_pml0       = 3;
cell_pml1       = 4;
cell_pml2       = 5;
cell_pml3       = 6;
cell_pml4       = 7;
cell_pml5       = 8;
cell_dynamic    = 9;
cell_dead       = 10;
cell_noPressure = 11; % To implement Dirichlet boundary condition
cell_numTypes   = 12;

vis_Boundary = 2000;
sigmadt = zeros(pmlLayer, 1);

% To store beta(tube wall) and sigmaPrimedt(PML Layers). 
% Beta for air & PMLLayers = 1 and for tubewall = 0
% sigmaPrimedt = sigmaPrime*dt
% sigmaPrime = 1 - Beta + Sigma
% e.g - 
% WALL -> beta = 0, sigma_prima*dt = (1-0)*dt = 1*dt = dt 
% AIR  -> beta = 1, sigma_prima*dt = (1-1)*dt = 0*dt = 0
% [NOTE] - We are considering excitation cell as a special wall cell
typeValues = zeros(2, cell_numTypes);
typeValues(:, cell_wall+1) = [0, dt];
typeValues(:, cell_air+1) = [1, 0];         % air
typeValues(:, cell_noPressure+1) = [1, 0];         % air
typeValues(:, cell_excitation+1) = [0, dt]; % excitation

% Define sigma for PMLLayers 
for pmlCounter = 0:pmlLayer-1
    sigmadt(pmlCounter+1) = (pmlCounter/(pmlLayer-1)) * maxSigmadt;
    typeValues(:, cell_pml0+1+pmlCounter) = [1, sigmadt(pmlCounter+1)];
end
typeValues(:, cell_dead+1)    =  [0, 1000000];  % dead cell


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SIMULATION TYPES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
simulationType = input('Choose Simulation Type[0-Open Space 1-TubeWall 2-VerticalWall 3-BothEnd OpenTube 4-VowelSound]: ');
pmlSwitch = input('Swicth ON PML Layers. Press 1:ON 0:OFF = ');

switch simulationType
    case 0 % For open air space simulation
        % domainW an domainH signifies the size of problem space
        domainW = input('Enter domain width: ');
        domainH = input('Enter domain height: ');
        
        % Create the frame
        [PV_N, frameH, frameW, depthX, depthY, depthP] = ...
         frameConstruction(domainH, domainW, pmlSwitch, pmlLayer, simulation2D);
        
        % Define cell type and store it in PV_N(,,4)
        % Declare all the cells as air by default
        PV_N(1:frameH, 1:frameW, 4) = cell_air;
        
        % Define source position
        excitationX = floor(frameW/2);  
        excitationY = floor(frameH/2);
        
        % Define source size
        excitationH = 1;
        excitationW = 1;
        
        % Define Listener postion
        listenerX = excitationX;
        listenerY = excitationY;

        % Defining source cell type
        cellType = cell_excitation;
        PV_N(excitationY+(0:excitationH-1), excitationX+(0:excitationW-1), 4) = cellType;
    
    case 1 % For fixed size tube-wall simulation
        
        % domainW an domainH signifies the size of problem space
        domainW = input('Enter domain width: ');
        domainH = input('Enter domain height: ');
        
        % Create the frame
        [PV_N, frameH, frameW, depthX, depthY, depthP] = ...
         frameConstruction(domainH, domainW, pmlSwitch, pmlLayer, simulation2D);
        
        % Define cell type and store it in PV_N(,,4)
        % Declare all the cells as air by default
        PV_N(1:frameH, 1:frameW, 4) = cell_air;
        
        % Define source position
        excitationX = floor(frameW/2);  
        excitationY = floor(frameH/2);
        
        % Define source size
        excitationH = 5;
        excitationW = 1;
        
        % Defining source cell type
        cellType = cell_excitation;
        PV_N(excitationY+(0:excitationH-1), excitationX+(0:excitationW-1), 4) = cellType;
        
        % Check tube length
        tubeLength = input('Enter tube length: ');

        % Fix listener position
        listenerX = excitationX + tubeLength-1;
        listenerY = excitationY;
        
        % To implement Dirichlet Boundary Condition define cell_type
        for i=0:excitationH+1
                PV_N(listenerY-1+i, listenerX+1, 4) = cell_noPressure;
        end
        
        %back walls
        for i=0:excitationH+1
            PV_N(excitationY-1+i, excitationX-1, 4) = cell_wall;
        end

        %tube walls
        for j=excitationX-1:listenerX
            PV_N(excitationY-1, j, 4) = cell_wall;
            PV_N(excitationY+excitationH, j, 4) = cell_wall;
        end
        
    case 2 % For vertical wall simulation
        
        % domainW an domainH signifies the size of problem space
        domainW = input('Enter domain width: ');
        domainH = input('Enter domain height: ');
        
        % Create the frame
        [PV_N, frameH, frameW, depthX, depthY, depthP] = ...
         frameConstruction(domainH, domainW, pmlSwitch, pmlLayer, simulation2D);
        
        % Define cell type and store it in PV_N(,,4)
        % Declare all the cells as air by default
        PV_N(1:frameH, 1:frameW, 4) = cell_air;
        
        % Define source position
        excitationX = floor(frameW/2);  
        excitationY = floor(frameH/2);
        
        % Define source size
        excitationH = 1;
        excitationW = 1;
        
        % Define Listener postion
        listenerX = excitationX;
        listenerY = excitationY;
        
        % Defining source cell type
        cellType = cell_excitation;
        PV_N(excitationY+(0:excitationH-1), excitationX+(0:excitationW-1), 4) = cellType;
        PV_N(excitationY-1:excitationY+20, excitationX+20, 4) = cell_wall;
        
    case 3 % Both end open tube
        
        % domainW an domainH signifies the size of problem space
        domainW = input('Enter domain width: ');
        domainH = input('Enter domain height: ');
        
        % Create the frame
        [PV_N, frameH, frameW] = frameConstruction(domainH, domainW, pmlSwitch, pmlLayer);
        
        % Define cell type and store it in PV_N(,,4)
        % Declare all the cells as air by default
        PV_N(1:frameH, 1:frameW, 4) = cell_air;
        
        % Define source position
        excitationX = floor(frameW/2);  
        excitationY = floor(frameH/2);
        
        % Defining source cell type
        cellType = cell_excitation;
        PV_N(excitationY+(0:excitationH-1), excitationX+(0:excitationW-1), 4) = cellType;
        
        % Check tube length
        tubeLength = input('Enter tube length: ');
        
        % Fix listener position
        listenerX = excitationX + tubeLength-1;
        listenerY = excitationY;
        
        % To implement Dirichlet Boundary Condition define cell_type
        for i=0:excitationH+1
                PV_N(listenerY-1+i, listenerX+1, 4) = cell_noPressure;
                %PV_N(excitationY-1+i, excitationX-1, 4) = cell_noPressure;
        end
        
        %tube walls
        for j=excitationX:listenerX
            PV_N(excitationY-1, j, 4) = cell_wall;
            PV_N(excitationY+excitationH, j, 4) = cell_wall;
        end
        
    case 4 % For vowel sound
        vowelSound = input('Choose vowels [1-\a\ 2-\u\ 3-\i\]: ');
        
        % Keep asking user enter wrong input
        while vowelSound<1 || vowelSound>3
            disp('Give correct input')
            vowelSound = input('Choose vowels [1-\a\ 2-\u\ 3-\i\]: ');
        end
              
        % Generate the Tube Shape
        [listenerX, listenerY, frameH, frameW, depthX, depthY, depthP, PV_N]= ...
             crossSectionTube_SymmetricalGeometry(pmlSwitch, ds, pmlLayer, ...
             vowelSound, simulation2D, cell_wall, cell_air, cell_excitation, cell_noPressure);     
    otherwise
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Define PML Layer Cells and Dead Cells
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Then modify as per the requirement
% Define cell_dead
PV_N(1:frameH,1,4) = cell_dead;
PV_N(1:frameH,frameW,4) = cell_dead;
PV_N(1,1:frameW,4) = cell_dead;
PV_N(frameH,1:frameW,4) = cell_dead;

if pmlSwitch == 1 
    
    % Define horizontal PML layers - Start from the outer layers
    % -----Activate horizontal PML Layers-------
    cellType = cell_pml5;
    yShift = 1;
    xStart = 2;
    xEnd = frameW-1;

    for pmlCount = 1:pmlLayer   
        for hCount = xStart:xEnd
            PV_N(yShift+pmlCount, hCount, 4) = cellType;
            PV_N(frameH-pmlCount, hCount, 4) = cellType;
        end   
        xStart = xStart+1;
        xEnd = xEnd-1;
        cellType = cellType-1;
    end

    % -----Activate vertical PML Layers-------
    cellType = cell_pml5;
    xShift = 1;
    yStart = 2;
    yEnd = frameH-1;
    for pmlCount = 1:pmlLayer
        for vCount = yStart:yEnd
            PV_N(vCount, xShift+pmlCount, 4) = cellType;
            PV_N(vCount, frameW-pmlCount, 4) = cellType;
        end

        yStart = yStart+1;
        yEnd = yEnd-1;
        cellType = cellType-1;
    end
end

% Test the frame
frame = PV_N(:, :,4);
frame(listenerY, listenerX) = -1;
imagesc(frame);
title('Frame [Domain+PML]');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CALCULATE MINBETA AND MAXSIGMA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Storing min(Beta) and max(sigmaPrimedt) - We'll use this to calculate
% velocity
minVxBeta = zeros(frameH-2,frameW-2);
minVyBeta = zeros(frameH-2,frameW-2);

maxVxSigmaPrimedt = zeros(frameH-2,frameW-2);
maxVySigmaPrimedt = zeros(frameH-2,frameW-2);

PressureSigmaPrimedt = zeros(frameH-2,frameW-2);
cellTypes = zeros(1,3);
sigma_prime_dt = zeros(1,3);
typeIndex = zeros(1,3);

% Not inclusing cell_dead type
for row_idx = 2: frameH-1
    for column_idx = 2:frameW-1
        cellTypes = [PV_N(row_idx, column_idx, 4), PV_N(row_idx, column_idx+1, 4), PV_N(row_idx-1, column_idx, 4)];
        
        % For typeIndex add 1 to cellTypes
        typeIndex = cellTypes(:)+1;
        beta(:) = typeValues(1, typeIndex);
        sigma_prime_dt(:) = typeValues(2, typeIndex);
        
        % For storing minBeta and maxSigmaPrimedt
        minVxBeta(row_idx-1, column_idx-1) = min(beta(1),beta(2));
        minVyBeta(row_idx-1, column_idx-1) = min(beta(1),beta(3));
        
        maxVxSigmaPrimedt (row_idx-1, column_idx-1) = max(sigma_prime_dt(1), sigma_prime_dt(2));
        maxVySigmaPrimedt (row_idx-1, column_idx-1) = max(sigma_prime_dt(1), sigma_prime_dt(3));
        
        PressureSigmaPrimedt(row_idx-1, column_idx-1) = ...
        typeValues(2,typeIndex(1));
    end    
end

betaVxSqr = minVxBeta.*minVxBeta;
betaVxSqr_dt_invRho = (betaVxSqr.*dt)/rho;

betaVySqr = minVyBeta.*minVyBeta;
betaVySqr_dt_invRho = (betaVySqr.*dt)/rho;

rho_sqrC_dt_invds = (kappa*dt)/dx;
% To calculate pressure we do not need to change the sigmaPrimedt
% So for each cell get the cell index and then calculate the corresponding 
% typeIndex (2,:) by adding 1

% PressureSigmaPrimedt = typeValues(2,PV_N(2:frameH-1, 2:frameW-1, 4)+1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FDTD PARAMETERS - PART II (INITIALISING FIELD)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
PV_Nplus1  = zeros(frameH, frameW, 4);
audio_Vis = zeros(frameH, frameW); % Dispaly this array during simmulation

CxVx    = zeros(frameH-2,frameW-2);
CyVy    = zeros(frameH-2,frameW-2);
CxP     = zeros(frameH-2,frameW-2);
CyP     = zeros(frameH-2,frameW-2);
Pr_next = zeros(frameH-2,frameW-2);
Vx_next = zeros(frameH-2,frameW-2);
Vy_next = zeros(frameH-2,frameW-2);

%clims = [-2000 2000];
figure;
%hImg = imagesc(PV_Nplus1(:,:,1), clims); %VIC in matlab can remove this
% title('Simulation');

for T = 1:STEPS
    
    % STEP1: Calculate (del.V) = (dVx/dx + dVy/dy)
    % CxVx = dVx/dx, where Vx = velocity along x direction
    % CyVy = dVy/dy, where Vy = velocity along y direction
    
    CxVx(1:frameH-2, 1:frameW-2)= (PV_N(2:frameH-1, 2:frameW-1,2).*depthX(2:frameH-1, 2:frameW-1)) - ...
                                  (PV_N(2:frameH-1, 1:frameW-2,2).*depthX(2:frameH-1, 1:frameW-2));
                              
    CyVy(1:frameH-2, 1:frameW-2)= (PV_N(2:frameH-1, 2:frameW-1, 3).*depthY(2:frameH-1, 2:frameW-1)) - ...
                                  (PV_N(3:frameH, 2:frameW-1, 3).*depthY(3:frameH, 2:frameW-1));
                                  
    % STEP2: Calculate Pr_next                           
    Pr_next(1:frameH-2, 1:frameW-2) = ((PV_N(2:frameH-1, 2:frameW-1, 1).*depthP(2:frameH-1, 2:frameW-1)) - ((rho_sqrC_dt_invds.*(CxVx+CyVy))))./...
                                     ((1+PressureSigmaPrimedt).*depthP(2:frameH-1, 2:frameW-1));

    % STEP3: Copy Pr_next  to PV_Nplus1
    PV_Nplus1(2:frameH-1, 2:frameW-1,1) = Pr_next(:,:);
    
    % STEP4: Implement Dirichlet Boundary Condition
    checkPresCond = PV_N(:,:,4)~=cell_noPressure;
    PV_Nplus1(:,:,1) = PV_Nplus1(:,:,1).*checkPresCond;
        
    % STEP5: Calculate Vx & Vy
    % To compute Vx we need calculate CxP = (del.P) = dPx/dx
    % To compute Vy we need calculate CyP = (del.P) = dPy/dy
    
    CxP(1:frameH-2, 1:frameW-2) = (PV_Nplus1(2:frameH-1,3:frameW,1) - PV_Nplus1(2:frameH-1,2:frameW-1,1))/dx;
    CyP(1:frameH-2, 1:frameW-2) = (PV_Nplus1(1:frameH-2,2:frameW-1,1) - PV_Nplus1(2:frameH-1,2:frameW-1,1))/dy;
    
    Vx_next(1:frameH-2, 1:frameW-2) = (minVxBeta.*PV_N(2:frameH-1,2:frameW-1,2)- (betaVxSqr_dt_invRho.*CxP));                                
    Vy_next(1:frameH-2, 1:frameW-2) = (minVyBeta.*PV_N(2:frameH-1,2:frameW-1,3)- (betaVySqr_dt_invRho.*CyP));
    
    PV_Nplus1(2:frameH-1, 2:frameW-1,2) = Vx_next(:,:);
    PV_Nplus1(2:frameH-1, 2:frameW-1,3) = Vy_next(:,:);
    
    for row_idx = 2:frameH-1
        for col_idx = 2: frameW-1
            
            cellTypes = [PV_N(row_idx, col_idx, 4), PV_N(row_idx, col_idx+1, 4), PV_N(row_idx-1, col_idx, 4)];
            typeIndex = cellTypes(:)+1;
            beta(:) = typeValues(1, typeIndex);
            
            % STEP6: Add source velocity
            % Verify the cell type is a cell_excitation or not
            is_excitation = [cellTypes(1) == cell_excitation, cellTypes(2) == cell_excitation, cellTypes(3) == cell_excitation];
            are_we_not_excitations = [ (1 - is_excitation(1)) * (1 - is_excitation(2)), (1 - is_excitation(1)) * (1 - is_excitation(3))];
            
            % To calculate the net source velocity
            excitation_weight = [is_excitation(1) is_excitation(1)].*srcDirection(3:4) + [is_excitation(2) is_excitation(3)].*srcDirection(1:2);

            % Inject the source to the Vx_next and Vy_next = excitationV(T)
            PV_Nplus1(row_idx, col_idx, 2) = PV_Nplus1(row_idx, col_idx, 2) + excitationV(T)*excitation_weight(1)*maxVxSigmaPrimedt(row_idx-1, col_idx-1);
            PV_Nplus1(row_idx, col_idx, 3) = PV_Nplus1(row_idx, col_idx, 3) + excitationV(T)*excitation_weight(2)*maxVySigmaPrimedt(row_idx-1, col_idx-1);
            
            % STEP7: Add absorbing boundary condition
            is_normal_dir = [beta(2) ~= cell_air, beta(3) ~= cell_air, beta(3) == cell_air, beta(2) == cell_air];
            
            xor_term = [beta(2) * (1-beta(1)) , beta(1) * (1-beta(2)), beta(3) * (1-beta(1)), beta(1) * (1-beta(3))];
            
            N = [0.707106*is_normal_dir(3) + (1-is_normal_dir(3)), 0.707106*is_normal_dir(2) + (1-is_normal_dir(2)), ...
                 0.707106*is_normal_dir(4) + (1-is_normal_dir(4)), 0.707106*is_normal_dir(1) + (1-is_normal_dir(1))];
        
            vb_alpha = [xor_term(2)*PV_Nplus1(row_idx,col_idx,1)*N(2) - xor_term(1)*PV_Nplus1(row_idx,col_idx+1,1)*N(1), ...
                        xor_term(4)*PV_Nplus1(row_idx,col_idx,1)*N(4) - xor_term(3)*PV_Nplus1(row_idx-1,col_idx,1)*N(3)];
         
            vb_alpha = (vb_alpha.* are_we_not_excitations)*z_inv;
            
            % Update Vx and Vy
            PV_Nplus1(row_idx,col_idx,2) = PV_Nplus1(row_idx,col_idx,2) + maxVxSigmaPrimedt(row_idx-1,col_idx-1) * vb_alpha(1);
            PV_Nplus1(row_idx,col_idx,3) = PV_Nplus1(row_idx,col_idx,3) + maxVySigmaPrimedt(row_idx-1,col_idx-1) * vb_alpha(2);
        end
    end
       
    PV_Nplus1(2:frameH-1, 2:frameW-1,2) = PV_Nplus1(2:frameH-1, 2:frameW-1,2)./(minVxBeta+maxVxSigmaPrimedt);
    PV_Nplus1(2:frameH-1, 2:frameW-1,3) = PV_Nplus1(2:frameH-1, 2:frameW-1,3)./(minVyBeta+maxVySigmaPrimedt);
    
    % STEP8: Re-store the grid cell type
    PV_Nplus1(2:frameH-1, 2:frameW-1,4) = PV_N(2:frameH-1, 2:frameW-1,4);
    
    %STEP9: Clear the border cell
    
    PV_Nplus1(:, 1, 1:3) = 0;
    PV_Nplus1(:, 1, 4) = PV_N(:, 1, 4);
    
    PV_Nplus1(:, frameW, 1:3) = 0;
    PV_Nplus1(:, frameW, 4) = PV_N(:, frameW, 4); 

    PV_Nplus1(1, :, 1:3) = 0;
    PV_Nplus1(1, :, 4) = PV_N(1, :, 4);
    
    PV_Nplus1(frameH, :, 1:3) = 0;
    PV_Nplus1(frameH, :, 4) = PV_N(frameH, :, 4); 
    
    audio_Vis = PV_Nplus1(:,:,1);
    audio_Vis(PV_Nplus1(:,:,4)==cell_wall) = vis_Boundary; % To visualize the obstacle
    
    % STEP10: Plot wave simulation
    if ~mod(T,1)
        imagesc(audio_Vis,[-1000 4000]);  colorbar; % Multiplied with twenty to change the color code
        xlabel('Spatial Resolution along X');
        ylabel('Spatial Resolution along Y');
        title(['STEP NUMBER: ' num2str(T) ' OUT OF ' num2str(STEPS)]);
        drawnow;
        
    end
    
    % STEP11: Copy PV_Nplus1 to PV_N for the next time step
    PV_N = PV_Nplus1; 
    Pr_Audio(T) = PV_Nplus1(listenerY, listenerX,1);
end