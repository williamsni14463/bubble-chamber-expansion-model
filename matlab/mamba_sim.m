function mamba_sim
% MAMBA_SIM  Coupled motor / drive-train / bellows / gas model of one
%            compression stroke on the MMBC chamber.
%
% Seven states, integrated with ode15s. The system is stiff by a wide margin:
% the current loop runs at kilohertz while the thermal time constant is
% seconds, so an explicit solver spends all its time on the fast mode.
%
% States
%   1  x_m   motor-side position, reflected to linear          [m]
%   2  v_m   motor-side velocity                               [m/s]
%   3  x_w   bellows wall position (load side of the spring)   [m]
%   4  v_w   bellows wall velocity                             [m/s]
%   5  T     gas temperature                                   [K]
%   6  i     motor current                                     [A]
%   7  ei    velocity-loop integrator                          [A]
%
% Gas pressure is NOT a state. Vessel elastic compliance makes volume depend
% on pressure and pressure depend on volume, which is an algebraic loop; it
% is solved in closed form in gasState() so the system stays index-1 and
% ode15s needs no mass matrix.
%
% Base MATLAB only. Runs on MATLAB Online Basic.
%
% Numbers marked PLACEHOLDER are not measured. Every absolute result scales
% with them. The ratios in the README do not.

clc; close all;

ATM = 101325;                 % Pa

% ---- chamber and gas -------------------------------------------------------
P.V0   = 1.70e-3;             % m^3     chamber volume            PLACEHOLDER
P.P0   = 4*ATM;               % Pa      fill pressure
P.T0   = 293.15;              % K       20 C
P.Rs   = 287.05;              % J/kg/K  dry air, R/M with M = 28.9655 g/mol
P.gam  = 1.4055;              % -       air is ~99% diatomic
P.Tamb = 293.15;              % K       wall temperature, held constant
P.hA   = 1.0;                 % W/K     gas-to-wall conductance   ESTIMATE

% Gas mass is fixed by the fill condition and never changes. Everything
% thermodynamic follows from this plus the energy equation.
P.mgas = P.P0*P.V0/(P.Rs*P.T0);
P.cv   = P.Rs/(P.gam - 1);

% ---- bellows ---------------------------------------------------------------
IN2 = 6.4516e-4;              % m^2 per in^2
P.Ac = 15.118*IN2;            % m^2     effective area, measured 2026-10-23
                              %         from convolution circumference
P.kc = 1775*4.448/0.0254;     % N/m     bellows spring rate       PLACEHOLDER
                              %         this is what the stroke test measures

% Vessel elastic compliance: the chamber itself stretches under pressure.
% Small, but it is what creates the algebraic loop below.
P.Cel = 1.4177e-13;           % m^3/Pa                            ESTIMATE

% ---- drive train -----------------------------------------------------------
P.kmach = 100e6;              % N/m     series stiffness          PLACEHOLDER
P.cmach = 2*0.05*sqrt(P.kmach*2369);   % N-s/m  5% of critical, assumed
P.mwall = 2.0;                % kg      bellows + rod moving mass ESTIMATE

% ---- motor and screw -------------------------------------------------------
P.Lead = 0.004;               % m/rev   screw lead
P.Jrot = 9.60209e-4;          % kg-m^2  rotor inertia (9.60209 kg-cm^2)
P.Kt   = 1.693717;            % N-m/Arms  torque constant
P.eta  = 0.90;                % -       screw efficiency          ASSUMED
P.Re   = 2.32;                % ohm     winding resistance, line-line
P.Le   = 11.5e-3;             % H       quadrature inductance, line-line
P.Vbus = 480;                 % V       DC bus
P.Ilim = 7.27;                % A       set below the 17.4 kN screw rating

% Reflected inertia. The lead appears SQUARED because kinetic energy goes as
% velocity squared and a smaller lead spins the motor faster for the same
% linear speed. This is 2369 kg, which dominates every fast move.
P.meff = P.Jrot*(2*pi/P.Lead)^2;

% Force per amp, and the same constant backwards as back-EMF per m/s.
P.Kf = 2*pi*P.eta*P.Kt/P.Lead;        % N/A  = 2394

