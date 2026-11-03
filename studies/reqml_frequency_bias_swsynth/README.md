# REQ-ML frequency-bias controls using swsynth V2

Three **separate, deterministic** source/medium groups, all measured as the
z component on the same 50 × 50 mm x-z observation FOV at 0.2 mm sampling
(251 × 251 samples). This is a complementary fast study; it does **not**
replace the full 3D k-Wave study.

| Group | Cases | Material / propagation |
| --- | ---: | --- |
| `plane_homogeneous` | 8 | 1.8 and 3.0 m/s × 300, 400, 500, 600 Hz; two coherent counterpropagating ±x shear plane waves; directional Eikonal |
| `plane_bilayer` | 4 | 1.8/3.0 m/s z-bilayer × the same four frequencies; **identical ±x incidence and phase**; directional Eikonal |
| `point_homogeneous` | 8 | Both homogeneous speeds × four frequencies; two coherent 13-node disks represented by spherical *point-force elements* |

## Physical design

- Both plane-wave groups have identical incidence directions
  `[+1,0,0]` and `[-1,0,0]`, equal amplitude, zero source phase,
  `in_plane_sv` polarization, a common z-axis readout and the same
  `projected3d` Eikonal solver. These are **incident plane waves**, not
  finite actuators.
- The bilayer has `cs=1.8 m/s` at z < 25 mm and `cs=3.0 m/s` at z >= 25 mm, corresponding to an interface at z=0 in the centered
  physical FOV. Here the material boundary is **horizontal**, normal to z;
  its position is provisional until matched to experimental phantom data.
- Point-source geometry duplicates the **physical locations of the sparse
  nodes** in the 0.5-mm k-Wave opposed-disk pilot: source planes x=-8 mm
  and x=58 mm relative to the 0–50 mm observed FOV, centers at z=25 mm,
  y=0, radius 3 mm, node pitch 1.5 mm, 13 nodes per disk. All 26 point
  elements are coherent, have x-directed force, equal relative amplitude,
  zero phase, and are observed via axial z motion.
- The point-source group uses **analytical homogeneous spherical shear
  radiation**, `1/r` geometric spreading and `sqrt_count`
  normalization. It **does not** impose the Dirichlet surface velocity of
  k-Wave, simulate compressional waves, reflect at boundaries, or model
  finite-contact stress. Amplitudes are relative.
- No attenuation, tracking noise or material dispersion. The frequency
  dependence of REQ-ML on these data therefore cannot be attributed to a
  constitutive frequency dependence **within the synthesizer**.

The point-source group is homogeneous only. The current V2 simulator
deliberately does not support heterogeneous spherical propagation
(see [framework issue #31](https://github.com/gsara798/shear-wave-simulation-framework/issues/31)).
Do not create a bilayer by passing heterogeneous speed maps to its
homogeneous spherical-wave option.

## Setup (after existing k-Wave jobs have finished)

This study lives in
`shear-wave-estimation-evaluation/studies/reqml_frequency_bias_swsynth/`.
It uses `run_simulation` from `shear-wave-simulation-framework`
`develop/v2` and **does not edit that framework**.

MATLAB:

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"studies","reqml_frequency_bias_swsynth"),"-begin")
clear prepare_swsynth_frequency_study run_swsynth_frequency_study
rehash

% Read-only plan: no JSON and no solver.
T=prepare_swsynth_frequency_study();

% Create or verify 20 deterministic JSON configurations (no simulation).
T=prepare_swsynth_frequency_study(WriteConfigs=true);

% Validate all 20 files using the real V2 JSON API; NO wave synthesis.
V=run_swsynth_frequency_study(Mode="validate");

% Execute all 20 after reviewing this protocol. Produces standard
% data/wavefield_sample.mat, metadata and figures for every case.
R=run_swsynth_frequency_study( ...
    Mode="run",ConfirmFullRun=true,MakePlots=true);
```

### Unit tests (no solver execution)

```matlab
tests=runtests("tests/test_reqml_frequency_swsynth_configuration.m");
disp(table(tests))
assert(all([tests.Passed]))
```

All output artifacts are under this study's ignored `outputs/` folder:

```text
studies/reqml_frequency_bias_swsynth/
  study_config.json
  prepare_swsynth_frequency_study.m
  run_swsynth_frequency_study.m
  README.md
  outputs/
    configs/{plane_homogeneous,plane_bilayer,point_homogeneous}/
    runs/{plane_homogeneous,plane_bilayer,point_homogeneous}/
    status/<case_id>.json
