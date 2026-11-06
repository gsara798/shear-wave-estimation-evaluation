## Frozen QMV2 experimental quality-mask transfer (2026-11-06)

After completing four synthetic masks and geometry-held-out validation,
the experiment manifest now includes a **mask_transfer** section.
The four exact model/filtration pairs and their frozen mask filenames
are specified there; model selection is not embedded in MATLAB code.
The risk score cutoff comes ONLY from the saved TRAIN OOF mask metadata
(target retention 80%), and is **not** optimized using experimental
maps, phantom ROI means, or reference SWS. Test geometries are untouched.

The transfer runner `run_qmv2_experimental_risk_mask`:

- `Mode="plan"`: lists missing fitted masks and original experimental
  SWS estimates without writing or recomputing anything.
- `Mode="run"`: reads each existing `reqml_result.mat` including
  `patch_examples`, `q_map`, `cs_map`, and grid indices. The frozen
  risk classifier uses **exactly the same extracted patch features**
  and predicted q as the quantile estimator. No new IQ processing,
  filtering, feature extraction, quantile fit or SWS estimation.
- Scores are for likelihood *ranking*, not calibrated risk
  probabilities. Only finite, SWS-valid windows are evaluated.
  Three disjoint classes are stored: retained, rejected, unscorable.
  An invalid original SWS pixel is never counted as retained.
- Results use immutable source/mask-file fingerprints and a separate
  versioned directory. The original SWS predictions are not changed.
- `Mode="analyze"`: per-dataset, frequency, model and manifest-defined
  physical ROI, produces original/retained/rejected counts, actual
  retained fraction (experimental coverage may NOT be 80%),
  mean/median SWS and spatial CV before/after masking.
  For inclusion, contrasts before/after and target/background
  retained fractions are reported. These are **descriptive**, not
  errors against independent ground truth.
- `Mode="plot"`: three-panel maps show original SWS, risk score
  and SWS remaining after the *frozen TRAIN cutoff*, with consistent
  spatial coordinates and the existing configured ROIs.

### Preparation

```bash
cd /Users/sara/local/shear-wave-estimation-evaluation
git pull --ff-only
```

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
study=fullfile(pwd,"studies","reqml_experimental_qmv2");
addpath(study,"-begin")
clear run_qmv2_experimental_risk_mask qmv2_score_experimental_risk_mask
rehash
t=runtests("tests/test_qmv2_experimental_risk_mask.m");
assert(all([t.Passed]))
manifest=fullfile(study,"experiment_manifest.example.json");

P=run_qmv2_experimental_risk_mask( ...
    ManifestFile=manifest,Mode="plan");
disp(P.models)
disp(P.jobs)
```

### Small pilot on the difficult experimental fields

```matlab
pilotIDs=["2026Feb27_homo_5perc_rswe","2026Feb19_inc_rswe"];
pilotArms=["qmv2_unfiltered_reduced14", ...
    "qmv2_unfiltered_expanded20"];

Q=run_qmv2_experimental_risk_mask( ...
    ManifestFile=manifest,Mode="run", ...
    CaseIDs=pilotIDs,Arms=pilotArms, ...
    FrequenciesHz=[300 600], ...
    Verbose=true);
disp(Q.status)

F=run_qmv2_experimental_risk_mask( ...
    ManifestFile=manifest,Mode="plot", ...
    CaseIDs=pilotIDs,Arms=pilotArms, ...
    FrequenciesHz=[300 600]);
disp(F.files)
```

This is **8 mask mappings** from already saved experimental q/SWS
estimates, with no model fitting. Examine rejected regions and
coverage before scaling to the entire 8-dataset cohort.

### All acquired datasets × four frozen masks

```matlab
Q=run_qmv2_experimental_risk_mask( ...
    ManifestFile=manifest,Mode="run", ...
    ConfirmFullRun=true);
