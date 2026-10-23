#!/usr/bin/env python3
"""
Expansion sizing with real fluid properties.

The MATLAB model in ../matlab/ assumes an ideal gas, which is fine for air at
4 atm and 293 K and wrong for a cryogenic liquid near saturation. This version
pulls density, sound speed and bulk modulus from CoolProp so the same sizing
arithmetic works on both sides of the phase boundary.

    pip install CoolProp
    python3 expansion_model.py

Runs without CoolProp too, falling back to ideal-gas relations for gases and
tabulated values for liquids, with a warning. The fallback is enough to
reproduce the ratios in the README; it is not enough to size hardware.
"""

import math

ATM = 101325.0

try:
    from CoolProp.CoolProp import PropsSI
    HAVE_COOLPROP = True
except ImportError:
    HAVE_COOLPROP = False

# Fallback values, normal boiling points. Density and sound speed from standard
# tables; bulk modulus derived as rho*c^2. VERIFY against NIST before use.
FALLBACK = {
    # fluid:      (T_K,  rho_kg_m3, c_m_s)
    "Hydrogen":   (20.4,   70.8, 1100.0),
    "Neon":       (27.1, 1207.0,  595.0),
    "Argon":      (87.3, 1396.0,  840.0),
}

GAMMA = {"Argon": 5.0 / 3.0, "Air": 1.4, "Nitrogen": 1.4, "Neon": 5.0 / 3.0,
         "Hydrogen": 1.41}


def liquid_bulk_modulus(fluid, T=None):
    """Isentropic bulk modulus of a saturated liquid, in Pa.

    K_S = rho * c^2 is exact, and both inputs are measured independently, so
    the result carries its own cross-check: if it disagrees with a tabulated
    K, one of the three numbers is wrong. That check caught a real error here —
    an early pass used isothermal K for liquids and adiabatic for gases, and
    the sound speed it implied was 30% below the measured value.
    """
    if HAVE_COOLPROP:
        T = T or PropsSI("T", "P", ATM, "Q", 0, fluid)
        rho = PropsSI("D", "T", T, "Q", 0, fluid)
        c = PropsSI("A", "T", T, "Q", 0, fluid)
    else:
        T, rho, c = FALLBACK[fluid]
    return rho * c * c, T, rho, c


def gas_bulk_modulus(pressure_pa, gamma):
    """Isentropic bulk modulus of an ideal gas: K_S = gamma * P.

    Exact for an ideal gas, and identical to rho*c^2 — worth confirming once,
    because it validates the rho*c^2 method on a case where you already know
    the answer before applying it to liquids where you do not.
    """
    return gamma * pressure_pa


def stroke_for_pressure(V0, A_eff, P1, P2, gamma):
    """Bellows stroke for a finite adiabatic compression from P1 to P2.

    dV/V0 = 1 - (P1/P2)^(1/gamma)

    Use this rather than the linearized dP/K for any real sizing. The gas
    stiffens as it compresses, so the linear form overestimates the stroke —
    by 17% at 4->5 atm and 43% at 4->8 atm.
    """
    frac = 1.0 - (P1 / P2) ** (1.0 / gamma)
    dV = V0 * frac
    return dV / A_eff, dV, frac


def plant_stiffness(A_eff, K, V0):
    """Fluid-as-spring stiffness seen by the actuator, N/m.

    k = A^2 * K / V. This is what sits in series with the machine's own
    compliance, and it is why a drive train that is rigid against gas behaves
    as a spring against liquid.
    """
    return A_eff ** 2 * K / V0


def delivered_fraction(k_machine, k_plant):
    """Fraction of commanded motion that reaches the fluid."""
    return k_machine / (k_machine + k_plant)


def main():
    if not HAVE_COOLPROP:
        print("CoolProp not installed — using fallback tables. Install with:")
        print("    pip install CoolProp\n")

    V0 = 1.70e-3          # m^3,  PLACEHOLDER
    A_eff = 0.0097534     # m^2,  measured 2026-10-23
    P_fill = 4 * ATM

    print(f"chamber {V0*1e3:.2f} L, bellows A_eff {A_eff*1e4:.2f} cm^2 "
          f"({A_eff*1e-3*1e6:.2f} cm^3 per mm of stroke)\n")

    print("GAS, finite adiabatic compression from 4 atm")
    print(f"  {'to':>6} {'dV/V0':>8} {'dV (cm^3)':>11} {'stroke (mm)':>12}")
    for P2_atm in (5, 6, 8, 10):
        x, dV, frac = stroke_for_pressure(V0, A_eff, 4, P2_atm, GAMMA["Air"])
        print(f"  {P2_atm:>4} atm {frac*100:>7.2f}% {dV*1e6:>11.1f} {x*1000:>12.2f}")

    print("\nBULK MODULUS")
    K_gas = gas_bulk_modulus(P_fill, GAMMA["Argon"])
    print(f"  {'argon gas at 4 atm':<22} {K_gas/1e6:>9.3f} MPa")
    for fluid in ("Hydrogen", "Neon", "Argon"):
        K, T, rho, c = liquid_bulk_modulus(fluid)
        print(f"  {'liquid ' + fluid.lower():<22} {K/1e6:>9.0f} MPa   "
              f"(T {T:.1f} K, rho {rho:.1f}, c {c:.0f} m/s)   "
              f"ratio {K/K_gas:>6.0f}x")

    print("\nPLANT STIFFNESS AND DELIVERED MOTION")
    k_machine = 100e6     # N/m,  PLACEHOLDER — measure this
    print(f"  assumed machine stiffness {k_machine/1e6:.0f} MN/m")
    print(f"  {'fluid':<22} {'k_plant (N/mm)':>16} {'delivered':>11}")
    k = plant_stiffness(A_eff, K_gas, V0)
    print(f"  {'argon gas at 4 atm':<22} {k/1e3:>16.2f} "
          f"{delivered_fraction(k_machine, k)*100:>10.2f}%")
    for fluid in ("Hydrogen", "Neon", "Argon"):
        K, *_ = liquid_bulk_modulus(fluid)
        k = plant_stiffness(A_eff, K, V0)
        print(f"  {'liquid ' + fluid.lower():<22} {k/1e3:>16.0f} "
              f"{delivered_fraction(k_machine, k)*100:>10.2f}%")

    print("\n  The delivered-motion column is the whole gas/liquid story. Against")
    print("  gas essentially all commanded motion arrives. Against liquid argon a")
    print("  meaningful fraction goes into flexing the machine instead, and the")
    print("  machine stiffness above is a guess that badly needs measuring.")


if __name__ == "__main__":
    main()
