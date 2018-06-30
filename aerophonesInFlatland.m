%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FDTD 2D MODELLING FOR ACOUSTIC WAVE ANALYSIS INSIDE A TUBE
%
% This code implments a cylinderical tube model inside a grid to analyze 
% acoustic wave propagation using FDTD engine. To understand the technical 
% details and conceptual theory behind this implementation, follow these papers - 
% [1] "Aerophones in Flatland: Interactive wave simulation of wind instruments"
% by Andrew allen and Nikunj Raghubansi.
% [2] "Towards a real-time two-dimensional wave propagation for articulatory 
% speech synthesis." by Victor Zappi, Arvind and Sidney Fels
% [3] "Acoustic Analysis of the vocal tract during vowel production" by 
% finite-difference time-domain method by Hironori Takemoto and Parham Mokhtari.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Wave equation for non-PML (FOR 2D):
% dp/dt = -(rho*c*c*r*del.(v)) % del = del operator
% dv/dt = (-1/rho)*(del(P))
% du/dt = (-1/rho)*(del(P))

% Wave equation for PML (FOR 2D):
% dp/dt + sig*p = -(rho*c*c*r*del.(v)) % sig = stretching field
% dv/dt + sig*v = (-1/rho)*(del(P))
% du/dt + sig*v = (-1/rho)*(del(P))

% Wave equation to implement Tube with PML
% dp/dt + sigPrime*p = -(rho*c*c*r*del.(v))
% dv/dt + sigPrime*v = (-beta^2/rho)*(del(P)) + sigprimeVb
% sigPrime = 1-beta+sigma
%***********************************************************************

% Initialize MATLAB environment
close all;
clear; clc;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DEFINE UNITS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
meter = 1;
centimeter  =1e-2;

second    = 1;
hertz     = 1/second;
kilohertz = 1e3 * hertz;
megahertz = 1e6 * hertz;
gigahertz = 1e9 * hertz;

gram      = 1e-3;
kilogram  = 1e3*gram;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DEFINE CONSTANTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rho = 1.1760*kilogram/(meter^3);   % Air density  [kg/m^3]
c   = 343*meter/second;            % Sound speed in air [m/s]
PML_ON  = 1;                       % fictitious conductance when PML is ON
PML_OFF = 0;                       % fictitious conductance when PML is OFF
maxSigmaVal = 0.5;                 % Attenuation coefficient at the PML layer
alpha = 0.004;                     % Reflection coefficient
Zn = ((1+sqrt(1-alpha))/(1-sqrt(1-alpha)))*rho*c; % Acoustic Impedance

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DASHBOARD
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dx = 3.83e-3;            % spatial resolution along x-direction
dy = 3.83e-3;            % apatial resolution along y-direction
dt = 7.81e-6;            % temporal resolution
STEPS = 10000;           % number of time-steps for simulation
kappa = rho*c*c;             % Bulk modulus
CURR_PML_VAL = PML_ON;  % current pml status

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% GRID CELL CONSTRUCTION : DEFINE SIGMA AND BETA VALUE FOR EACH CELL
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% domainW an domainH signifies the size of problem space
domainW = input('Enter domain width: ');
domainH = input('Enter domain height: ');

% tubeHorizontalLength an tubeVerticalLength signifies the size of tube
tubeHorizontalLength = input('Enter horizontal tube length: ');
tubeVerticalLength   = input('Enter vertical tube length: ');

% tubeWidth signifies the distance between tube walls : Right now we are
% assuming it's uniform across the tube.
tubeWidth = input('Enter tube width: ');

% Number of PML layers
pmlLayer = input('Number of PML layer: ');

% build the tube inside the problem space and add the PML layers
refFrameSigma = buildFrameSigma(domainW, domainH, pmlLayer, maxSigmaVal, dt);
[refFrameBeta, xSrc, ySrc]  = buildFrameBeta(domainW, domainH, tubeHorizontalLength,...
                   tubeVerticalLength, tubeWidth, pmlLayer);

refFrameBeta(xSrc, ySrc) = 0;