A=run_qmv2_experimental_risk_mask( ...
    ManifestFile=manifest,Mode="analyze");
F=run_qmv2_experimental_risk_mask( ...
    ManifestFile=manifest,Mode="plot");
disp(A.roi_summary)
disp(A.contrasts)
```

The runner resumes successful pilot checkpoints. For eight datasets
and four frequencies this is up to **128 already-estimated SWS maps**
(4 frozen masks × 32 acquisitions), with zero IQ/SWS recomputation.

Output examples, based on JSON settings:

```text
<dataset>/analysis/<study_id>/M<M>_step<N>/<mask_analysis_version>/masks/<arm>/<freq>Hz/risk_mask_result.mat
<dataset>/analysis/<study_id>/M<M>_step<N>/<mask_analysis_version>/comparison_figures/mask_<arm>_<freq>Hz.png
<data_root>/analysis/<study_id>/M<M>_step<N>/<mask_analysis_version>/quality_mask_experimental_roi_summary.csv
<data_root>/analysis/<study_id>/M<M>_step<N>/<mask_analysis_version>/quality_mask_inclusion_contrasts.csv
```

The original ROI CSVs and q/SWS estimates remain unchanged.
**Status:** Source and unit tests committed; local MATLAB execution
has not yet been verified. Start with the pilot, not the full run.

---

## Inclusion physical ROIs and paired contrast analysis (2026-11-06)

After quantitative comparison of 5%/10% homogeneous and bilayer CSVs,
both Feb-19 inclusion cases now use three **fixed physical** rectangles
(SP and RSWE, all frequencies, all arms). Values are configured ONLY
in the example JSON, not in MATLAB analysis code:

| ROI | center [x,z], mm | size [x,z], mm | Purpose |
|---|---|---|---|
| `inclusion_core` | [19.5,24.5] | [8,8] | Primary interior estimate |
| `inclusion_large` | [19.5,24.5] | [12,12] | Boundary sensitivity |
| `background_ref` | [28,13.5] | [6,6] | Background contrast reference |

Two JSON `contrasts` definitions pair core/background and
large/background. The `analyze` stage now creates:

- `qmv2_experimental_roi_summary.csv`: per-ROI mean/median SWS,
  spatial SD/CV, median q, common valid pixel counts, and
  `roi_extent_in_sample_fraction`.
- `qmv2_inclusion_contrasts.csv`: median target/background SWS,
  median SWS difference (m/s), ratio, percent median contrast,
  mean difference, spatial CNR, pixel counts and
  `roi_pair_within_fov` (true when both ROI physical extents
  reach the configurable JSON `roi_min_fov_fraction`, 0.90 by default,
  on the estimated map-center grid).
- The combined `all_inclusion_contrasts.csv` in the shared analysis root.
- Extra `comparison_figures/contrast_<name>_M2.png` with contrast
  and spatial CNR vs acquisition frequency, plus the standard
  SWS maps overlaying all three ROI boundaries.

Contrast is descriptive; without independent shear-speed ground truth
it is **not** an accuracy measure. CNR uses
`(mean_target - mean_background) / hypot(sd_target,sd_background)`
(descriptive, not a hypothesis test). The 6x6 mm reference ROI is near
the right edge and may be clipped, especially at lower frequencies:
the code warns and flags incomplete coverage, without silently moving
or replacing the ROI. Validate its physical position against B-mode;
if it needs changing, edit JSON and bump `analysis_version`.

### Reanalyze and plot only (no IQ processing and no new SWS estimation)

```bash
cd /Users/sara/local/shear-wave-estimation-evaluation
git pull --ff-only
```

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
study=fullfile(pwd,"studies","reqml_experimental_qmv2");
addpath(study,"-begin");
clear read_qmv2_experiment_manifest run_qmv2_experimental_study
clear qmv2_inclusion_contrasts qmv2_plot_experimental_study
rehash
t=runtests("tests/test_qmv2_experimental_manifest.m");
assert(all([t.Passed]))

manifest=fullfile(study,"experiment_manifest.example.json");

% Rebuild all 8 existing case summaries with the new, versioned ROI policy.
R=run_qmv2_experimental_study( ...
    ManifestFile=manifest,Stage="analyze");

% Only regenerate the Feb-19 inclusion plots for now.
F=run_qmv2_experimental_study( ...
    ManifestFile=manifest,Stage="plot", ...
    CaseIDs=["2026Feb19_inc_sp","2026Feb19_inc_rswe"]);

disp(R.contrasts(:,["case_id","frequency_hz","model", ...
    "contrast_name","median_sws_difference_m_s", ...
    "median_contrast_percent","spatial_cnr", ...
    "roi_pair_within_fov"]))
disp(F.files)
```

