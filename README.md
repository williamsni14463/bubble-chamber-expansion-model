# Bubble Chamber Expansion: Sizing and Dynamic Model

How much a bellows has to move to produce a given pressure change in a chamber,
how that answer changes between gas and liquid, and what the actuator has to do
to deliver it.

Work for MAMBA, a rapid cycling bubble chamber prototype at Fermilab. A bubble
chamber works by dropping a superheated liquid's pressure fast enough that
particle tracks nucleate bubbles along their path. Everything here is about
sizing the mechanism that drops the pressure.

---

## The stroke equation

A bellows sweeping volume out of a sealed chamber:

```
x  =  dV / A_eff  =  (V_0 / A_eff) * (dV/V_0)
```

Three variables and all of them are measurable. The content is in the last
term — how much the fluid compresses for a given pressure change.

**For a gas, compressed fast enough to be adiabatic:**

```
dV / V_0  =  1 - (P_1 / P_2)^(1/gamma)
```

**For a liquid, or a gas under a small pressure change:**

```
dV / V_0  =  dP / K
```

where K is the bulk modulus — how much pressure it takes to squeeze something by
a fractional volume. Steel is about 160 GPa. Water is 2.2 GPa. Air at atmospheric
pressure is 0.14 MPa, a million times softer than steel, which is the entire
reason this is hard.

---

## Which bulk modulus

There are two, and picking the wrong one is a factor-of-γ error that does not
announce itself.

**Isothermal (K_T)** applies when compression is slow enough that heat leaves and
the temperature stays constant. **Isentropic (K_S)** applies when it is fast
enough that no heat moves, so the fluid warms as it compresses and resists more.

```
K_S = gamma * K_T
```

For a monatomic gas γ = 5/3, so the adiabatic case is 67% stiffer. For a diatomic
gas γ = 7/5. For liquids γ is closer to 1 but not equal to it.

The deciding question is whether heat has time to cross the chamber during the
stroke. That is the Fourier number:

```
Fo = alpha * t / L^2
```

with α the thermal diffusivity and L the distance heat has to travel. Fo ≪ 1 is
adiabatic, Fo ≫ 1 is isothermal.

For air at 4 atm and 293 K in a 100 mm chamber, the diffusion time L²/α is about
486 s. A 300 ms stroke gives Fo ≈ 6×10⁻⁴. **Deeply adiabatic**, by a factor of a
thousand. There is no realistic stroke time where the isothermal number applies,
so K_S is the right choice throughout.

I got this wrong in a first pass, using the adiabatic modulus for gases and the
isothermal one for liquids. Speed of sound caught it — see below.

---

## Bulk moduli, and a check that catches sign errors

Because

```
c = sqrt(K_S / rho)    ->    K_S = rho * c^2
```

and both density and speed of sound are tabulated independently, you can derive
the bulk modulus from two numbers nobody got from the same place. If the result
disagrees with your table, one of them is wrong.

**Liquids at their normal boiling points:**

| Fluid | T (K) | ρ (kg/m³) | c (m/s) | K_S (MPa) |
|---|---|---|---|---|
| Liquid H₂ | 20.4 | 70.8 | 1119 | 89 |
| Liquid Ne | 27.1 | 1206 | 595 | 428 |
| Liquid Ar | 87.3 | 1395 | 838 | 981 |

*Saturated liquid at 1 atm, from CoolProp's Helmholtz equations of state.
Reproduce with `python/expansion_model.py`.*

**Gases, where K_S = γP exactly:**

| Gas | γ | 1 atm | 4 atm | 10 atm |
|---|---|---|---|---|
| Argon (monatomic) | 5/3 | 0.169 MPa | 0.675 MPa | 1.689 MPa |
| Air / N₂ (diatomic) | 7/5 | 0.142 MPa | 0.567 MPa | 1.419 MPa |

The two routes agree exactly for an ideal gas. Argon at 4 atm and 293 K: ρ = 6.643
kg/m³, c = 318.9 m/s, ρc² = 0.675 MPa against γP = 0.675 MPa. That identity
holding is how you know the method is sound before applying it to liquids where
there is nothing to check against.

---

## The result that reframed the project

For the same chamber, the same bellows, and the same small pressure change, the
required stroke is inversely proportional to bulk modulus. So the ratio is just
the bulk modulus ratio, and **the geometry cancels out entirely**:

| | Stroke ratio vs argon gas at 4 atm |
|---|---|
| Liquid H₂ | 131× |
| Liquid Ne | 633× |
| **Liquid Ar** | **1452×** |

Gas and liquid actuation are not two settings of one problem. They are different
problems that happen to share a machine.

In gas, the actuator is the bottleneck — tens of millimetres of travel and
hundreds of milliseconds, and the question is whether it has enough stroke and
enough force. In liquid, the actuator is trivially capable and the bottleneck
moves entirely to whether the drive train is stiff enough and whether you know
where the rod is to better than a micron.

What carries over: the drive configuration, commutation, motion task structure,
the trigger chain, the force-budget method. What does not carry over: every
number, and position control as a strategy.

### A caveat on that ratio

