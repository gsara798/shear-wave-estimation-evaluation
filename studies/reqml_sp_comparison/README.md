# Experimental REQ-ML comparison — SP phantoms, M=2

Study-specific scripts live here, not in REQ-ML training. This study
**orchestrates** three existing packages: EWP for IQ processing, REQ-ML for
SWS prediction, SWS-Eval for ROI analysis and maps. No new estimator,
retraining, or simulation is implemented by this study.

## Protocol and model arms

Frozen first-stage data: `2026Feb27_dl_sp`,
`2026Feb27_homo_5perc_sp`, and `2026Feb27_homo_10perc_sp`;
300/400/500/600 Hz; M=2; StepPixels=2; no SVD mode removal.
ROI1: center [18 10], size [10 5] mm.
ROI2: center [18 25], size [10 5] mm.
These are physical (x,z) centers; confirm they cover the intended tissue.

| Name | Spatial preprocessing | Model |
| --- | --- | --- |
| A_raw_v1 | None | frozen reduced16 v1 |
| B_filtered_v1 | Global FFT donut 0.8–8 m/s, taper 0.06 | frozen reduced16 v1 |
| C_filtered_v2 | Same filtered wavefield as B | new frozen reduced16-filtered v2 |
| candidate10 | None | original candidate10 |
| candidate | None | original candidate |

EWP runs **once** with no spatial filter. The already processed, isotropically
sampled complex harmonic field is filtered using exactly the
`q0v5.filter.applyFixedDonut` code from the training campaign; raw and
filtered observations have the same grid and temporal processing. The old
candidate models are run on the same unfiltered wavefields; this need not
replicate their historical acquisition pipeline.

## Organization

- `sp_comparison_config.m` — one shared configuration (paths, models, runs,
  frozen ROI and frequency policy).
- `run_processing.m` — EWP no-spatial-filter + derived 0.8–8 donut wavefields.
- `run_estimation.m` — reuse the five fitted models, save estimates.
- `run_analysis.m` — call swseval.analyzeSweep; combine ROI tables.
- `plot_model_comparison.m` — five-model maps and frequency/ROI figures.
- `run_plots.m` — short entry point for just the visualizations.

**Important:** none of these filenames should be copied back into REQ-ML
training. The original study controller `run_reqml_sp_comparison.m` in a
user's local req-ml tree can be retired once this version is confirmed to work.

## Run from MATLAB

Update the `shear-wave-estimation-evaluation` **main** branch; use an existing
REQ-ML checkout containing the Q0-v5 donut and saved models. Make sure your EWP
checkout provides `SpatialFilterMode="none"` and `RunName`.

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"src"))
addpath(fullfile(pwd,"studies","reqml_sp_comparison"))
clear functions
rehash

% Stage 1 — resumable: finished old samples are reused.
run_processing();

% Stage 2 — resumable: existing per-model estimate files are reused.
run_estimation();

% Stage 3 — ROI tables and comparative plots.
result=run_analysis();
disp(result.summary)

% Optional: only recreate figures.
run_plots();
```

You can call e.g. `run_processing(UseParallel=false)` if parallel resources
are constrained. Dependencies are added from explicit local paths in
`sp_comparison_config.m`, with the same defaults as the original study.

## Resuming a previously interrupted local run

**Do not move, delete, or regenerate** the existing experiment outputs. Paths
and run identifiers are unchanged from the earlier controller:

```text
<experiment>/processed/reqml_compare_raw_no_spatial_v1/
<experiment>/processed/reqml_compare_global_donut_0p8_8_v1/
<experiment>/estimates/reqml_sp_compare_m2_0p8_8_v1/REQ-ML/<arm>/<f>Hz/M2/reqml_result.mat
<experiment>/analysis/reqml_sp_compare_m2_0p8_8_v1/
<DataRoot>/reqml_sp_compare_m2_0p8_8_v1/all_experiments_roi_statistics.csv
```

The new code preserves the original per-sample, per-model fingerprint and
resume checks. **If any pre-existing output has a different recorded
signature, the study will stop instead of silently mixing versions.**
For the filtered-v2 model bundle, a leftover `.partial.mat` from an interrupted write is now automatically **validated against the frozen fitted checkpoint** (model ID, complete required fields, predictor order, source signature/size/date, filter parameters, and sample predictions). Only if valid is it atomically promoted to `model_bundle.mat`; invalid partials remain untouched with an explicit diagnostic. Interrupted prediction outputs still require inspection before reuse.

Filtered-v2 deployment is packaged from the *existing trained checkpoint*
into `req-ml/models/reduced16_filtered_v2/model_bundle.mat`, without
refitting. The baseline models are read-only. The historical candidate10
directory must contain a unique valid `model_bundle.mat`; the script will
not guess its training feature order or substitute another candidate.

## Evaluation and interpretation

`swseval.analyzeSweep` writes per-experiment ROI statistics and maps and
this study creates comparison panels of SWS means, spatial standard
deviations, CV, five-model SWS maps and A/B/C changes in ROI mean. A lower
spatial CV does **not** establish accuracy, and ROI spatial std is **not**
a confidence interval. No phantom ground-truth SWS is assumed.

### Compatibility

The migration copies the **same implementation** used by the former
`run_reqml_sp_comparison.m` + `plot_reqml_sp_comparison.m`, splitting
the controller into stage-specific files. Only the entry points and
code organization change; the experiment paths and frozen parameters remain
unchanged. **MATLAB execution has not yet been verified** here.
