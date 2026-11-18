# Adaptive REQ-ML — final experimental evaluation

This directory contains the **new** experimental evaluation workflow for the
frozen Adaptive REQ-ML Full21 estimator and quality mask, once publication
of their bundles and the independent TEST equivalence check finishes. It is separate
from `studies/reqml_experimental_qmv2` and does not change prior estimates,
masks, training data, or ROI analyses.

## Stage 01 — process eight acquisitions (implemented)

Run the MATLAB script:

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
run("studies/adaptive_req_final_experimental/run_01_process_wavefields.m")
```

Edit the settings at the beginning of the script:

- `DataRoot`: experimental dataset root (default: `/Users/sara/local/experimental-data-reorganized`)
- `EwpRoot`: EWP checkout
- `RunName`: unique processing run, currently `adaptive_req_final_unfiltered_v1`
- `SelectedCaseIDs`: leave empty to run **all eight**, or select case IDs for a pilot
- `PreviewOnly=true`: inspect input filename pattern and available frequencies
  without processing, writing results or generating figures
- `UseParallel`: enable the EWP parallel displacement calculation
- `FigureFormats`: PNG, PDF, FIG by default

Datasets:

| Date | Dataset |
| --- | --- |
| 2026-02-27 | 2026Feb27_homo_10perc_sp |
| 2026-02-27 | 2026Feb27_homo_10perc_rswe |
| 2026-02-27 | 2026Feb27_homo_5perc_sp |
| 2026-02-27 | 2026Feb27_homo_5perc_rswe |
| 2026-02-27 | 2026Feb27_dl_sp |
| 2026-02-27 | 2026Feb27_dl_rswe |
| 2026-02-19 | 2026Feb19_inc_sp |
| 2026-02-19 | 2026Feb19_inc_rswe |

The February 27 acquisitions are expected to use
`raw/test1_{frequency}Hz.mat`. February 19 raw naming was not verified;
the script discovers unique `{frequency}Hz` patterns. If multiple patterns
exist, it flags an ambiguity rather than choosing an arbitrary acquisition.
Edit `filePatterns` for the corresponding experiment if necessary.

Available frequencies are selected from 300, 400, 500, and 600 Hz and
reported when missing. The script continues across other datasets when
one dataset fails.

**EWP settings:** no spatial filtering; no SVD modes removed; temporal
FIR half-bandwidth 20 Hz; 12-cycle lock-in; isotropic sampling; axial
Loupas processing; optional parallelization. Raw IQ files are untouched.

The script calls `ewp.runFrequencySweep` with `SaveFigures=false`,
`SaveMovies=false`, and `SaveIntermediate=false`, then invokes
`ewp.viz.renderWavefieldSample` and `ewp.viz.renderBmodeAcquisition`
to export **still figures only**. This avoids retaining large temporal
intermediate arrays just to create plots. From `wavefield_sample.mat`
we can render final harmonic maps; additional pre/post temporal fields
or spectra that require `intermediate.mat` will not be available.

**Required EWP version:** a checkout containing
`ewp.viz.renderBmodeAcquisition` and
`ewp.viz.renderWavefieldSample`; the
`feature/bmode-alias-and-sweep-plots` branch contains both.

Output for each acquisition/frequency:

```text
<dataset>/processed/adaptive_req_final_unfiltered_v1/
  run_config.json
  sweep_summary.csv
  sweep_manifest.json
  300Hz/
    wavefield_sample.mat
    processing_manifest.json
    plots/
      bmode.png / .pdf / .fig
      summary_filtered.png / .pdf / .fig
      harmonic_final_isotropic_*.png / .pdf / .fig