Those are linearized. For a finite compression the gas stiffens as it is squeezed,
so the real stroke is less than the linear estimate:

| Compression | Exact | Linearized | Ratio |
|---|---|---|---|
| 4 → 5 atm | 12.53% | 15.00% | 0.835 |
| 4 → 6 atm | 21.59% | 30.00% | 0.720 |
| 4 → 8 atm | 34.02% | 60.00% | 0.567 |

Use the exact form for any real sizing. The linear ratio is the right tool for
understanding the scale of the difference, not for choosing a bellows.

---

## Why the drive train suddenly matters in liquid

A fluid in a chamber behaves as a spring with stiffness

```
k_plant = A_eff^2 * K / V_0
```

and it sits in series with the machine's own compliance. The fraction of
commanded motion that reaches the fluid is

```
delivered = k_machine / (k_machine + k_plant)
```

In gas, k_plant is tiny and essentially all commanded motion arrives. In liquid,
k_plant rises by the same 1458×, and the machine's flex becomes comparable to the
entire working stroke.

Running the numbers for a 1.70 L chamber, the measured 97.5 cm² bellows, and an
assumed 100 MN/m machine stiffness:

| Fluid | k_plant | Commanded motion that reaches the fluid |
|---|---|---|
| Argon gas at 4 atm | 37.8 N/mm | 99.96% |
| Liquid H₂ | 4,963 N/mm | 95.3% |
| Liquid Ne | 23,924 N/mm | 80.7% |
| **Liquid Ar** | **54,877 N/mm** | **64.6%** |

Against gas, essentially everything arrives. Against liquid argon, **a third of
the commanded stroke goes into flexing the machine** rather than compressing the
fluid. Concretely, a drive-train deflection of 184 µm is invisible on a 40 mm gas
stroke and is three times the entire liquid-argon stroke.

The same machine, doing the same thing, is rigid in one case and a spring in the
other. That 100 MN/m is an assumption and it is now the most important
unmeasured number in the project.

This is also where trapped vapour becomes a design constraint. A bubble chamber
has to be liquid-full, because a gas pocket is a thousand times softer than the
liquid around it and absorbs the stroke. Break-even — where trapped vapour
contributes as much compliance as the entire liquid — arrives at
γP/K_S ≈ 0.017% by volume.

---

## The dynamic model

Sizing says how far. It does not say whether the actuator can get there in the
time available, what current that costs, or what the pressure curve looks like on
the way.

[`matlab/mamba_sim.m`](matlab/mamba_sim.m) is a 7-state stiff ODE covering motor,
drive train, bellows and gas as one coupled system:

| State | Meaning |
|---|---|
| x_m, v_m | Motor-side position and velocity (reflected to linear) |
| x_w | Bellows wall position, the load side of the drive-train spring |
| v_w | Bellows wall velocity |
| T | Gas temperature |
| i | Motor current |
| ei | Velocity-loop integrator |

Gas pressure is algebraic rather than a state, because vessel elastic compliance
makes volume depend on pressure and pressure depend on volume. That loop is
solved in closed form each step rather than iterated:

```matlab
function [V, Pr] = gasState(xw, T, P)
    % V appears on both sides through the vessel's elastic compliance, so
    % substituting P = m*Rs*T/V gives a quadratic in V with one physical root.
    b  = P.V0 - P.Ac.*xw - P.Cel*P.P0;
    V  = 0.5*(b + sqrt(b.^2 + 4*P.Cel*P.mgas*P.Rs.*T));
    Pr = P.mgas*P.Rs.*T./V;
end
```

Keeping it index-1 rather than a differential-algebraic system is what lets
`ode15s` handle it without a mass matrix. The system is stiff by a wide margin:
the current loop runs at kilohertz while the thermal time constant is seconds.

[`python/`](python/) has an equivalent built on `scipy` BDF integration with
CoolProp for real fluid properties, which is the route to take when ideal-gas
assumptions stop holding — which they do for liquids near saturation.

### What the model found that the sizing did not

Four things, none designed in:

- The motor holds **153% of its continuous rating indefinitely** at the operating
  point, with no thermal sensor configured and no brake fitted
- The holding force exceeds the actuator's rated thrust at 5 atm, well before the
  10 atm target
- The bellows **spring force is 2.2× the gas pressure load** — the spring, not
  the gas, is the dominant term in the force budget
- Drive-train flex of 184 µm is invisible on the gas plot and is three times the
  entire liquid stroke

The first two are the reason the model was worth building. Neither appears
anywhere in a steady-state calculation.

---

## Layout

```
docs/     Derivations and the gas/liquid comparison
matlab/   7-state stiff ODE, base MATLAB only (runs on MATLAB Online Basic)
python/   scipy + CoolProp equivalent for real fluid properties
```

## What is assumed

Chamber volume and bellows effective area are placeholders in the simulation and
are flagged as such in the parameter block. Every absolute number scales with
them; the ratios do not.

Vessel elastic compliance, drive-train stiffness, and the convective heat
transfer coefficient are estimates. The first two are measurable on a bench and
should be measured before any of this is used to size hardware.