% Just to visualize the PML layers with the tube structure, I've multiplied 
% refFrameBeta with 1e6.
refFrameSigmaPrimeVisual = 1-(1e6*refFrameBeta)+refFrameSigma ;
figure('color','w'); imagesc(refFrameSigmaPrimeVisual');

% Actual refFrameSigmaPrime value
refFrameSigmaPrime = 1-refFrameBeta + refFrameSigma ;

% Define Grid/Frame size
Nx = size(refFrameSigmaPrime, 1);
Ny = size(refFrameSigmaPrime, 2);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SOURCE PARAMETERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
freq = 1*kilohertz;      % source frequency
t = (1:STEPS).*dt;       % time steps
Esrc = sin(2*pi*freq*t); % sinusoidal source wave

% Source parameters for Gaussian source
tau = 0.5/freq;
t0 = 6*tau;
% Esrc = exp(-(((t-t0)./tau).^2));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FDTD PARAMETERS - PART I (DEFINE UPDATE COEFFICIENT)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
mUx0 = (refFrameBeta./dt) + (refFrameSigmaPrime./2);
mUx1 = ((refFrameBeta./dt) - (refFrameSigmaPrime./2))./mUx0;
mUx2 = (-(refFrameBeta.*refFrameBeta)./rho)./mUx0;
mUx3 = refFrameSigmaPrime./mUx0;

mVy0 = (refFrameBeta./dt) + (refFrameSigmaPrime./2);
mVy1 = ((refFrameBeta./dt) - (refFrameSigmaPrime./2))./mVy0;
mVy2 = (-(refFrameBeta.*refFrameBeta)./rho)./mVy0;
mVy3 = refFrameSigmaPrime./mVy0;

mPr0 = 1/dt + refFrameSigmaPrime./2;
mPr1 = (1/dt - refFrameSigmaPrime./2)./mPr0;
mPr2 = (-kappa)./mPr0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FDTD PARAMETERS - PART II (INITIALISING FIELD)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CxP = zeros(Nx, Ny);
CyP = zeros(Nx, Ny);
CxU = zeros(Nx, Ny);
CyV = zeros(Nx, Ny);
Ux  = zeros(Nx, Ny);
Vy  = zeros(Nx, Ny);
Ubx = zeros(Nx, Ny);
Vby = zeros(Nx, Ny);
Pr  = zeros(Nx, Ny);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FDTD ANALYSIS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for T = 1: STEPS
    
    % STEP1 : Solve CxP & CyP : Calculate Pressure gradient
    CxP(1:Nx-1,:) = (Pr(2:Nx,:)-Pr(1:Nx-1,:))/dx;
    CxP(Nx,:) = (Pr(1,:)-Pr(Nx,:))/dx;
    
    CyP(:,1:Ny-1) = (Pr(:,2:Ny) - Pr(:,1:Ny-1))/dy;
    CyP(:,Ny) = (Pr(:,1) - Pr(:,Ny))/dy;
    
    % Step2: Solve Vby and Ubx : To verify tube boundary
    Ubx(1:Nx-1,:) = Pr(2:Nx,:)./Zn;
    Vby(:, 1:Ny-1)  = Pr(:,2:Ny)./Zn;
    
    % STEP3 : Solve Ux & Vy
    Ux = mUx1.*Ux + mUx2.*CxP + mUx3.*Ubx;
    Vy = mVy1.*Vy + mVy2.*CyP + mVy3.*Vby;
       
    % STEP4 : CxU & CyV  
    CxU(1,:)  = (Ux(1,:) - Ux(Nx,:))/dx;
    CxU(2:Nx,:)  = (Ux(2:Nx,:) - Ux(1:Nx-1,:))/dx;    
    
    CyV(:,1) = (Vy(:,1) - Vy(:,Ny))/dy;
    CyV(:,2:Ny) = (Vy(:,2:Ny) - Vy(:,1:Ny-1))/dy;   
    
    % STEP5 : Solve Pr
    Pr = Pr.*mPr1 + (mPr2.*(CxU+CyV));
    
    % STEP6: Inject source
    Pr(xSrc,ySrc) = Pr(xSrc,ySrc) + Esrc(T);
    
    % STEP7 : Draw the graphics
    if ~mod(T,20)
        imagesc(Pr'*50, [-1,1]); colorbar; % Multiplied with twenty to change the color code
        xlabel('Spatial Resolution along X');
        ylabel('Spatial Resolution along Y');
        title(['STEP NUMBER: ' num2str(T) ' OUT OF ' num2str(STEPS)]);
        drawnow;
    end   
end