# Derivations

The working behind the README, with the assumptions made explicit and the points
where they break down.

---

## 1. Stroke from a pressure target

A sealed chamber of volume V₀ with a bellows of effective area A_eff. Moving the
bellows by x sweeps out ΔV = A_eff·x, so:

```
x = dV / A_eff = (V_0 / A_eff) * (dV / V_0)
```

Everything interesting is in dV/V₀, the fractional compression.

### Effective area is not the envelope area

A bellows does not have one diameter. The standard estimate uses the mean of the
convolution outer and inner diameters:

```
A_eff = (pi/4) * D_mean^2,    D_mean = (OD + ID) / 2
```

The true definition is ΔV/Δx, determined experimentally, and manufacturers
publish it for bellows sold as displacement elements. For well-formed
convolutions the mean-diameter estimate is good to a few percent; deep
convolutions deviate more.

A practical note that cost a day here: measuring the circumference around the
outer convolutions and dividing by π is more robust than measuring the diameter
directly. Error propagates as dA/A = dC/(π·D_mean), so a quarter-inch error in
circumference on a 4.4 in mean diameter moves the area by 1.8%.

And if the manufacturer does not publish an effective area, that absence is
information. Flex hoses do not have one published because they are not sold as
displacement elements.

---

## 2. Compression of a gas

For a reversible adiabatic process, PV^γ = constant, so:

```
V_2 / V_1 = (P_1 / P_2)^(1/gamma)
dV / V_0  = 1 - (P_1 / P_2)^(1/gamma)
```

**Linearizing** for small ΔP gives dV/V₀ ≈ ΔP/(γP₁), which identifies γP as the
isentropic bulk modulus. The linear form is convenient and it overestimates:

| Compression | Exact | Linear | Exact / linear |
|---|---|---|---|
| 4 → 5 atm | 12.53% | 15.00% | 0.835 |
| 4 → 6 atm | 21.59% | 30.00% | 0.720 |
| 4 → 8 atm | 34.02% | 60.00% | 0.567 |

The gas stiffens as it is squeezed, so each additional atmosphere costs less
volume than the last. Use the exact form for sizing.

### Where γ comes from

Equipartition gives cv = (f/2)R with f the active degrees of freedom, and
γ = 1 + 2/f:

| Gas | Degrees of freedom | γ |
|---|---|---|
| Monatomic (Ar, Ne, He) | 3 translational | 5/3 = 1.667 |
| Diatomic (N₂, O₂, H₂) | 3 translational + 2 rotational | 7/5 = 1.400 |

Vibrational modes are frozen out at room temperature for these gases, which is
why the diatomic value is 7/5 and not 9/7. Air at 1.4055 reflects its ~99%
diatomic composition.

---

## 3. Which bulk modulus, and how to tell

```
K_S = gamma * K_T
```

Isothermal applies when heat has time to leave during the compression; isentropic
when it does not. The Fourier number decides:

```
Fo = alpha * t / L^2
```

with α = k/(ρ·cp) the thermal diffusivity, t the stroke time, and L the distance
heat must travel — half the smallest chamber dimension, not the longest.

**For air at 4 atm, 293 K, in a 100 mm chamber:**

```
rho   = 4*101325 / (287.05 * 293.15) = 4.816 kg/m^3
alpha = 0.0257 / (4.816 * 1005)      = 5.31e-6 m^2/s
L^2/alpha = 0.0508^2 / 5.31e-6       = 486 s
```

A 300 ms stroke gives Fo = 6.2×10⁻⁴. Adiabatic by three orders of magnitude.
There is no stroke time a servo can produce where the isothermal modulus applies.

### The boundary layer is the real correction

Fo ≪ 1 says the bulk of the gas is adiabatic. It does not say *no* heat moves. A
thermal boundary layer grows at the wall as δ ≈ √(α·t), and the gas inside it
does exchange heat:

| Stroke time | δ | Fraction of the gas inside it |
|---|---|---|
| 100 ms | 0.73 mm | 3.6% |
| 300 ms | 1.26 mm | 6.2% |
| 1.0 s | 2.30 mm | 11.3% |