The v2 ROI summaries/figures live under
`analysis/<study_id>/M<M>_step<N>/physical_rois_v2_inclusion_core_large_bg/`,
leaving the older `physically_fixed_rois_v1` output untouched.
The code/JSON/tests are committed but **require local MATLAB tests
and execution** before final quantitative conclusions.

---

## Five-percent homogeneous SP/RSWE extension (2026-11-06)

The existing SP/RSWE comparison scripts define
`2026Feb27_homo_5perc_sp` and `2026Feb27_homo_5perc_rswe`, with the
same fixed **central** ROI as the 10% homogeneous acquisitions:
center `[19,19.25]` mm, size `[17,15]` mm. Both cases have been added
to the **example JSON manifest** (not hard-coded into the workflow).
The plan now checks eight cases instead of six. Their availability
has not yet been verified on the user's machine.

Run **only the two new cases** first:

```matlab
manifest=fullfile(pwd,"studies","reqml_experimental_qmv2", ...
    "experiment_manifest.example.json");
ids=["2026Feb27_homo_5perc_sp","2026Feb27_homo_5perc_rswe"];
P=run_qmv2_experimental_study( ...
    ManifestFile=manifest,Stage="plan",CaseIDs=ids);
disp(P.jobs(:,["case_id","frequency_hz","raw_run", ...
    "raw_exists","run_candidates"]))
```

Only after `all(P.jobs.raw_exists)` and `all(P.models.model_present)`
are true, run:

```matlab
Q=run_qmv2_experimental_study( ...
    ManifestFile=manifest,Stage="estimate",CaseIDs=ids, ...
    UseParallel=true,ConfirmFullRun=true);
```

**Important:** The analysis stage writes both per-case summaries and a
combined summary in the study folder. To avoid replacing the existing
six-case combined CSV with only two cases, run `analyze`/`plot` with
the *default full eight-case scope* only after the two newly added
cases have completed. Existing six-case estimates are reused.

```matlab
A=run_qmv2_experimental_study(ManifestFile=manifest,Stage="analyze");
F=run_qmv2_experimental_study(ManifestFile=manifest,Stage="plot");
disp(F.files)
```

If the old `reqml_compare_raw_no_spatial_v1` processed run is missing
for 5%, examine available runs in `run_candidates` and update
`raw_run` in JSON. Do not silently substitute a low-pass or spatially
filtered run; verify its provenance first.

---
## Stage=plot output contract (2026-11-06)

The plot stage returns a consistent struct with `stage`, `files`, `jobs`, and `models`, matching the `plan` and `analyze` stages. Use `disp(F.files)` after pulling the latest patch. Before that patch, `F` was itself a string array of output filenames: `disp(F)` shows already-generated plots without regenerating anything. Existing PNGs and CSVs are unchanged.

# Configurable experimental QMV2 comparison: SP, RSWE, bilayer, homogeneous, inclusion

This opt-in study brings **SP and RSWE into one common experimental pipeline**.
It supports datasets under any date/root and any available acquisition
frequency. Model inference reuses the **eight frozen QMV2 quantile bundles**
(with/without frequency predictor, with/without canonical global FFT donut)
and optionally the two original Reduced14 deployment arms.

