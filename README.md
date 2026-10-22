# Shear Wave Estimation Evaluation (SWS-Eval)

Independent MATLAB framework for ROI-based analysis of shear-wave-speed (SWS) maps from any estimator. Does not compute SWS or process acquisitions.

## Quick start

```matlab
cd('/Users/sara/local/shear-wave-estimation-evaluation')
addpath(fullfile(pwd,'src'))
map=swseval.io.loadReqmlResult('/path/to/reqml_result.mat');
rois=[swseval.roi.rectangle('ROI1',Center=[18 24],Size=[7 7],Units='mm'); ...
      swseval.roi.rectangle('ROI2',Center=[30 24],Size=[7 7],Units='mm')];
T=swseval.analyzeROIs(map,rois,OutputDir='results/example');
```

`Center=[x,z]`, `Size=[width,height]`; `Units='pixel'` means **1-based pixel indices of the SWS estimation map**, not raw RF/IQ pixels. ROI boundaries are inclusive at pixel centers. Map axes in mm may be nonuniform but must increase.

## Input contract

An estimator adapter returns a scalar struct with `cs_map` (2-D `[z,x]`), `x_mm` and `z_mm` (physical 1-D axes), `valid_mask` and `metadata`. Invalid/nonpositive SWS are excluded from ROI statistics. ROIs outside the field remain present in outputs with zero valid coverage.

## Figures and statistics

Per-ROI `mean`, `median`, `std`, `CV`, `IQR`, `p05`, `p95`, min/max, valid coverage, selected/valid pixel counts. Overlapping windows are correlated; spatial variation is **not** an uncertainty-of-the-mean estimate. The SWS map and labeled ROIs use the matching palette, font, and export conventions of REQ-ML's figure templates (source palette documented in `docs/theme.md`). Exports PNG, PDF, TIFF. Results use CSV and MAT.

## Package boundaries

- `+io`: estimator adaptors, canonical map validation
- `+roi`: geometry and pixel masks
- `+metrics`: robust descriptive statistics
- `+viz`: reusable visual templates
- `+analysis`: frequency/model comparisons (planned)

Run `runtests('tests')` after adding `src` to the MATLAB path.

Not yet a publication-level uncertainty-analysis tool. No model-specific fields required and no training/test data accessed.


## Multi-frequency, multi-model ROI analysis

`swseval.analyzeSweep` applies a **single fixed ROI definition** to all
available REQ-ML predictions with layout
`estimates/<run>/REQ-ML/<model>/<frequency>Hz/M<M>/reqml_result.mat`.
Physical ROI coordinates in millimeters are recommended for comparisons
across maps with different spatial sampling.

```matlab
cd('/Users/sara/local/shear-wave-estimation-evaluation')
addpath(fullfile(pwd,'src'))
root="/Users/sara/local/experimental-data-reorganized/2026-02-19/2026Feb19_inc_sp/estimates/lowpass_1ms";
rois=[
 swseval.roi.rectangle("ROI1",Center=[18 24],Size=[7 7],Units="mm")
 swseval.roi.rectangle("ROI2",Center=[18 10],Size=[7 7],Units="mm")
];
T=swseval.analyzeSweep(rois,EstimatesRoot=root, ...
 Models=["candidate","candidate10"],Frequencies=[300 400 500 600], ...
 MValues=[2 3],SWSColorLimits=[1 4],ContinueOnMissing=true);
```

Outputs are written to `<EstimatesRoot>/evaluation/roi_analysis`:
`roi_statistics_all.csv`, `roi_sweep.mat`, per-file ROI-overlay maps,
and SWS-versus-frequency figures for each model/M. Curves show ROI **mean +/- spatial standard deviation** (not confidence intervals; neighboring windows are correlated). The x-axis shows only requested frequencies and the y-axis uses two decimals by default. Set `FrequencyYLim=[1 4]` to enforce the same vertical scale across models, or `YDecimals=1` for one decimal. SWS map colorbars use one decimal. Figure titles are disabled by default. Summary files use `roi_mean_std_vs_frequency_<model>_M<M>`; map overlays use `sws_map_with_rois_<model>_M<M>_<frequency>Hz`. Missing files are reported,
not silently filled in. To generate just tables without overlay maps,
use `ExportMaps=false`.