```

The cross-dataset status table is saved to:

```text
<data-root>/analysis/adaptive_req_final_experimental_v1/processing_summary.csv
```

`Resume=true` skips completed wavefield calculations. Missing plots
are produced from saved samples without reprocessing. The EWP run
configuration is immutable under the same run name; modify `RunName`
if the processing parameters change.

## Stage 02 — estimate unfiltered SWS with final Full21 (implemented)

Stage 02 deliberately **does not** reprocess IQ, apply a spatial
filter, train a model, or score the quality mask.

The script is:

```matlab
run("studies/adaptive_req_final_experimental/run_02_estimate_sws.m")
```

It is a nested sweep over the same eight acquisitions,
300/400/500/600 Hz, and **M = 1, 2, 3**. Only existing
`processed/adaptive_req_final_unfiltered_v1/<frequency>Hz/wavefield_sample.mat`
inputs are used.

### Progress diagnostics and timing

The stage-02 script has `Verbose=true` by default. It reports
`[SETUP 1/3]` through `[SETUP 3/3]`, the observation plan, and three
`[PREFLIGHT]` checkpoints **before** the first `[1/96]` job.
It no longer calls `whos("-file")` on `req_model.mat`: the standalone
MAT inspection was redundant. The Full21-specific loader validates the
published regression model and operating specification, once per run,
followed by predictor checks.

For every case/frequency/M job, it reports input provenance checks,
resume checks, inference start/end, validation/save, valid patch
fraction, and elapsed times. The internal `reqml.predictSWS`
`Verbose` option is also enabled. Internal REQ-ML messages identify
feature extraction and q/SWS prediction stages, but they do not report
per-window progress or separate elapsed times for those internal phases.

Set `Verbose=false` near the start of the script to reduce detailed
sub-step messages while retaining main checkpoint/job progress lines.

### Preflight before prediction

The default `Mode="plan"` is strictly read-only: it lists the **96
estimation jobs** (8 experiments × 4 frequencies × 3 M values), their
processed-sample and existing-estimate availability, and whether the
final model-release files exist.

The script expects the output of
`publish_adaptive_req_full21(Mode="publish",ConfirmPublish=true)`
in `/Users/sara/local/req-ml/models/adaptive_req_full21_v1/`:

- `req_model.mat`
- `quality_mask.mat`
- `operating_spec.mat`
- `deployment_manifest.json`

Only the first file is used for inference. All four are checked as one
versioned published release; step 03 will use the mask.
**Run `verify_published_adaptive_req_full21()` before invoking stage 02.**
The inference script does not invoke TEST or verify TEST equivalence itself.

**Final Full21 compatibility:** the published `req_model.mat`
contains `model` and `model_info`, not the legacy Q0 fields
`model_metadata` and `predictor_names`. A separate
`load_adaptive_req_full21_sws_bundle.m` helper reads the frozen
`operating_spec.mat`, release manifest and the Full21 regressor, checks
the 21 ordered predictors, the unfiltered TRAIN provenance, model ID,
clip range and tree configuration, then supplies a validated
`ModelBundle` to the unchanged `reqml.predictSWS` physical REQ
pipeline. **No models are retrained or rewritten.** The helper loads
only the final REQ regressor (not the large classifier); the original
`quality_mask.mat` will be used in stage 03. The model may take time to
load on MATLAB, but it is loaded only once before the estimation loop.
The obsolete call to `reqml.models.loadQ0Model` has been removed.

For a dry-run:

```matlab
% In run_02_estimate_sws.m:
Mode = "plan";
```

For a pilot after the release and step 01 are ready:

```matlab
% Edit settings at top of script:
Mode = "run";
SelectedCaseIDs = "2026Feb27_homo_10perc_sp";
FrequenciesHz = [300 600];
MValues = [1 2 3];
```

For all eight experiments:

```matlab
Mode = "run";
SelectedCaseIDs = strings(1,0);
FrequenciesHz = [300 400 500 600];
MValues = [1 2 3];
```

The estimator is called separately for `M=1`, `M=2`, and `M=3`
with `StepPixels=5`, `UseParallel=true`, and `RequireTruth=false`,
using the same explicitly loaded Full21 model. Estimated `q_map`, `cs_map`,
`valid_mask`, and `patch_examples` remain together so the
frozen mask can use the identical patch features later.

Output (one per case/frequency/M):

```text
<dataset>/estimates/adaptive_req_final_experimental_v1/REQ-ML/
  adaptive_req_full21_unfiltered_v1/300Hz/M1/step5/reqml_result.mat
  adaptive_req_full21_unfiltered_v1/300Hz/M2/step5/reqml_result.mat
  adaptive_req_full21_unfiltered_v1/300Hz/M3/step5/reqml_result.mat
```

A run-specific report goes to:

```text
<data-root>/analysis/adaptive_req_final_experimental_v1/
  estimation_reports/<timestamp>/sws_estimation_summary.csv
