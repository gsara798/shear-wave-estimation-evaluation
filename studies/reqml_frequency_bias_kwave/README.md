# REQ-ML: apparent frequency dispersion under controlled 3D k-Wave fields

**Status (2026-11-03): Study specification + homogeneous config builder;
no 3-D simulation has been executed or scientifically validated.**
This is a *study* in SWS-Eval, not a new fitting or training campaign.
Frozen model bundles remain in REQ-ML. Solver implementations remain in
shear-wave-simulation-framework.

## Scientific question

Does the observed increase of SWS with driving frequency in
`reduced16` occur when the *true material shear speed is constant*?

We want to separate:

1. Constitutive dispersion (set **zero** in the first pilot).
2. Nonlocal wavefield interference, interface reflection and polarization.
3. Numerical effects of elastic wave propagation, finite sources and FFT.
4. REQ-ML model/quantile error; changing spatial patch dimensions with frequency.
5. Region-of-interest support changes with frequency.

We do **not** use mechanical testing SLS extrapolations as exact truth.
For the nondispersive simulated material, truth is instead set exactly by
the numerical material map. Convergence error still needs validation.

## Existing framework examples inspected

- **Opposed disks:** `shear-wave-simulation-framework` **develop/v2** branch,
  `examples/kwave/3d/opposed_x_disks/{README.md,config.json,run_opposed_x_disks_3d.m}`.
  This is a *custom* runner, NOT the public `run_simulation`/campaign JSON.
  It solves **3D pstdElastic3D**, drives facing x-normal disks with
  x-directed velocity, and saves central x-z plane `run.mat` components:
  `axial_shear_displacement_zx`, `axial_compression_displacement_zx`,
  `axial_total_displacement_zx`, `lateral_shear_displacement_zx`.
- **Bilayer:** `examples/kwave/3d/bilayer/config.json` (public framework
  `run_simulation` API). Its default interface normal is **x**. A z-oriented
  interface and both opposed disk sources will require a combined **validated
  implementation**. Simply editing an extra `geometry` block into the
  custom opposed-disk config would silently produce a homogeneous field.

**Physical warning:** a disk normal to x, driven in x, produces important
compressional (longitudinal) motion. Axial `U_z` might be small and/or
dominated by mode conversion. Quantify shear/compression before interpreting
REQ/REQ-ML. The simulation measures the center **x-z** plane (out-of-plane
coordinate y). The experimental ultrasound measures **axial displacement**.

## Frozen observational and numerical design

| Quantity | Setting | Meaning |
| --- | --- | --- |
| Observation FOV | **50 x 50 mm**, x-z | Not the entire solver box |
| Desired sampling | **dx=dz=0.2 mm** | 251 x 251 field centers approximately |
| Current custom runner | **dx=dy=dz=0.2 mm** | One isotropic spacing field |
| Computational domain | **70 x 24 x 64 mm**, x-y-z | Disks + boundary clearance outside FOV |
| Estimated solver grid | **351 x 121 x 321** | **13.63 million** 3-D nodes |
| Material SWS | 1.8 and 3.0 m/s | Deliberately nondispersive, not fitted reference |
| Frequencies | 300, 400, 500, 600 Hz | Full experimental sampling |
| Sources | Two 3 mm radius sparse x-normal disks | x velocity; phase offset 0 |\n| Source-node spacing | 8 grid points = 1.6 mm | Approximate the 1.5 mm source-node spacing in the 0.5 mm example |
| Density / cp | 1000 kg/m³ / reduced cp=10cs | Computational approximation; not tissue cp |
| Loss | No material attenuation, no tracking noise | Establish clean control |
| REQ analysis | M=2; StepPixels=2 | Same as SP experiment |
| Models to inspect | reduced16 A, filtered-v2 C, candidate10 filtered | No retraining |

The computational box is larger than the visible FOV by design. The
**13.63 million nodes** are *much* larger than the example's default
0.5 mm grid; the full k-Wave peak memory/time is not inferred from the raw
array size. There are many material, solver, FFT and sensor buffers.
Even a **single** simulation may be impractical on a laptop. Inspect
resources before any run; if memory prohibits 0.2 mm in 3D, do a
**clearly labeled resolution/convergence pilot** rather than quietly
altering the target study.

For the minimum shear wavelength, λ=1.8/600=3 mm, giving
15 points per wavelength at dx=0.2 mm (necessary, not sufficient, for
numerical convergence). 3-D resources and k-Wave time-step count must
also be checked. A fixed REQ M changes the patch size in meters as f changes.

## Study phases and stopping criteria

### 0. ROI matching — no simulations

Recalculate statistics on a common physical subset of ROI centers across
300–600 Hz, within each phantom and each model. Keep identical ROI masks
where feasible. Original ROI1 has a smaller valid depth range at 300 Hz
than at higher frequencies: do not attribute the effect to material
dispersion until this confound is removed.

### 1. Homogeneous nondispersive k-Wave control

**Eight possible cases**: cs {1.8, 3.0} m/s × f {300,400,500,600} Hz.
Before the full sweep: run **one 500-Hz case only**, inspect the spatial
complex `U_z`, shear and compressional components, P/S ratio, simulation
runtime, finite field validity, boundaries and numerical stability.