```

A completed case writes a status marker only after verifying the standard
`data/wavefield_sample.mat`. Re-running the study skips completed cases
whose markers and samples agree, and refuses to overwrite altered configs.
No existing k-Wave/experimental outputs are touched.

## REQ-ML analysis scope

Use the **same frozen estimators** (Reduced16 raw, Reduced16 filtered-v2,
Candidate10 filtered) and paired physical ROI/patch centers at all
frequencies. For bilayer, report errors by layer excluding an agreed
interface buffer; for homogeneous, inspect predicted q and apparent
`delta cs(600-300)`. The model-specific spatial donut 0.8–8 m/s must
be applied consistently to the whole complex field before patch
extraction for filtered arms. Synthesis and estimator application are
separate stages.

Important: the Eikonal solver encodes propagation travel time but not
full interface reflection, mode conversion, or amplitude transport.
A lack of frequency bias here would not disprove a k-Wave or
experimental geometry-induced effect. The three source groups should be
reported as separate controls, not pooled into one performance statistic.

**Validation status:** scripts and tests prepared in GitHub; MATLAB
unit tests, 20 dry runs, and actual wave synthesis remain to be verified
on the user's computer.


## ROI-based frozen-model comparison (after synthesis)

This second stage reproduces the **seven experimental inference arms** in
[reqml_sp_comparison](../reqml_sp_comparison/README.md) on the 20 synthetic
wavefields. **No EWP/IQ processing, no model retraining, and no new
swsynth/k-Wave simulation** occurs.

- **REQ-ML:** M=2, StepPixels=2; raw and globally filtered versions of the
  same input wavefield.
- **FFT donut:** the identical Q0-v5 implementation, with csMin=0.8 m/s,
  csMax=8 m/s and taper=0.06, applied to the full complex field.
- **Arms:** A_raw_v1, B_filtered_v1, C_filtered_v2, candidate10,
  candidate, candidate10_filtered, candidate_filtered. Frozen model bundles
  must already exist under the same REQ-ML paths as the experiment study.
- **Homogeneous ROI:** one center ROI at (x,z)=(25,25) mm, 10×10 mm.
- **Bilayer ROIs:** soft (25,12.5) mm and hard (25,37.5) mm, 10×5 mm
  each; both avoid the z=25 mm material interface.
- **Metrics:** SWS-Eval descriptive statistics, on-model and
  **common-valid-pixel** SWS, bias, MAE, MAPE, spatial SD/CV, median
  predicted q and mean-SWS shift from 300 to 600 Hz. Truth is known
  (homogeneous 1.8 or 3.0 m/s; bilayer soft 1.8/hard 3.0 m/s).

The comparison is implemented in:
- swsynth_comparison_config.m — seven arms, model sources, M/step, filter;
- swsynth_comparison_rois.m — central/layer ROIs and physical reference;
- run_swsynth_comparison.m — plan, filter, estimate, analyze, plot, all;
- analyze_swsynth_comparison.m — shared-support ROI statistics and errors;
- plot_swsynth_comparison.m — frequency panels and SWS map montages.

### How to run (after simulations complete)

~~~matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"src"))
addpath(fullfile(pwd,"studies","reqml_frequency_bias_swsynth"))
clear run_swsynth_comparison swsynth_comparison_config

% No writes; inspect which of the 20 simulations have completed:
plan=run_swsynth_comparison();

% One-case pilot with the three primary arms:
pilotCase="point_homo_cs180_f500";
primary=["A_raw_v1","C_filtered_v2","candidate10_filtered"];
run_swsynth_comparison(Stage="filter",CaseIDs=pilotCase);
run_swsynth_comparison(Stage="estimate",CaseIDs=pilotCase, ...
    Arms=primary,UseParallel=false);

% All seven arms (20 x 7 = 140 predictions, then ROI analysis and plots):
result=run_swsynth_comparison(Stage="all",UseParallel=false);

% Analysis and plots can be regenerated without reinference:
stats=run_swsynth_comparison(Stage="analyze");
figures=run_swsynth_comparison(Stage="plot");
~~~

A shorter primary comparison across all 20 cases is available via
Stage="all",Arms=primary (60 predictions). Run the separate analyze/plot
stages using the **same arm selection**. Make sure that the existing
REQ-ML reduced16-filtered-v2 deployment bundle is present first.

Files stay inside this study's ignored outputs folder:

~~~text
outputs/comparison/
  filtered/<case_id>/wavefield_sample.mat
  filtered/<case_id>/filter_manifest.mat
  estimates/<series>/REQ-ML/<arm>/<frequency>Hz/M2/reqml_result.mat
  analysis/all_cases_roi_statistics.csv
  analysis/frequency_shifts_300_600.csv
  analysis/comparison_figures/*.png
~~~

Alternative model-arm selections (or M/step settings) write their separate
ROI CSVs and figures under analysis/alternatives/<arm_set>/; they do not
replace the default seven-arm analysis.

Filtered samples and estimates are resumable with input/model fingerprint
checks; they are not overwritten on a mismatch. During other k-Wave jobs,
leave UseParallel=false.

Unit test (configuration/ROIs/plan only, no inference):

~~~matlab
runtests("tests/test_reqml_swsynth_comparison_config.m")
~~~

**Interpretation:** all arms are compared on common valid patch centers
**within each frequency**. Patch center grids can differ with frequency
because of the wavelength-dependent window size; 300–600 Hz shifts are ROI
summaries, not paired-pixel differences. Spatial SD is not a confidence
interval. The nondispersive Eikonal bilayer excludes complete reflections
and mode conversion; spherical point forces are not finite-contact
k-Wave actuation. Any frequency bias here is conditional on this
synthetic observation model.



### Changing StepPixels without losing earlier estimates

The inference results now have a step-aware output layout. Previous files
saved at M2/reqml_result.mat are **not moved or overwritten**. They remain
available when their recorded comparison identity contains the requested
StepPixels. For a new step, predictions are saved under
M2/step<N>/reqml_result.mat (e.g. M2/step1/reqml_result.mat).
ROI summaries and figures from non-default steps are isolated under the
corresponding analysis/alternatives/M2_step<N>_... folder.

Explicitly pass StepPixels: omitting it still means **StepPixels=2**.

~~~matlab
% Example: change to StepPixels=1; adjust to your desired step.
results=run_swsynth_comparison( ...
    Stage="all",StepPixels=1,UseParallel=true);
~~~

The raw and filtered wavefields are independent of StepPixels and are
reused. If a saved estimate for the *same* step differs in sample or model
fingerprint, inference stops and reports the changed fields. Inspect
that mismatch before deciding whether to create a separate comparison;
do not delete the earlier estimate.

**Execution status:** MATLAB tests, model inference and numeric comparisons
remain to be run/verified on the user's Mac.
