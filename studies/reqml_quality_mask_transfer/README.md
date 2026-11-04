# Exploratory application of the frozen Reduced14 SWS-error mask

The trained quality mask is **not** an IQ-correlation/SNR threshold. It is a
supervised classifier for `P(|SWS_est - SWS_GT| / SWS_GT > 0.10)` trained on
Q0-v5 simulations (20 observable window predictors + frozen `q_pred`).
Experimental ground truth is **not** available to assess these predictions.

This study only reads existing `reqml_result.mat` files; it does **not**
reprocess IQ, retrain models, overwrite SWS estimates, or change Q predictions.

## Compatible estimators

- `reduced14`: raw wavefield, matching the classifier's synthetic preprocessing
  more closely (frequency and physical-domain transfer remain unvalidated).
- `reduced14_filtered`: **same** raw-trained Reduced14 quantile model applied
  to a fixed 0.8–8 m/s global donut-filtered wavefield. Applying the mask to
  this arm is an **additional filter-domain transfer**, not an in-domain test.

The runner refuses other estimator IDs and checks that saved patches align
exactly with their SWS, quantile and valid-mask grids. All 21 classifier
inputs must be present. Invalid SWS patches are always excluded; `risk=1`
on invalid patches is a **rejection sentinel**, not a calibrated prediction.

## MATLAB usage

Pull the new `feature/reduced14-quality-mask-experimental-20261104` branch of
`shear-wave-estimation-evaluation` and ensure the REQ-ML checkout contains
the trained bundle at:

`/Users/sara/local/req-ml/training/q0_v5_clean_campaign/outputs/reduced14_quality_mask_v1/quality_mask_bundle.mat`

From the shear-wave-estimation-evaluation checkout:

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"src"),"-begin")
addpath(fullfile(pwd,"studies","reqml_quality_mask_transfer"),"-begin")

% Unit tests first; these do not need experimental data.
runtests("tests/test_reduced14_quality_transfer.m")

% Read-only preflight: 2 phantoms x 2 arms x 4 frequencies = 16 estimates.
p=run_quality_mask_transfer(Mode="plan");
disp(p.missing_inputs)

% First run only one available arm / one frequency.
pilot=run_quality_mask_transfer(Mode="run", ...
    Experiments="2026Feb27_homo_5perc_sp", ...
    Arms="reduced14_filtered",Frequencies=500);
disp(pilot.summary)

% Full study; existing matching outputs are verified and resumed.
out=run_quality_mask_transfer(Mode="run");
disp(out.summary)
```

If only filtered estimates are currently available, explicitly set
`Arms="reduced14_filtered"`; the preflight shows exactly which raw/filtered
input estimates are missing. Other experiments (e.g. `2026Feb27_dl_sp`)
can be added through `Experiments` without changing code.

For each estimate, the study saves a new
`analysis/reduced14_quality_mask_transfer_v1/<arm>/<frequency>Hz/M2/`
folder containing:

- `risk_mask_result.mat`: risk grid, original and masked SWS maps, counts,
  coverage and descriptive spatial statistics at maximum risks 0.2 and 0.3.
- `risk_and_sws_maps.png`: original SWS, predicted risk, masked SWS at both
  cutoffs using identical speed color limits.

Existing outputs with matching source/bundle identity are resumed; differing
input files or settings stop with an error and are never overwritten.

## Scientific interpretation

- Retention is the fraction of **originally valid** SWS patches retained;
  the displayed raw and masked SWS share the same spatial grid.
- Changes in spatial SD or median SWS after masking are descriptive;
  lower variability does **not** prove higher experimental accuracy.
- The risk model was trained with Q0-v5 synthetic simulations at 750 Hz;
  its calibration at experimental frequencies 300–600 Hz and for filtered
  data is **unknown**. Avoid calling output probabilities calibrated
  experimental error probabilities until validated with reference data.
- The 45 earlier synthetic validation geometries were used during model
  selection. This experimental study is intended to check spatial behavior
  and hotspots, not to claim independent accuracy.
