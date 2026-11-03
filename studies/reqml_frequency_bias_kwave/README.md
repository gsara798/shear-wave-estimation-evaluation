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

## 0.5-mm feasibility pilot (November 3, 2026)

The computationally expensive frozen `study_config.json` **continues
to specify 0.2 mm** for any later resolution/convergence comparison.
To test the opposed-disk physics sooner, the configuration generator and
single-case runner now accept `GridSpacingM=0.0005`, with **no alteration
of the 0.2-mm configs**.

| Quantity | 0.5-mm pilot | 0.2-mm reference |
| --- | --- | --- |
| Computation | 141 × 49 × 129 = 891,261 nodes | 351 × 121 × 321 = 13,633,191 nodes |
| Observation FOV | 50 × 50 mm | 50 × 50 mm |
| Observation pixels | approx. 101 × 101 | approx. 251 × 251 |
| Source disk radius | 3 mm | 3 mm |
| Sparse source-node spacing | 3 cells = 1.5 mm | 8 cells = 1.6 mm |
| Source velocity direction | x | x |
| Material and frequency for pilot | 1.8 m/s, 500 Hz | 1.8 m/s, 500 Hz |
| Computation box | 70 × 24 × 64 mm | 70 × 24 × 64 mm |

The **0.5-mm outputs cannot overwrite 0.2-mm results**. They are kept under:

```text
<original-output-root>/
  resolution_pilots/
    dx0p5mm/
      configs/homo_cs180_f500.json
      runs/homo_cs180_f500/run.mat
```

After **interrupting and confirming the 0.2-mm k-Wave job has stopped**,
run from MATLAB:

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"studies","reqml_frequency_bias_kwave"))
clear prepare_homogeneous_pilot run_one_homogeneous_case
rehash

% Preview 0.5-mm grid and output paths without launching the solver.
T=prepare_homogeneous_pilot(GridSpacingM=0.0005);

% Launch just ONE 0.5-mm case, once machine resources are confirmed.
pilot=run_one_homogeneous_case(GridSpacingM=0.0005, ...
    CaseID="homo_cs180_f500", ...
    Execute=true,ResourcesReviewed=true);
```

This is a **feasibility test**, not a converged reference. At 1.8 m/s
and 500 Hz, the shear wavelength is 3.6 mm, giving 7.2 grid points
per shear wavelength at 0.5 mm; at 600 Hz it would be 6 points per
wavelength. Verify solver accuracy/convergence before using the
0.5-mm outputs as quantitative truth. In particular, assess the P/S
components of the observed axial field before interpreting REQ-ML bias.
The actual solver time has not been measured here.

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

## Updated framework dependency (develop/v2, 2026-11-03)

The custom opposed-disks runner has been corrected in
`shear-wave-simulation-framework` `develop/v2`:
- k-Wave 1.4.1 `DataCast` and other legacy parameter values use MATLAB
  character vectors rather than `string` scalar values.
- The solver records the 251×251 observed central plane instead of all
  351×321 central-plane points, reducing the memory reserved for retained
  P/S time series without changing the physical solver domain or FOV.
- `setup_simulation_framework(KWavePath=...)` now adds the external toolbox
  root to the MATLAB function path when configured.
- Runtime logging prints a lower-bound size for four recorded P/S time-series
  arrays; total peak memory can be substantially larger.

Update **the develop/v2 simulation checkout**, not just this SWS-Eval
repository, before re-running the solver. MATLAB execution of the modified
3D solver has not yet been verified.

## Configuration resume and existing JSONs

`prepare_homogeneous_pilot(WriteConfigs=true)` is idempotent for
configuration files that contain the same physical values. It now compares
JSON *canonically*, because order of keys in a JSON object has no semantic
meaning, but `isequaln` on MATLAB structs can reject a reordered key
sequence. Any **true difference in values** still raises
`FreqBias:ConfigChanged` and preserves the original file. The runner also
checks `ResourcesReviewed` **before** causing file-writing side effects
when `Execute=true`.

If you already wrote the eight files, simply rerun:

```matlab
clear prepare_homogeneous_pilot run_one_homogeneous_case
rehash
T=prepare_homogeneous_pilot(WriteConfigs=true);
pilot=run_one_homogeneous_case(); % read-only; does not execute k-Wave
```

Do not manually delete or overwrite the generated JSONs. A valid
`WriteConfigs=true` pass does **not** imply the heavy 3-D solver has
sufficient resources.

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


## Bilayer extension (prepared, not simulated)

The **same opposed x-driven disks** can now be used for a controlled
nondispersive z-bilayer (soft 1.8 m/s, hard 3.0 m/s) at 300–600 Hz.
Both repositories have matching feature branches. Configuration-only
preflight, guarded single-run instructions, source-identity regression
tests, separate 0.5-mm outputs and per-pixel truth export are documented
in [BILAYER_PILOT_README.md](BILAYER_PILOT_README.md).

The z=0 mm interface is a provisional simulation control, not a
measurement of the experimental phantom's layer boundary. The bilayer
runner has not been validated by a MATLAB solver execution. Do not
change simulation code branches while homogeneous parfor jobs are active.
