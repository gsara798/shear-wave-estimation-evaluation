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
| candidate10_filtered | Same global FFT donut as B/C | original candidate10 (no retraining) |
| candidate_filtered | Same global FFT donut as B/C | original candidate (no retraining) |

EWP runs **once** with no spatial filter. The already processed, isotropically
sampled complex harmonic field is filtered using exactly the
`q0v5.filter.applyFixedDonut` code from the training campaign; raw and
filtered observations have the same grid and temporal processing. The historical candidate models are evaluated on **both** the same unfiltered and the same filtered wavefields. No legacy model is retrained. The raw paths need not reproduce the candidates' original historical processing pipeline.

## Organization

- `sp_comparison_config.m` — one shared configuration (paths, models, runs,
  frozen ROI and frequency policy).
- `run_processing.m` — EWP no-spatial-filter + derived 0.8–8 donut wavefields.
- `run_estimation.m` — reuse the five fitted models across seven inference arms, save estimates.
- `run_analysis.m` — call swseval.analyzeSweep; combine ROI tables.
- `plot_model_comparison.m` — seven-arm maps and frequency/ROI figures.
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


## Adding the two filtered historical candidates (2026-11-03)

The original five arms (A/B/C/candidate10/candidate) finished for all three
SP experiments. The following two arms were appended **without changing the
name of the study, the existing output layout, model checkpoints, or EWP
processing**:

- `candidate10_filtered`: same candidate10 bundle as `candidate10`,
  but input from `reqml_compare_global_donut_0p8_8_v1`.
- `candidate_filtered`: same candidate bundle as `candidate`,
  but input from the same filtered run.

Only **24 new estimate files** should be calculated (2 new arms × 3
experiments × 4 frequencies, M=2); older estimates are verified and skipped
when `Resume=true`. Existing filtered wavefields are reused; do **not**
call `run_processing()` again just for this extension.

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"src"))
addpath(fullfile(pwd,"studies","reqml_sp_comparison"))
clear functions
rehash

run_estimation();       % resume five originals, compute only two new arms
results=run_analysis(); % updated combined seven-arm ROI CSV and figures
disp(results.summary)