```

Resume behavior checks a saved `inference_identity` recording the
input and published-model file identities, the model label, M, step,
and the unfiltered processing run. Matching estimates are reused;
mismatched estimates are never silently replaced. A partial output is
flagged rather than overwritten. Missing samples are recorded
per frequency/M combination, and the loop continues unless
`ContinueOnError=false`.

This script has been inspected against GitHub's public REQ-ML inference
API, but **has not been executed on the Mac** and the latest Full21
publisher source is not yet present on the reviewed GitHub branch.

## Stage 03 — frozen Full21 quality mask (implemented)

The quality mask is scored on **stage-02 saved predictions**, not on
new wavefield processing or recomputed q. The frozen classifier takes
the original 21 ordered Full21 predictors **plus saved predicted q** as
the last (22nd) input. The positive-class ensemble score measures risk
of **SWS APE > 10%** (it is not a calibrated probability). The risk
threshold was fixed from **independent VALIDATION**, not from phantom
results or TEST.

**Quantile provenance (important fix):** in the REQ-ML feature
extractor, `patch_examples.q_pred` stores the **local non-ML REQ**
baseline (`q_local_req`), *not* Full21's predicted quantile. Stage 02
stores the fitted Full21 quantile in `q_map` and
`patch_predictions.q_pred`. Stage 03 uses `q_map` as the mask's 22nd
input, with an exact row-aligned cross-check against
`patch_predictions.q_pred`. Never compare Full21 `q_map` against
`patch_examples.q_pred`: doing so caused all 96 step-3 mask jobs to
fail with a false `AdaptiveREQ:MaskQMismatch` error (2026-11-17).
No model, score cutoff or input wavefield changed in this fix.

The stage-03 script and helpers are:

- `run_03_apply_quality_mask.m` — one loop across all eight experiments,
  four frequencies and `MValues=[1 2 3]` (96 mask jobs)
- `load_adaptive_req_full21_quality_mask.m` — reads only the saved
  classifier, operating spec and manifest; **never loads the giant q
  regressor again**
- `score_adaptive_req_full21_quality_mask.m` — uses exactly the
  saved `patch_examples`, `q_map`, `cs_map` and map-center indices
- `test_step_03_quality_mask.m` — fast synthetic structural tests

To inspect inputs without loading the classifier or saving anything:

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
% In run_03_apply_quality_mask.m:
Mode = "plan";
run("studies/adaptive_req_final_experimental/run_03_apply_quality_mask.m")
```

For a pilot, change the settings near the beginning of the script:

```matlab
Mode = "run";
SelectedCaseIDs = "2026Feb27_homo_10perc_sp";
FrequenciesHz = [300 600];
MValues = [1 2 3];
```

For the full eight-case experiment:

```matlab
Mode = "run";
SelectedCaseIDs = strings(1,0);
FrequenciesHz = [300 400 500 600];
MValues = [1 2 3];
```

Run the synthetic unit tests first if MATLAB's Statistics and Machine
Learning Toolbox is available:

```matlab
runtests("studies/adaptive_req_final_experimental/test_step_03_quality_mask.m")
```

Only finite valid SWS windows with finite classifier inputs are scored.
The saved quality result contains four disjoint statuses:

1. **Retained**: valid, scored and risk score ≤ frozen cutoff
2. **Rejected**: valid, scored and risk score > frozen cutoff
3. **Unscored**: originally valid SWS but no finite risk score
4. **Invalid**: originally invalid SWS (outside the denominator)

`retained_mask`, `rejected_mask` and `unscored_mask` partition the
originally valid set. An unscored pixel is **never** treated as retained.
The output also preserves `original_sws_map`, `masked_sws_map`,
`risk_score_map`, `q_map`, physical `x_mm/z_mm` coordinates,
original/retained/rejected counts and the exact cutoff.

For example, a case at 300 Hz and M=2 saves:

```text
<dataset>/analysis/adaptive_req_final_experimental_v1/
  M2_step5/quality_mask_full21_locked_v1/masks/
    adaptive_req_full21_unfiltered_v1/300Hz/risk_mask_result.mat
```

A CSV summary of each run is saved separately:

```text
<data-root>/analysis/adaptive_req_final_experimental_v1/
  quality_mask_reports/<timestamp>/quality_mask_summary.csv
```

Mask outputs never overwrite stage-02 estimates. On rerun,
`mask_identity` checks the source estimate, original inference identity,
all published release files, the M/step and the frozen cutoff. Compatible
checkpoints are reused; mismatches fail rather than overwriting anything.
A missing estimate is reported and skipped by default.

**Validation status:** logic was inspected against the frozen final model
and earlier QMV2 scoring conventions; no experimental MATLAB execution
was available in GitHub. Run the synthetic tests and start with a pilot
before launching all 96 jobs. Observed retention may differ from the
80% VALIDATION target: do not force it experimentally.



## Stage 04 — paper SWS maps and physical B-mode overlays (implemented)