No dates, folder names, ROI positions, input file patterns, acquisition
frequencies or absolute user paths are baked into the MATLAB source.
These belong to the editable `experiment_manifest.example.json`. The
shipped example lists the *requested* February 27 (10% and bilayer) and
February 19 (SP/RSWE inclusion) datasets. It is not proof that all six
folders or processed MAT files exist on a particular workstation.

## Relation to earlier scripts

- `studies/reqml_sp_comparison`: original SP processing/inference/ROI scripts.
- `studies/reqml_rswe_comparison`: original RSWE counterpart in the
  `feature/reqml-central-homo-roi-rswe-20261104` branch.
- `studies/reqml_experimental_qmv2`: new unified QMV2 workflow, independent
  of those frozen study runners and their hard-coded acquisition assumptions.

## Scientific scope and safeguards

- The `plan` stage is **read-only** and lists raw availability, derived
  donut availability, model bundle presence, selected ROI policy and
  candidate processed-run names. Unspecified inclusion frequencies are
  discovered from actual `*Hz` acquisition or processed sample files.
- `process` runs the existing EWP `ewp.runFrequencySweep` from IQ once
  per dataset, using **per-case manifest options**: raw file pattern,
  frequency list, SVD modes, isotropic resampling and raw-run name.
  **Do not run process if suitable raw wavefield MATs already exist.**
- `estimate` uses `reqml.predictSWS` and the exported **train-only**
  bundles; every estimate has input/model size, modification time,
  frequency, `M`, and step in an immutable comparison identity.
  Existing matching estimates are resumed, not overwritten.
- For donut arms, a new derived sample is saved under the configured
  `filtered_run`. This uses the canonical `q0v5.filter.applyFixedDonut`
  with configurable cutoffs/taper, **without changing the raw sample**.
- `analyze` uses paired/common-valid map centers **within each frequency**
  for every selected model, and physical rectangle ROIs from JSON.
  Reports mean/median SWS, spatial SD, CV, predicted q, ROI coverage.
  Without an independent known speed, bias and MAPE are NaN. **Experimental
  variability/dispersion cannot be interpreted as SWS accuracy.**
- Inclusion datasets have `rois: []` on purpose: **first inspect full-field
  maps** without inventing the inclusion contour or location. This gives
  an exploratory `whole_FOV_unsegmented` summary, not an inclusion-vs-
  background contrast. After inspecting B-mode/wavefield, define physical
  inclusion/background rectangles in JSON, and bump `analysis_version`.
- Analysis policy fingerprints guard against silently overwriting a
  previous ROI/arm selection. Simulation models and untouched TEST are
  not retrained or evaluated in this study.

## Run

**1. Check out the experimental study branch** (after saving local changes):

```bash
cd /Users/sara/local/shear-wave-estimation-evaluation
git fetch origin
git switch feature/qmv2-experimental-manifest-sp-rswe-inclusion-20261105
```

**2. Edit or copy the manifest**. Keep the default path if the supplied
datasets and roots match your workstation. Check `raw_run` and
`raw_file_pattern` using `plan` before processing IQ. The Feb-19 inclusion
cases use `raw_run: "auto"` and an empty acquisition pattern: if exactly
one unfiltered processed run covers the discovered frequencies, it is
reused; otherwise select the correct raw run explicitly in JSON.

**3. Plan and validate the six requested cases without writing:**

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
study=fullfile(pwd,"studies","reqml_experimental_qmv2");
addpath(study,"-begin");
clear run_qmv2_experimental_study qmv2_experimental_plan
rehash

t=runtests("tests/test_qmv2_experimental_manifest.m");
assert(all([t.Passed]))