A few percent of the pressure rise, scaling as √t. Faster strokes lose less, but
only as the square root, so halving the move time buys a factor of 1.41. Not
worth chasing against the constraints at the other end.

Note this gets worse if a filler block is added to reduce V₀ — a displacer adds
wetted area, and the boundary-layer fraction climbs.

---

## 4. The error the sound speed caught

A first pass used the adiabatic modulus for gases and the isothermal one for
liquids. The numbers looked plausible and the error was a factor of γ hiding in
the liquid column.

What caught it:

```
c = sqrt(K_S / rho)
```

Liquid argon at 87.3 K, ρ = 1395 kg/m³. With the isothermal K = 474 MPa:

```
c = sqrt(474e6 / 1395) = 583 m/s
```

Measured sound speed in liquid argon at that temperature is about 838 m/s. Off by
30%, which is √γ for argon — exactly the signature of using the wrong modulus.

With K_S = 981 MPa the predicted sound speed is 838 m/s and the discrepancy
disappears.

**The general lesson, and the reason it is worth writing down:** a derived
quantity that can be computed two independent ways is worth computing both ways.
Density and sound speed come from different measurements and different tables.
Agreement between them is not guaranteed by the arithmetic, so it means
something.

---

## 5. Plant stiffness and series compliance

A fluid in a fixed chamber acts as a spring. Compressing by ΔV raises pressure by
K·ΔV/V₀, which pushes back on the bellows with A_eff·ΔP:

```
F = A_eff * dP = A_eff * K * (A_eff * x) / V_0
k_plant = A_eff^2 * K / V_0
```

The area appears squared: once converting motion to volume, once converting
pressure back to force.

This sits in **series** with the machine's own compliance, so they combine as
springs in series and the softer one dominates:

```
delivered = k_machine / (k_machine + k_plant)
```

With A_eff = 97.5 cm², V₀ = 1.70 L, and an assumed k_machine = 100 MN/m:

| Fluid | K_S | k_plant | Delivered |
|---|---|---|---|
| Argon gas at 4 atm | 0.675 MPa | 37.8 N/mm | 99.96% |
| Liquid H₂ | 89 MPa | 4,963 N/mm | 95.3% |
| Liquid Ne | 428 MPa | 23,924 N/mm | 80.7% |
| Liquid Ar | 981 MPa | 54,877 N/mm | 64.6% |

Against gas the machine is effectively rigid. Against liquid argon a third of the
commanded stroke goes into the machine.

**k_machine = 100 MN/m is a guess.** It is the most important unmeasured number
in the project, because the liquid case depends on it directly and the gas case
is insensitive to it. A bench test that pushes a known force and measures the
difference between the motor encoder and a dial indicator on the rod measures it
in an afternoon.

---

## 6. Trapped vapour

A bubble chamber must be liquid-full. A gas pocket is compressible enough to
absorb the stroke before the liquid feels it.

Break-even — where a vapour fraction φ contributes as much compliance as the
entire liquid volume:

```
phi * (1 / (gamma * P)) = (1 - phi) * (1 / K_S)
phi ~ gamma * P / K_S    for small phi
```

For liquid argon at 1 atm: φ ≈ 1.667 × 101325 / 981×10⁶ = **1.7×10⁻⁴**, which is
0.017% by volume.

A vapour fraction of two parts in ten thousand doubles the system's compliance.
That is the number that makes bubble chamber plumbing hard, and it is not
intuitive until you see where it comes from.

---

## 7. Reflected inertia

The rotor must be accelerated along with the load, and the screw multiplies its
apparent mass:

```
m_eff = J * (2*pi / lead)^2
```

The lead appears squared because kinetic energy goes as v², and a smaller lead
means more motor revolutions per millimetre. For J = 9.60209×10⁻⁴ kg·m² and a
4 mm lead:

```
m_eff = 9.60209e-4 * (2*pi / 0.004)^2 = 2369 kg
```

A 4 mm lead buys 2394 N/A of thrust and costs 2369 kg of apparent mass. That
trade is fixed once the actuator is chosen, and it is why acceleration rather
than velocity is the binding constraint on fast moves.