Script: `run_04_plot_sws_maps.m`. It scans the same eight experiments,
300/400/500/600 Hz and **M=1,2,3** (96 potential figure jobs). It reads
the immutable stage-02 `result` and stage-03 `quality_result` files:
no IQ processing, new q prediction, mask retraining or model loading.

Output formats are **PNG (300 dpi), PDF, and MATLAB FIG**, with
`swseval.viz.mapColormap()` (the existing REQ paper SWS palette),
**fixed CLim 1.5–3.5 m/s**, colorbar ticks 1.5, 2.0, ..., 3.5
and consistent **one-decimal axis/colorbar formatting**.

Per experiment / frequency / M, outputs include:

- `individual/sws_original_plain.*`
- `individual/sws_masked_plain.*` (when mask exists)
- `individual/sws_original_bmode_rois.*` (when B-mode aligns)
- `individual/sws_masked_bmode_rois.*` (when mask and B-mode align)
- `combined/sws_comparison_2x2.*` (all four arrangements, shared
  colorbar), or `combined/sws_comparison_1x2_no_bmode.*`
  when physical B-mode alignment cannot be verified

The original and masked maps always use identical physical coordinates
and limits; no interpolation or cosmetic filling of rejected regions is
performed. ROI rectangles appear on maps, while panel labels (a–d)
are unobtrusive and plots have no manuscript titles.

**ROI provenance:** `adaptive_req_final_case_rois.m` reads the exact
previously reviewed `../reqml_experimental_qmv2/experiment_manifest.example.json`.
Homogeneous phantoms have **central** only; bilayer has **soft** and
**hard**; inclusion retains **inclusion_core** and **background_ref**
(the exploratory `inclusion_large` ROI is excluded). This avoids
silently choosing new physical ROIs.

**B-mode provenance:** `load_adaptive_req_final_bmode.m` locates the
exact raw Verasonics MAT using EWP's
`processed/<run>/<Hz>/processing_manifest.json.source_file`.
It accepts both `IQBmodeData` and `BmodeIQ`, loads only the 2D
B-mode IQ and `dinf.dx/dz`, checks the raw `IQData1` *dimensions*
without loading the IQ movie, and requires physically consistent
image/map extents. Invalid or missing B-mode is **never** fabricated
from the wavefield. The script emits plain maps and reports an absent
overlay; `RequireBmode=true` instead makes it a per-job failure.
The B-mode is logarithmically normalized from −60 to 0 dB, as in EWP.

To start with a pilot (edit script settings):

```matlab
Mode = "run";
SelectedCaseIDs = "2026Feb27_homo_10perc_sp";
FrequenciesHz = 300;
MValues = 2;
run("studies/adaptive_req_final_experimental/run_04_plot_sws_maps.m")
```

Then run all experiments with:

```matlab
Mode = "run";
SelectedCaseIDs = strings(1,0);
FrequenciesHz = [300 400 500 600];
MValues = [1 2 3];
```

If a plot run reports **0/96 stage-02 estimates**, stage 04 now stops
before rendering with an actionable error, the exact expected MAT path,
and the latest stage-02 estimation status breakdown if available.
In that case run `run_02_estimate_sws.m` with `Mode="run"` and confirm
its report contains `completed` or `reused` jobs. The 32 processed
wavefield samples from stage 01 are not the same as 96 SWS estimate files.

By default `Mode="plan"` is read-only and lists missing inputs;
`Overwrite=false` reuses existing figures; `RequireMask=false`
allows originals while step 03 is incomplete. Set `RequireMask=true`
to insist on paired comparison figures.

Example outputs:

```text
<dataset>/analysis/adaptive_req_final_experimental_v1/
  M2_step5/paper_figures_full21_v1/
    adaptive_req_full21_unfiltered_v1/300Hz/
      individual/
      combined/
```

Each run saves a non-destructive status report at
`<data-root>/analysis/adaptive_req_final_experimental_v1/figure_reports/<timestamp>/sws_figure_summary.csv`.

Unit/smoke tests for ROI geometry, B-mode grid validation and figure
exports:

```matlab
runtests("studies/adaptive_req_final_experimental/test_step_04_paper_figures.m")
```

**Validation status:** the implementation has been checked against
SWSEval, EWP, and earlier experimental ROI code in GitHub. It has **not**
yet been run with the local MATLAB experimental MAT files. Pilot one
case before producing the full set.

## Stage 05 — physical ROI statistics (planned)

Analyze physical ROIs and plot SWS versus frequency for all M values
and both original/masked maps; show spatial SD as **spatial variability**,
not as a confidence interval for the mean. Inclusion/background contrast
will be descriptive unless an independent reference is supplied.

