# Reduced14 quality mask v1 — synthetic ground-truth transfer

This is a **bounded, ground-truth falsification study**, not quality-mask
training. It reuses the existing 20 nondispersive swsynth V2 wavefields and
the existing `reduced14` and, when available, `reduced14_filtered`
`reqml_result.mat` predictions at `M=2, StepPixels=5`. It does **not** rerun
simulations or change the frozen Reduced14 regressor or risk classifier.

The question is whether the 750-Hz-trained **risk mask v1** identifies true
SWS errors >10%, rather than marking physically correct high-speed regions
as unreliable. The experimental maps showed excessive rejection in 10%
homogeneous phantoms and the hard bilayer; without true speed, those maps
cannot establish if the rejection is justified.

## Existing synthetic controls

| Medium | Wave source | Speeds | Number of cases |
| --- | --- | --- | ---: |
| Homogeneous | Opposed plane waves | 1.8, 3.0 m/s | 8 |
| Homogeneous | Opposed point-source disks | 1.8, 3.0 m/s | 8 |
| Horizontal bilayer | Opposed plane waves | Soft 1.8; hard 3.0 m/s | 4 |

All five physical series have 300, 400, 500, and 600 Hz. The bilayer
interface is at `z=25 mm`. The evaluated ROIs are the established central
homogeneous 10×10 mm ROI, soft/hard interior 10×5 mm ROIs, and a *separate*
10×5 mm interface band. The exact material boundary line (`|z-25| <= 0.25 mm`)
is not labeled with pointwise truth. A window spanning an interface mixes
two media, so the interface-band error is descriptive and **not** a simple
proof of estimator failure; the two homogeneous layer interiors are the
primary check for false rejection of correct high-speed estimates.

The plane/bilayer Eikonal simulator does not model full reflection, mode
conversion or attenuation. The point-source waves are analytical spherical
waves, not experimental IQ measurements or full 3D k-Wave. Each series
corresponds to four frequencies of one physical configuration; the thousands
of overlapping patch centers are correlated, not independent samples.

## Run from MATLAB

First pull the branch and add the existing code folders:

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"src"),"-begin")
addpath(fullfile(pwd,"studies","reqml_frequency_bias_swsynth"),"-begin")
addpath(fullfile(pwd,"studies","reqml_quality_mask_swsynth"),"-begin")

clear run_swsynth_quality_mask_study swsynth_comparison_config
rehash
tests=runtests("tests/test_reduced14_quality_swsynth.m");
assert(all([tests.Passed]))

% Strict read-only preflight. Prints every missing reqml_result.mat.
plan=run_swsynth_quality_mask_study(Mode="plan");
disp(plan.cases(:,["case_id","arm","estimate_exists"]))
```

If the `reduced14_filtered` inference files are missing, reuse the saved
simulated wavefields. This stage creates no new simulation, and uses the
same full-field Q0-v5 donut (`cs_min=0.8 m/s`, `cs_max=8 m/s`, taper=0.06)
as the synthetic comparison:

```matlab
% Idempotent: verifies/reuses any existing filtered samples.
run_swsynth_comparison(Stage="filter", ...
    Arms="reduced14_filtered",M=2,StepPixels=5);

% Only missing filtered Reduced14 SWS estimates are computed.
run_swsynth_comparison(Stage="estimate", ...
    Arms="reduced14_filtered",M=2,StepPixels=5,UseParallel=true);

% If necessary, compute missing raw Reduced14 estimates too:
run_swsynth_comparison(Stage="estimate", ...
    Arms="reduced14",M=2,StepPixels=5,UseParallel=true);
```

Run a **single case** as a pilot, then all 20 × 2 inference maps:

```matlab
pilot=run_swsynth_quality_mask_study(Mode="run", ...
    CaseIDs="plane_bilayer_soft180_hard300_f500", ...
    Arms="reduced14_filtered",MakePlots=true);
disp(pilot.summary)

full=run_swsynth_quality_mask_study(Mode="run", ...
    Arms=["reduced14","reduced14_filtered"], ...
    MaximumRisks=[0.2 0.3 0.5],MakePlots=true);
disp(full.summary)
```

An initial **raw-only** run (`Arms="reduced14"`) also works if filtered
estimates have not yet been created. All runs assert the exact saved
estimator identity and match each case to its saved prediction.

## Output and interpretation

All new outputs are isolated under the existing synthetic study:

```
studies/reqml_frequency_bias_swsynth/outputs/comparison/
  quality_mask_swsynth/reduced14_quality_mask_swsynth_v1/
    cases/<case_id>/<arm>/quality_truth_result.mat
    cases/<case_id>/<arm>/risk_vs_true_error.png
    aggregates/<case_scope>/risk_vs_truth_by_roi.csv
    aggregates/<case_scope>/risk_calibration_bins.csv
    aggregates/<case_scope>/risk_vs_truth_windows.mat
```

For every case/ROI/threshold:

- `mape_valid_pct` versus `mape_retained_pct`: is filtering actually
  reducing error against known true SWS?
- `fraction_retained_valid` and `high_error_fraction_retained`: how much
  useful area remains, and how often are high errors retained?
- `high_error_rejection_fraction`: among truly incorrect SWS pixels, what
  fraction was rejected?
- `correct_rejection_fraction`: among truly **accurate** SWS pixels, what
  fraction was incorrectly rejected? **This is critical in the 3 m/s
  medium and bilayer hard interior.**
- AUC/Brier and predicted-vs-observed calibration by risk bins. AUC is
  reported as `NaN` when a ROI has only one true error class.

The artificial risk=1 sentinel used to reject **invalid SWS** is excluded
from classifier evaluation; invalid estimates are counted separately.
Comparisons are between frequencies/ROIs (patch grids differ), not
individual matched pixels over frequency.

## Decision after results

1. If the mask rejects low-error SWS in 3 m/s homogeneous interiors or the
   hard bilayer interior, that is evidence of **domain shift / over-rejection**;
   raising a global threshold should not be the primary correction.
2. If it preferentially rejects truly high-error SWS while maintaining
   reasonable coverage for *both* speeds, retain its design and investigate
   threshold calibration; compare unfiltered and filtered preprocessing.
3. For a subsequent mask **v2**, keep the Reduced14 SWS regressor frozen;
   broaden risk-model training with high speeds, multiple frequencies,
   interfaces and matching fixed spatial filtering, with geometry-held-out
   train/calibration/test splits. Do not use this small evaluation set as
   both the test and hyperparameter-selection set.

No v2 training is performed by this study. MATLAB execution and numerical
results must be verified on Sara's computer (the code was not run on MATLAB
in the development environment).
