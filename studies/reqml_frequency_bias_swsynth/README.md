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
