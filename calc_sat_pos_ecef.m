%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%      Satellite Position/Velocity Calculation Function        %
%   Author: Saurav Agarwal   %
%   Date: January 1, 2011  %
%   Dept. of Aerospace Engg., IIT Bombay, Mumbai, India %
%   All i/o units are specified in brackets %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% References:
%            1. Grewal & Andrews, Ch 3-Table 3.2  
% Outputs:     
%        1. x_ecef,y_ecef,z_ecef: GPS Satellite Coordinates in ECEF frame (m) 
%        2. Vecef: Velocity of satellite w.r.t to earth in ECEF frame (m/s)
% Inputs:
%        1. gps_sat: array containing ephemeris data of gps satellites
%        2. t_sv: gps time (s)
%        3. sv_id: id number of gps satellite for which to calculate p/v
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [x_ecef,y_ecef,z_ecef,Vecef] = calc_sat_pos_ecef(gps_sat,t_sv,sv_id)


    %  Constants
    mu = 3.986004418e14;							% universal gravitational param (m^3/s^2)
    OMEGA_dot_e = 7.292115e-5;				% earth's rotation rate (rad/sec)
    c = 2.99792458e8;							% speed of light (m/s)
    F = -2*sqrt(mu)/c^2;					    % (s/m^1/2)
    rtd = 180/3.14159; % radians to degree
    dtr = 3.14159/180;

    %  Given constant ephemeris data
    delta_n = 4.908419e-9;							% (rad/s) from grewal
    t_oe = 147456.0000;                             % Ephemeris Reference Time(s) [from the GPS data taken from website]
    C_ic = 6.146729e-8;								% (rad)
    C_rc = 2.259375e2;								% (rad)
    C_is = 2.086163e-7;								% (rad)
    C_rs = 7.321875e1;								% (rad)
    C_uc = 4.017726e-6;								% (rad)
    C_us = 7.698312e-6;								% (rad) 
    I_dot = 9.178953e-11;                           % Rate of change of inclination(rad/s) from grewal

    %  Time calculations:
    %  We assume that when transmit time is taken into account, 
    %  t_sv = 248721.9229  This value is used to calculate GPS system
    %  time below.  Note: delta_tr is assumed to be negligible (calculated
    %  value of delta_tr = 2.6e-8 sec)

    n_0 = sqrt(mu/(gps_sat(sv_id).sqrt_a)^6);		% (rad/s)
    t_k=t_sv-t_oe;									% Time from eph ref epoch (s)
    n = n_0 + delta_n;                              % Corrected mean motion (rad/s)
    M_k = gps_sat(sv_id).M_0+n*t_k;					% Mean anomaly (rad/s)

    %  Perform Newton-Raphson solution for E_k estimate
    E_k= newton_raphson(gps_sat(sv_id).e,M_k);		% Eccentric anomaly ESTIMATE for computing delta_tr
    
    num  =(sqrt(1-gps_sat(sv_id).e^2)*sin(E_k))/(1-gps_sat(sv_id).e*cos(E_k));
    denom =(cos(E_k)-gps_sat(sv_id).e)/(1-gps_sat(sv_id).e*cos(E_k));
    v_k=atan2(num,denom);									% True anom (rad)
    E_k=acos((gps_sat(sv_id).e+cos(v_k))/(1+gps_sat(sv_id).e*cos(v_k)));				% Eccentric anomaly
    PHI_k=v_k+gps_sat(sv_id).omega;											% Argument of latitude 

    % Second Harmonic Perturbations
    deltau_k=C_us*sin(2*PHI_k)+C_uc*cos(2*PHI_k);	% Argument of Lat correction
    deltar_k=C_rs*sin(2*PHI_k)+C_rc*cos(2*PHI_k);	% Radius correction
    deltai_k=C_is*sin(2*PHI_k)+C_ic*cos(2*PHI_k);	% Inclination correction
    
    u_k=PHI_k+deltau_k;										% Corr. arg of lat
    r_k=(gps_sat(sv_id).sqrt_a)^2*(1-gps_sat(sv_id).e*cos(E_k))+deltar_k;			% Corrected radius
    i_k=gps_sat(sv_id).i_0+deltai_k+I_dot*t_k;							% Corrected inclination
    
    % Positons in orbital plane
    xprime_k=r_k*cos(u_k);
    yprime_k=r_k*sin(u_k);

    OMEGA_k=gps_sat(sv_id).Omega_0+(gps_sat(sv_id).Omega_dot-OMEGA_dot_e)*t_k-OMEGA_dot_e*t_oe;

    % ECEF coordinates
    x_ecef = xprime_k*cos(OMEGA_k)- yprime_k*cos(i_k)*sin(OMEGA_k);
    y_ecef = xprime_k*sin(OMEGA_k)+ yprime_k*cos(i_k)*cos(OMEGA_k);
    z_ecef = yprime_k*sin(i_k); 
    
    % Velocity Estimation
    a = gps_sat(sv_id).sqrt_a^2;
    Vorbital = n*a/(1-gps_sat(sv_id).e*cos(E_k))*[-sin(E_k);sqrt(1-gps_sat(sv_id).e^2)*cos(E_k);0];% satellite velocity in orbital plane
    
    % Formulate Rotation matrix
    R1 = [cos(gps_sat(sv_id).omega) -sin(gps_sat(sv_id).omega) 0;sin(gps_sat(sv_id).omega) cos(gps_sat(sv_id).omega) 0;0 0 1];
    R2 = [1 0 0;0 cos(i_k) -sin(i_k);0 sin(i_k) cos(i_k)];
    R3 = [cos(OMEGA_k) -sin(OMEGA_k) 0;sin(OMEGA_k) cos(OMEGA_k) 0;0 0 1];
    R_ORIBT2ECEF= R3*R2*R1; % rotation matrix from orbit to ECEF frame 

    Vecef = (R_ORIBT2ECEF*Vorbital - cross([0;0;OMEGA_dot_e],[x_ecef;y_ecef;z_ecef]))'; % Subtracting rotation of earth to get velocity with respect to center of earth in ECEF frame
    
end
    