% ---- control ---------------------------------------------------------------
% Velocity loop at 50 Hz, current loop an order of magnitude above it,
% position loop an order below. Standard cascade spacing.
wv = 2*pi*50;
P.Kp_cur = 60;
P.Kp_vel = wv/(P.Kf/P.meff);
P.Ki_vel = P.Kp_vel*wv/5;
P.Kp_pos = wv/5;

% ---- commanded move --------------------------------------------------------
P.d    = 0.0198;              % m   stroke, sized for 4 -> 5 atm adiabatic
P.Tm   = 0.30;                % s   move time
tend   = 2.0;                 % s   simulated duration

% ---- initial conditions ----------------------------------------------------
% Start at force balance: the bellows spring is already compressed by the
% static pressure difference, so the drive train carries that preload.
x0 = zeros(7,1);
x0(5) = P.T0;

opts = odeset('RelTol',1e-7,'AbsTol',1e-9,'MaxStep',P.Tm/50);
[t,y] = ode15s(@(t,y) rhs(t,y,P), [0 tend], x0, opts);

% ---- post-process ----------------------------------------------------------
[V,Pr] = gasState(y(:,3), y(:,5), P);
Fspring = P.kmach*(y(:,1) - y(:,3));
Fgas    = (Pr - ATM)*P.Ac;
Fbel    = P.kc*y(:,3);
flex    = (y(:,1) - y(:,3))*1e6;      % um

fprintf('\n--- results ---\n');
fprintf('  peak pressure      %7.3f atm   (%.2f PSI above fill)\n', ...
        max(Pr)/ATM, (max(Pr)-P.P0)/6894.76);
fprintf('  commanded stroke   %7.2f mm\n', P.d*1000);
fprintf('  delivered stroke   %7.2f mm   (%.1f%% of command)\n', ...
        max(y(:,3))*1000, 100*max(y(:,3))/P.d);
fprintf('  peak drive flex    %7.1f um\n', max(abs(flex)));
fprintf('  peak current       %7.2f A     (%.0f%% of 5 A continuous)\n', ...
        max(abs(y(:,6))), 100*max(abs(y(:,6)))/5);
fprintf('  settled current    %7.2f A\n', y(end,6));
fprintf('  peak gas temp      %7.2f K     (+%.2f K)\n', max(y(:,5)), max(y(:,5))-P.T0);
fprintf('  force at peak: gas %7.0f N, bellows spring %7.0f N  (ratio %.2f)\n', ...
        max(Fgas), max(Fbel), max(Fbel)/max(Fgas));

plot_results(t, y, Pr, V, flex, Fgas, Fbel, P, ATM);
end

% =============================================================================
function dy = rhs(t, y, P)
% Right-hand side. Order matters only for readability; everything is
% evaluated from the current state.

x_m = y(1); v_m = y(2); x_w = y(3); v_w = y(4);
T   = y(5); i   = y(6); ei  = y(7);

[V, Pr] = gasState(x_w, T, P);

% --- commanded trajectory: trapezoid, equal thirds ---
[xc, vc] = trapezoid(t, P.d, P.Tm);

% --- cascade control ---
v_dem  = vc + P.Kp_pos*(xc - x_m);
i_dem  = P.Kp_vel*(v_dem - v_m) + ei;
i_dem  = max(min(i_dem, P.Ilim), -P.Ilim);          % current limit
V_cmd  = P.Kp_cur*(i_dem - i);
V_cmd  = max(min(V_cmd, P.Vbus), -P.Vbus);          % bus limit

% Integrator only accumulates when the current demand is not saturated.
% Without this the integrator winds up during the accel phase and the move
% overshoots badly on arrival.
if abs(i_dem) < P.Ilim*0.999
    dei = P.Ki_vel*(v_dem - v_m);
else
    dei = 0;
end

% --- electrical ---
emf = P.Kf*v_m;                                      % back-EMF, same constant
di  = (V_cmd - P.Re*i - emf)/P.Le;

