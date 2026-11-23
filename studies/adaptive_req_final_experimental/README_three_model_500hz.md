# Three frozen REQ models — experimental 500-Hz comparison

This is a **new, isolated** comparison of the six 2026-02-27 phantom
acquisitions. It is not part of the original quality-mask study and
does not change any existing processed wavefield or Full21 estimate.

The first pilot fixes:

- Frequency: **500 Hz**
- M: **2**
- StepPixels: **3**
- Input: existing **unfiltered**
  `processed/adaptive_req_final_unfiltered_v1/500Hz/wavefield_sample.mat`
- SWS masks: **none**
- Scope: homogeneous 5% and 10%, bilayer; each SP and RSWE

### Three frozen models

1. **Full21 original** — already estimated and saved at
   `.../REQ-ML/adaptive_req_full21_unfiltered_v1/500Hz/M2/step3/reqml_result.mat`
2. **Full21 clean-trained** — reads the clean-only model in
   `REQ-ML/training/adaptive_req_final_v1/noise_free_full21_v1/outputs/clean_v1/`
3. **Legacy Q0** — EXACT locally saved
   `REQ-ML/models/legacy/model_bundle.mat` and
   `REQ-ML/models/legacy/training_manifest.json`.

The saved legacy manifest identifies
`reqml_q0_reduced_v2`: 10 predictors, 160 bagged trees,
`MinLeafSize=8`, 463,800 TRAIN+VALIDATION rows and TEST excluded.
The 21-feature Full21 clean model uses 160 trees with leaf 2.
These model families and training corpora differ, so any ranking
cannot be attributed uniquely to the presence/absence of noise.

### Full inference, not feature reuse

**Both new models are evaluated using `reqml.predictSWS` on the original
processed wavefield.** Each performs its own REQ spectral extraction,
quantile prediction, q-to-wavenumber mapping and SWS assembly.
The clean model uses the adaptive Full21 branch with an explicit
experimental in-memory release bundle; legacy uses Q0 ModelBundle.
`RequireTruth=false`, same M, StepPixels, guess speed and input.
The published original model is NOT rerun, overwritten or masked.

### Scripts

- `compare_models_500hz_config.m` — shared path/selection configuration
- `run_compare_models_500hz.m` — preflight, full REQ inference of two
  new models, model/input fingerprint checks, resumable safe MAT output
- `plot_compare_models_500hz.m` — saved-only three-model SWS maps,
  pixelwise *SWS differences*, frozen ROI statistics and six-acquisition
  summary figures. No inference, mask or spectral extraction.
- `test_compare_models_500hz.m` — lightweight MATLAB path/ROI/plan checks

### Usage

From the existing local checkout of the experimental study branch:

~~~matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"studies","adaptive_req_final_experimental"))

t = runtests("studies/adaptive_req_final_experimental/test_compare_models_500hz.m");
assert(all([t.Passed]))

% Read-only inventory: checks all 6 samples, original estimates and models.
P = run_compare_models_500hz(Mode="plan");

% Resume-safe, per-model FFT + REQ from processed wavefield_sample.mat.
% Set UseParallel=false if RAM or parpool contention is a problem.
R = run_compare_models_500hz(Mode="run",UseParallel=true);

% All three SWS maps must now exist; no quality mask is consulted.
Q = plot_compare_models_500hz(Mode="plan");
F = plot_compare_models_500hz(Mode="run");
~~~

To run a single acquisition first:

~~~matlab
caseID="2026Feb27_homo_10perc_rswe";
R=run_compare_models_500hz(Mode="run",SelectedCaseIDs=caseID);
F=plot_compare_models_500hz(Mode="run",SelectedCaseIDs=caseID);
~~~

To run 10 workers manually (the estimator uses an existing pool):

~~~matlab
oldPool=gcp("nocreate");
if ~isempty(oldPool),delete(oldPool);end
parpool("Processes",10);
R=run_compare_models_500hz(Mode="run",UseParallel=true);
~~~

For each case, the new MAT files are written to:

~~~text
<case>/estimates/adaptive_req_final_experimental_v1/REQ-ML/
    adaptive_req_full21_clean_v1/500Hz/M2/step3/reqml_result.mat
    legacy_q0_v1/500Hz/M2/step3/reqml_result.mat
~~~

All figures/ROI summaries are written to a separate folder:

~~~text
<DataRoot>/analysis/adaptive_req_final_experimental_v1/
    three_model_unfiltered_comparison_v1/500Hz/M2/step3/
        experimental_inference_summary.csv
        roi_descriptive_statistics.csv
        roi_descriptive_statistics.mat
        figures/
            <case>_three_model_sws.png/.pdf
            <case>_three_model_differences.png/.pdf
            all_cases_roi_medians.png/.pdf
~~~

For each physical ROI, the table reports number of three-way
common-valid pixels, matched coverage, median SWS, interquartile range
and paired median changes in SWS (m/s).

**There is no automatic experimental MAPE**: the SWS reference
requires independent mechanical measurements. The original SLS paper
envelopes are approximate over 300–600 Hz and are not substituted as
exact pixelwise truth. Lower spatial variance or similarity to a
published expectation alone does not demonstrate accuracy.

### Frozen ROIs and separation from previous study

All ROIs are loaded using the existing
`adaptive_req_final_case_rois.m`, which selects the saved central ROI
for homogeneous phantoms and soft/hard ROIs for bilayer.
SP and RSWE cases are evaluated identically.
No existing Full21 release, estimation, mask or experimental dataset is
overwritten.

### MATLAB verification status

The source and model schemas were inspected using the GitHub checkouts,
but the local large model MAT files and actual experimental wavefields
are available only on the user's workstation. Execute the small plan
tests, pilot on one acquisition and review the three maps before
trusting the complete experiment.