% Later: regenerate seven-arm figures without inference/ROI recomputation:
run_plots();
```

New plots include seven-arm frequency-vs-SWS/CV panels, seven-map montages
(files named `seven_model_SWS_maps_...`) and a new
`candidate_filter_effect_roi_mean` figure with the paired
filtered-minus-raw effect for both historical candidates. The A/B/C paired
mean-SWS figure is retained.

**Interpretation:** a smaller CV or change in ROI mean with filtering is
not itself proof of more accurate shear-wave speed. Compare exact matching
frequency/ROI, keep spatial SD distinct from confidence intervals, and
do not treat candidate10 or candidate as being retrained on filtered
features. All results remain descriptive unless independent experimental
reference speeds are available.

## Evaluation and interpretation

`swseval.analyzeSweep` writes per-experiment ROI statistics and maps and
this study creates comparison panels of SWS means, spatial standard
deviations, CV, seven-arm SWS maps, A/B/C changes in ROI mean and the paired
spatial-filter effects for candidate10 and candidate. A lower
spatial CV does **not** establish accuracy, and ROI spatial std is **not**
a confidence interval. No phantom ground-truth SWS is assumed.

### Compatibility

The migration copies the **same implementation** used by the former
`run_reqml_sp_comparison.m` + `plot_reqml_sp_comparison.m`, splitting
the controller into stage-specific files. Only the entry points and
code organization change; the experiment paths and frozen parameters remain
unchanged. **MATLAB execution has not yet been verified** here.

## Reduced14 transfer: raw and filtered SP comparison (2026-11-04)

This extension adds two **opt-in** inference arms to the original seven;
all pre-existing seven-arm estimates and analysis outputs retain their
original paths:

| Arm | Input wavefield | Fitted model | Interpretation |
| --- | --- | --- | --- |
| `reduced14` | Existing `reqml_compare_raw_no_spatial_v1` | Same Q0-v5 Reduced14 train-210 bundle | Matched to unfiltered training preprocessing |
| `reduced14_filtered` | Existing `reqml_compare_global_donut_0p8_8_v1` | **The same unfiltered-trained Reduced14 bundle** | Exploratory filter-transfer sensitivity; **not** retrained with filtering |

Reduced14 removes `ecum_increment_entropy` and
`srad_proxy_centroid_k_norm` from Reduced16. The new bundle comes from
the frozen 210-training-geometry validation checkpoint; there is no
new independent TEST claim for this version. Before inference, export
the checkpoint in the REQ-ML checkout with:

~~~matlab
cd("/Users/sara/local/req-ml")
addpath(fullfile(pwd,"training","q0_v5_clean_campaign"),"-begin")
export_q0_v5_reduced14_transfer(Mode="plan"); % read-only identity check
bundle=export_q0_v5_reduced14_transfer(Mode="run");
~~~

This must produce
`training/q0_v5_clean_campaign/outputs/reduced14_transfer_bundle_v1/model_bundle.mat`
in REQ-ML. It does **not** refit the model or change `models/current`.

### Run only the two new models

The SP datasets already processed for the original comparison have
three experiments and four frequencies. **No IQ/Loupas/EWP processing
or spatial filtering needs to be repeated.** At M=2, StepPixels=2:

~~~matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"src"),"-begin")
addpath(fullfile(pwd,"studies","reqml_sp_comparison"),"-begin")
clear sp_comparison_config run_estimation run_analysis run_plots ...
    plot_model_comparison
rehash

% Single-phantom pilot: 2 arms x 4 frequencies = 8 new estimates.
pilot=run_estimation( ...
    Experiments="2026Feb27_dl_sp", ...
    Arms=["reduced14","reduced14_filtered"], ...
    UseParallel=false);

% Complete 3 phantoms x 4 frequencies x 2 arms = 24 estimates.
% The 8 pilot estimates are validated and resumed.
new=run_estimation( ...
    Arms=["reduced14","reduced14_filtered"], ...
    UseParallel=true);
~~~

The new estimates are placed under the **existing**
`<experiment>/estimates/reqml_sp_compare_m2_0p8_8_v1/REQ-ML/`
root, but in separate `reduced14` and `reduced14_filtered` folders.
The same existing raw and global-donut wavefields are reused.
The estimate identity includes source/model file fingerprints and
`StepPixels`; incompatible existing files are not replaced.

### Analyze all nine arms without replacing the seven-arm results

~~~matlab
legacy=["A_raw_v1","B_filtered_v1","C_filtered_v2", ...
    "candidate10","candidate", ...
    "candidate10_filtered","candidate_filtered"];
allNine=[legacy,"reduced14","reduced14_filtered"];

results=run_analysis(Arms=allNine,MakeComparisonPlots=true);
disp(results.summary)

% Regenerate nine-arm figures without new predictions:
figures=run_plots(Arms=allNine);
~~~

The original **estimate** study name is preserved, while nine-arm
**analysis** is isolated to
`reqml_sp_compare_m2_0p8_8_v1_reduced14_9arms_v1`.
The original seven-arm CSVs and figures stay untouched.
Nine-arm outputs contain per-phantom ROI statistics, frequency plots
of mean SWS ± spatial SD and CV, nine-map montages, and a paired
filtered-minus-raw Reduced14 ROI-mean curve alongside candidate models.

The pre-existing ROIs are fixed at centers [18,10] and [18,25] mm
with 10×5 mm rectangles. Check that they correspond to the intended
tissue region in each phantom.

**Scientific caveat:** a flatter SWS-frequency curve and lower spatial
CV are not sufficient to establish accuracy without an independent
experimental SWS reference. In particular, comparing
`reduced14_filtered` with `reduced14` measures the impact of
applying the donut to a raw-trained model; it does **not** validate a
model trained with a filtered feature distribution.

Configuration-only MATLAB tests:

~~~matlab
runtests("tests/test_reqml_sp_reduced14_configuration.m")
~~~

The validation and inference stages require the saved files on the
user's Mac; they have not been executed by this repository change.


## Focused four-arm comparison: Reduced16 vs Reduced14, raw vs filtered

Use these **four existing inference arms** to isolate the effect of removing
two features from the effect of fixed spatial filtering:

| Arm | Fitted model | Experimental input |
| --- | --- | --- |
| `A_raw_v1` | Reduced16 | Raw (no spatial filter) |
| `reduced14` | Reduced14 | Raw (no spatial filter) |
| `B_filtered_v1` | **Same** Reduced16 bundle as `A_raw_v1` | Fixed 0.8–8 m/s global FFT donut |
| `reduced14_filtered` | **Same** Reduced14 bundle as `reduced14` | Same fixed donut |

The two filtered arms measure **transfer of raw-trained models to filtered
data**. Neither was refitted on the filtered wavefield. All four use the
same frozen phantoms, 300–600 Hz frequencies, M=2, StepPixels=2 and ROIs.

After the four estimates per frequency exist (the first three arms may
already be present), run only the focused analysis, **without new inference**:

~~~matlab
four=["A_raw_v1","reduced14","B_filtered_v1","reduced14_filtered"];

result=run_analysis(Arms=four,MakeComparisonPlots=true);
disp(result.summary)

% Optional: regenerate just this set of figures.
figures=run_plots(Arms=four);
~~~

If the Reduced14 estimates have not been generated yet, use the
`run_estimation(Arms=["reduced14","reduced14_filtered"])` command above
first; it resumes existing compatible predictions.

A dedicated analysis folder prevents overwriting earlier seven- or
nine-model tables and plots:
`reqml_sp_compare_m2_0p8_8_v1_reduced14_4arms_v1`.
Its figures include four-curve ROI mean SWS and spatial CV panels,
four-map montages and `feature_filter_2x2_roi_mean`:
Reduced14 minus Reduced16 (raw and filtered) and filtered minus raw
(Reduced16 and Reduced14), matched by phantom, ROI and frequency.

Without independent phantom SWS ground truth, these are **comparisons of
predicted SWS and spatial variation**, not experimental accuracy estimates.
Spatial SD across an ROI is not a confidence interval.


### Optional fifth model: candidate10 on the filtered wavefield

The focused comparison also accepts one historical benchmark:
`candidate10_filtered` (the frozen Candidate10 model on the **same
global-donut-filtered input** as the other filtered arms). It is **not**
the same architecture or training dataset as Reduced14/Reduced16, so
interpret it as an external experimental comparator rather than part
of the matched feature-ablation design.

~~~matlab
four=["A_raw_v1","reduced14", ...
      "B_filtered_v1","reduced14_filtered"];
five=[four,"candidate10_filtered"];

% Uses existing saved estimates: no refitting or EWP reprocessing.
result=run_analysis(Arms=five,MakeComparisonPlots=true);
disp(result.summary)

% Optional figure-only rerun:
figures=run_plots(Arms=five);
~~~

The fifth arm is already included in the historical seven-arm study,
so it usually needs no new estimation. The separate output
`reqml_sp_compare_m2_0p8_8_v1_reduced14_5arms_v1`
contains five-arm maps and frequency/ROI curves, retains the matched
four-arm 2×2 contrasts, and adds
`candidate10_filtered_vs_reduced_roi_mean` to compare Candidate10
with Reduced14 and Reduced16 **under identical filtering**.
The four-, seven-, and nine-arm analyses remain unchanged.


## Central homogeneous ROI, versioned analysis (2026-11-04)

New ROI policy:

| Phantom | ROI | Center [x,z] mm | Size [width,height] mm |
| --- | --- | --- | --- |
| Homogeneous 5% / 10% SP | central | [18,18] | [16,14] |
| Double-layer SP | ROI1 (soft) | [18,10] | [10,5] |
| Double-layer SP | ROI2 (hard) | [18,25] | [10,5] |

The homogeneous central rectangle spans x=10–26 and z=11–25 mm.
All arms share the same physical ROI. The earlier two-ROI sections above
describe historical analyses; the updated analysis/plot functions use
sp_comparison_rois(experiment), supporting one or two ROIs per phantom.

New analyses end in _central_homo_v2 (e.g.,
reqml_sp_compare_m2_0p8_8_v1_reduced14_5arms_v1_central_homo_v2);
the old tables and plots remain intact. Existing inference files are reused.

~~~matlab
five=["A_raw_v1","reduced14","B_filtered_v1", ...
    "reduced14_filtered","candidate10_filtered"];
result=run_analysis(Arms=five,MakeComparisonPlots=true);
disp(result.summary)
~~~

The rectangle is nominal and valid map coverage may differ by frequency.
Inspect selected_pixels, valid_fraction and actual selected extents for
formal frequency consistency. The RSWE analogue is documented at
../reqml_rswe_comparison/README.md.