If axial shear is negligible, the x-normal disks are **not a meaningful
stand-in** for the experimental observed shear field: adjust source
geometry/polarization in the simulation framework with a validated
separate configuration, not by redefining the measured component.

Once that check passes, sweep four frequencies for both homogeneous
material speeds. Save every resolved input, numerical configuration and
simulation diagnostic.

### 2. Bilayer control

Validate a combined 3D opposed-disk source + heterogeneous bilayer
solver. Place a **z-normal** interface at the intended soft/hard depth
(precise location must match the actual experimental phantom).
Use `cs_soft=1.8`, `cs_hard=3.0` m/s and the same 300–600 Hz.
Check layer material maps, wavefields and whether the two homogeneous
reference regions measure similarly in the bilayer.

This phase is **blocked**, not implemented by the existing opposed-disk
runner. No purported bilayer output is generated from that homogeneous
runner.

### 3. Estimator comparisons on the SAME wavefield

Export explicit standardized `wavefield_sample.mat` for **axial total**
(and an additional **axial shear-only** diagnostic). Run the frozen
REQ-ML models on the raw and globally filtered complex fields with the
same 0.8–8 m/s donut, M=2, StepPixels=2:

- `reduced16 raw`
- `reduced16 filtered v2`
- `candidate10 filtered`

Important: the custom opposed-disk `run.mat` is **not itself**
a `wavefield_sample.mat`; convert explicitly and validate first.
Compare SWS to exact simulated truth; quantify signed bias, MAPE, CV,
valid fraction and \(\Delta c_s(600-300)\), at paired physical locations.
Compare field Fourier spectrum and quantile predictions as a *diagnostic*.
Use one common area for all f and arms.

### 4. Mechanism controls (only if needed)

If apparent dispersion exists in the clean elastic homogeneous control,
compare S/P separation, source polarization, wavefront curvature,
spatial filtering and patch support before adding physics.
Then test bilayer and source opposition. Tracking/SNR noise and material
viscoelasticity are **later** controlled factors, not implicit assumptions.

### Stop/decision rule

- **Nonzero frequency slope on known nondispersive material:** evidence
  of an apparent estimator/wavefield/numerical effect, not proof of
  constitutive dispersion.
- **Stable in homogeneous / unstable in bilayer:** geometry or interference
  is implicated.
- **Stable in both:** look next at acquisition noise and experimental
  constitutive response.
- **Strong P contamination or unsupported source physics:** do not
  interpret a synthetic `U_z` slope as a shear estimator verdict.

Do not retrain on this campaign. Record model-specific failures without
changing the frozen training/validation split.

## Code and organization

`study_config.json` freezes the intended physics and sampling.
`prepare_homogeneous_pilot.m` reads the *actual* develop/v2 custom
example and prepares per-condition JSONs, writing only when asked.
Solver outputs go **outside Git** under:
`experimental-data-reorganized/2026-02-27/_simulation_studies/reqml_frequency_bias_kwave_v1/`.

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"studies","reqml_frequency_bias_kwave"))

% Show expected sizes, cases, and saved-run status: DOES NOT simulate.
T=prepare_homogeneous_pilot();

% Only write per-case JSONs to the data directory:
T=prepare_homogeneous_pilot(WriteConfigs=true);

% After manual memory review, the custom framework's 3D solver is run
% explicitly for ONE selected case, not automatically all eight:
simroot="/Users/sara/local/shear-wave-simulation-framework";
addpath(fullfile(simroot,"src"))
addpath(fullfile(simroot,"examples","kwave","3d","opposed_x_disks"))
% Verify the framework and external k-Wave installation first:
which run_opposed_x_disks_3d
which pstdElastic3D
% Do not call run_opposed_x_disks_3d until resource preflight has passed.
```

## Optional single-run and sample-export helpers

A guarded single-case runner exists and does not launch the solver unless
both flags are explicitly true. It avoids ever accidentally running the
entire 8-condition 3D grid:

```matlab
% This is read-only. Default control is cs=1.8 m/s, 500 Hz:
pilot=run_one_homogeneous_case();

% ONLY after reviewing expected 3D RAM and runtime:
% pilot=run_one_homogeneous_case( ...
%     Execute=true,ResourcesReviewed=true);

% After a validated solver run.mat exists:
% s=export_opposed_disk_sample(pilot.run_file, ...
%     Component="axial_total",ApplyFixedDonut=false);
% s=export_opposed_disk_sample(pilot.run_file, ...
%     Component="axial_shear",ApplyFixedDonut=true);
```

`export_opposed_disk_sample.m` saves standardized 2D observation samples
while retaining the exact homogeneous material truth. It reports the axial
shear-component squared-amplitude fraction of the two P/S split fields,
and flags weak axial shear. This is a **diagnostic ratio**, not an
independent proof of a pure shear measurement or full 3D modal energy.
The original `run.mat` remains untouched.

The converter's `Component="axial_total"` most closely matches a
physical axial-displacement measurement; `axial_shear` is a
diagnostic separation and must not be silently substituted for measured
`U_z`. Material truth here describes *input shear speed*, not
the phase speed of any compressional component in a mixed measurement.

**Not yet verified in MATLAB**. The custom `develop/v2` source is a
different API from the standard `main` bilayer configuration; do not
mix them as if they were interchangeable.