manifest=fullfile(study,"experiment_manifest.example.json");
P=run_qmv2_experimental_study(ManifestFile=manifest,Stage="plan");
disp(P.models)
disp(P.jobs)
```

**4. Pilot on one already-processed dataset, with just two arms:**

```matlab
pilotArms=["qmv2_unfiltered_reduced14", ...
    "qmv2_fixed_donut_expanded20"];
Q=run_qmv2_experimental_study( ...
    ManifestFile=manifest,Stage="estimate", ...
    CaseIDs="2026Feb27_homo_10perc_sp", ...
    Arms=pilotArms,UseParallel=true);
```

First confirm that `plan` reports all of that dataset's `raw_exists=true`.
A pilot will run once at each available frequency; no IQ processing.

**5. Full estimation**, only for datasets confirmed processed:

```matlab
Q=run_qmv2_experimental_study( ...
    ManifestFile=manifest,Stage="estimate", ...
    CaseIDs=["2026Feb27_dl_sp","2026Feb27_dl_rswe", ...
             "2026Feb27_homo_10perc_sp","2026Feb27_homo_10perc_rswe"], ...
    UseParallel=true,ConfirmFullRun=true);
```

To include Feb-19 inclusion SP and RSWE, run `plan` for those IDs first.
If no raw wavefields exist, verify the real acquisition filenames under
`raw/`, set `raw_run` to a new unique processing name and
`raw_file_pattern` to the actual IQ naming template, then run:

```matlab
P=run_qmv2_experimental_study(ManifestFile=manifest,Stage="plan", ...
    CaseIDs=["2026Feb19_inc_sp","2026Feb19_inc_rswe"]);

% Only after confirming IQ filenames and editing manifest as needed:
Q=run_qmv2_experimental_study(ManifestFile=manifest,Stage="process", ...
    CaseIDs=["2026Feb19_inc_sp","2026Feb19_inc_rswe"], ...
    UseParallel=true);

% Re-run Stage="plan" to confirm processed samples, then Stage="estimate".
```

**6. ROI analysis and publication-friendly plots**, after the selected
datasets and all selected model arms have completed their estimates:

```matlab
caseIDs=["2026Feb27_dl_sp","2026Feb27_dl_rswe", ...
    "2026Feb27_homo_10perc_sp","2026Feb27_homo_10perc_rswe"];
R=run_qmv2_experimental_study( ...
    ManifestFile=manifest,Stage="analyze",CaseIDs=caseIDs);
F=run_qmv2_experimental_study( ...
    ManifestFile=manifest,Stage="plot",CaseIDs=caseIDs);
disp(R.summary)
disp(F.files)
```

The per-dataset output layout is:

```text
<dataset-root>/processed/<raw-run>/<frequency>Hz/wavefield_sample.mat
<dataset-root>/processed/<filtered-run>/<frequency>Hz/wavefield_sample.mat
<dataset-root>/estimates/<study-id>/REQ-ML/<arm>/<frequency>Hz/M<M>/step<N>/reqml_result.mat
<dataset-root>/analysis/<study-id>/M<M>_step<N>/<analysis-version>/qmv2_experimental_roi_summary.csv
<dataset-root>/analysis/<study-id>/M<M>_step<N>/<analysis-version>/comparison_figures/*.png
```

Combined ROI summaries for the chosen scope also appear under
`<data_root>/analysis/<study_id>/M<M>_step<N>/<analysis_version>/`.
Do not run `analyze` on different arm subsets into the same
`analysis_version`; change the version to keep separate reports.

## Current status

The source and read-only tests have been committed, but this ChatGPT
session cannot access the Mac's experimental datasets or execute MATLAB.
The first local `plan` and pilot must verify actual EWP input, model
bundle provenance, MATLAB syntax and output compatibility before the
full experimental campaign. The Feb-27 ROI coordinates come from the
previous SP/RSWE comparison scripts; check B-mode alignment for each
acquisition. The Feb-19 inclusion ROIs are intentionally unassigned.
