# Signal-quality association with REQ-ML SWS maps

This is a **diagnostic study**, not a quality mask and not a new estimator.
It co-registers saved REQ-ML maps with experimental-wavefield-processing
(EWP) IQ/temporal diagnostics in physical coordinates. It never regenerates
processed wavefields, changes model bundles, or modifies saved estimates.

## 1. Generate the quality MAT files in EWP

In MATLAB, with an EWP checkout that provides `ewp.diagnoseAcquisition`:

```matlab
ewpRoot="/Users/sara/local/experimental-wavefield-processing";
dataRoot="/Users/sara/local/experimental-data-reorganized/2026-02-27";
addpath(fullfile(ewpRoot,"src"));

experiments=["2026Feb27_homo_5perc_rswe", ...
             "2026Feb27_homo_5perc_sp"];
for experiment=experiments
    root=fullfile(dataRoot,experiment);
    outputRoot=fullfile(root,"analysis","quality_hotspot_check");
    for f=[300 400 600]  % 500 Hz can be skipped if already available
        rawFile=fullfile(root,"raw",sprintf("test1_%dHz.mat",f));
        assert(isfile(rawFile),"Missing raw acquisition: %s",rawFile);
        ewp.diagnoseAcquisition(rawFile,f, ...
            Types=["iq_quality","displacement_quality"], ...
            OutputRoot=outputRoot,StartFrame=2,UseParallel=true);
    end
end
```

This produces **two separate files per frequency**:

```text
<experiment>/analysis/quality_hotspot_check/
  iq_quality/test1_<f>Hz/iq_quality.mat
  displacement_quality/test1_<f>Hz/temporal_consistency.mat
```

The IQ correlation measures tracking consistency; **it is not SWS SNR**.
The temporal harmonic-fit `R^2` and amplitude/residual ratio characterize
the observed temporal displacement, not the accuracy of REQ-ML itself.
They are computed before the study's global spatial spectral filter; do not
describe them as post-filter measurement quality.

## 2. Compare with frozen `reduced14_filtered` estimates

Add the SWS-Eval source and study folders and run:

```matlab
evalRoot="/Users/sara/local/shear-wave-estimation-evaluation";
addpath(fullfile(evalRoot,"src"));
addpath(fullfile(evalRoot,"studies","reqml_signal_quality"));

out=run_signal_quality_study( ...
    DataRoot="/Users/sara/local/experimental-data-reorganized/2026-02-27", ...
    Experiments=["2026Feb27_homo_5perc_rswe", ...
                 "2026Feb27_homo_5perc_sp"], ...
    Frequencies=[300 400 500 600], ...
    EstimationRun="reqml_sp_compare_m2_0p8_8_v1", ...
    Arm="reduced14_filtered",M=2, ...
    QualityRun="quality_hotspot_check", ...
    ContinueOnMissing=true);

disp(out.summary)
```

The expected estimate path is:

```text
<experiment>/estimates/<EstimationRun>/REQ-ML/<Arm>/<f>Hz/M2/reqml_result.mat
```

Check `EstimationRun` against your actual estimate directory before
running. The default ROI is the physically fixed 5%-phantom central
rectangle: `Center=[19 19.25]`, `Size=[17 15]` mm. Override with, e.g.:

```matlab
roi=swseval.roi.rectangle("central",Center=[19 19.25], ...
    Size=[17 15],Units="mm");
out=run_signal_quality_study(ROIs=roi,ExportFigures=false);
```

You may add `"2026Feb27_homo_10perc_sp"` to the experiments, but verify
that the ROI lies in the intended homogeneous interior. The study never
guesses a reference SWS or a different ROI for that acquisition.

## Outputs

Each experiment/frequency/model/ROI writes to:

```text
<experiment>/analysis/signal_quality_reduced14_v1/
  <f>Hz/M2/reduced14_filtered/central/
    metric_associations.csv
    exploratory_gates.csv
    quality_association.mat
    hotspot_quality.png
    hotspot_quality.pdf
```

Cross-frequency summary files are saved in
`<DataRoot>/signal_quality_reduced14_v1/`:

- `summary_all.csv`: ROI and upper-tail counts and thresholds.
- `metric_associations_all.csv`: Spearman, depth-detrended Spearman,
  median metric values, and descriptive ROC AUC for each quality metric.
- `exploratory_gates_all.csv`: fraction of pixels flagged and fraction of
  upper-tail pixels detected by *illustrative* `R²<0.98`, ratio `<10`, or
  their union. Thresholds are not validated and should not be adopted as a
  reliability mask from this analysis alone.
- `missing_inputs.txt`: only if files are absent and skipped.

The upper SWS tail defaults to the top 10% **within each ROI**. This is a
relative spatial anomaly definition, **not** ground-truth estimation error;
every sufficiently populated ROI will contain a tail. Use the same fixed
ROI and arm across frequencies and inspect changes in the *absolute* SWS
threshold before comparing tail-detection rates. `HighTailPercentile` can
be changed; do not silently compare incompatible definitions.

Spearman rank correlations use valid, co-registered pixels. The
depth-adjusted statistic subtracts the *row-wise within-ROI median* from
both SWS and quality before computing Spearman. It removes a depth trend,
but does not eliminate lateral structure or identify a cause. Spatial
averages of `R²` and amplitude/residual cover approximately one REQ-ML
window; by default window width is inferred from `patch_width_pixels`,
`step_pixels`, and map-center spacing. Supply `WindowWidthMM=...` if that
inference is unavailable. Raw IQ and SWS grids are never paired by array
index, and quality outside the acquisition FOV is NaN (no extrapolation).

Do not calculate independent-pixel p-values or confidence intervals from
these overlapping patches. For a paper-level reliability claim, test an
**a priori** quality threshold across independent acquisitions and compare
retained spatial coverage and missed errors against external reference SWS.

## Tests

```matlab
addpath(fullfile(evalRoot,"src"));
runtests(fullfile(evalRoot,"tests","test_signal_quality.m"))
```