% --- mechanical, motor side ---
Fmot = P.Kf*i;
Fdt  = P.kmach*(x_m - x_w) + P.cmach*(v_m - v_w);   % drive-train spring+damper
dv_m = (Fmot - Fdt)/P.meff;

% --- mechanical, bellows side ---
Fgas = (Pr - 101325)*P.Ac;                           % gas resists compression
Fbel = P.kc*x_w;                                     % bellows spring
dv_w = (Fdt - Fgas - Fbel)/P.mwall;

% --- gas energy ---
% First law for a closed system with moving boundary:
%   m*cv*dT/dt = -P*dV/dt - hA*(T - Tamb)
% dV/dt is the bellows sweeping volume out, plus the vessel stretching.
dVdt = -P.Ac*v_w;
dT   = (-Pr*dVdt - P.hA*(T - P.Tamb))/(P.mgas*P.cv);

dy = [v_m; dv_m; v_w; dv_w; dT; di; dei];
end

% =============================================================================
function [V, Pr] = gasState(xw, T, P)
% Closed-form solution of the pressure/volume algebraic loop.
%
% The chamber volume is the nominal volume, less what the bellows swept out,
% plus however much the vessel stretched under pressure:
%
%     V = V0 - Ac*xw + Cel*(P - P0)
%
% and the ideal gas law gives P = m*Rs*T/V. Substituting one into the other
% produces a quadratic in V:
%
%     V^2 - (V0 - Ac*xw - Cel*P0)*V - Cel*m*Rs*T = 0
%
% Only the positive root is physical. Solving it here rather than iterating
% keeps the ODE system index-1.

b  = P.V0 - P.Ac.*xw - P.Cel*P.P0;
V  = 0.5*(b + sqrt(b.^2 + 4*P.Cel*P.mgas*P.Rs.*T));
Pr = P.mgas*P.Rs.*T./V;
end

% =============================================================================
function [x, v] = trapezoid(t, d, Tm)
% Trapezoidal position/velocity command, equal thirds.
% AKD2G motion tasks only offer trapezoidal, so the model matches the drive.
ta = Tm/3;
a  = d/(ta*(Tm - ta));
if t <= 0
    x = 0;          v = 0;
elseif t < ta
    x = 0.5*a*t^2;  v = a*t;
elseif t < Tm - ta
    x = 0.5*a*ta^2 + a*ta*(t - ta);
    v = a*ta;
elseif t < Tm
    td = Tm - t;
    x = d - 0.5*a*td^2;
    v = a*td;
else
    x = d;          v = 0;
end
end

% =============================================================================
function plot_results(t, y, Pr, V, flex, Fgas, Fbel, P, ATM)
figure('Position',[100 100 1100 700]);

subplot(2,3,1);
plot(t, y(:,1)*1000, 'LineWidth',1.2); hold on;
plot(t, y(:,3)*1000, '--', 'LineWidth',1.2);
xlabel('time [s]'); ylabel('position [mm]');
legend('motor side','bellows wall','Location','southeast');
title('Position'); grid on;

subplot(2,3,2);
plot(t, Pr/ATM, 'LineWidth',1.2);
xlabel('time [s]'); ylabel('pressure [atm]');
title('Chamber pressure'); grid on;

subplot(2,3,3);
plot(t, y(:,6), 'LineWidth',1.2); hold on;
yline(5,'--','5 A continuous');
xlabel('time [s]'); ylabel('current [A]');
title('Motor current'); grid on;

subplot(2,3,4);
plot(t, y(:,2)*1000, 'LineWidth',1.2);
xlabel('time [s]'); ylabel('velocity [mm/s]');
title('Motor velocity'); grid on;

subplot(2,3,5);
plot(t, flex, 'LineWidth',1.2);
xlabel('time [s]'); ylabel('deflection [\mum]');
title('Drive-train flex'); grid on;

subplot(2,3,6);
plot(t, Fgas/1000, 'LineWidth',1.2); hold on;
plot(t, Fbel/1000, '--', 'LineWidth',1.2);
xlabel('time [s]'); ylabel('force [kN]');
legend('gas pressure','bellows spring','Location','southeast');
title('Force budget'); grid on;
end
