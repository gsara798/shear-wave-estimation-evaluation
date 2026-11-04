# Experimental REQ-ML comparison — RSWE phantoms, M=2

RSWE counterpart of studies/reqml_sp_comparison. Three execution stages
(IQ processing, frozen-model estimation, ROI analysis) plus comparative
plots, with separate MATLAB names and RSWE output paths. **No changes
to fitted Reduced14 or other model bundles.**

## Acquisition settings

Expected experiments under
/Users/sara/local/experimental-data-reorganized/2026-02-27:

- 2026Feb27_dl_rswe
- 2026Feb27_homo_5perc_rswe
- 2026Feb27_homo_10perc_rswe

The first two names have been referenced previously; the 10% RSWE name
follows SP conventions and **must be confirmed locally**. If it is absent,
pass the same two-element Experiments array to each stage.

Frozen settings: 300/400/500/600 Hz; M=2; StepPixels=2; EWP no
SVD mode removal (RemoveSVDModes=0), isotropic sampling, raw complex
wavefield then derived Q0-v5 global FFT donut (CsMin=0.8, CsMax=8
m/s, taper=0.06).

## Five-arm model comparison

| Arm | Input | Frozen fitted model |
| --- | --- | --- |
| A_raw_v1 | Raw | Reduced16 v1 |
| reduced14 | Raw | Reduced14 train-210 |
| B_filtered_v1 | Global donut | Same raw-trained Reduced16 v1 |
| reduced14_filtered | Global donut | Same raw-trained Reduced14 |
| candidate10_filtered | Global donut | Candidate10 historical |

Filtered arms use raw-trained models (preprocessing transfer), and
Candidate10 is an external benchmark, not a matched feature ablation.
If necessary, export the Reduced14 frozen bundle using the instructions
in ../reqml_sp_comparison/README.md before starting estimation.

### ROI definition

| Phantom | ROI | Center [x,z] mm | Size [width,height] mm |
| --- | --- | --- | --- |
| Homogeneous 5%, 10% | central | [18,18] | [16,14] |
| Double layer | ROI1 (soft) | [18,10] | [10,5] |
| Double layer | ROI2 (hard) | [18,25] | [10,5] |

The homogeneous central rectangle spans x=10–26, z=11–25 mm.
Verify ROI position against B-mode/wavefield and inspect the actual
selected extents: valid map support may vary with frequency.

## Run in MATLAB

All entry points are RSWE-prefixed to prevent a MATLAB-path collision
when the SP and RSWE study folders are both on the path.

~~~matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"src"),"-begin")
addpath(fullfile(pwd,"studies","reqml_rswe_comparison"),"-begin")
clear rswe_comparison_config rswe_run_processing rswe_run_estimation ...
    rswe_run_analysis rswe_run_plots rswe_plot_model_comparison ...
    rswe_comparison_rois
rehash

% Stage 1: EWP from IQ and derived global-donut wavefields.
rswe_run_processing(UseParallel=true);

% Stage 2: frozen predictions, resumable.
rswe_run_estimation(UseParallel=true);

% Stage 3: ROI CSV, mean SWS/CV frequency plots, model map montages,
% paired contrasts, retaining processed wavefields and predictions.
result=rswe_run_analysis(MakeComparisonPlots=true);
disp(result.summary)

% Optional: remake figures using saved results.
rswe_run_plots();
~~~

If only the two previously referenced RSWE experiments exist:

~~~matlab
rsweExperiments=["2026Feb27_dl_rswe","2026Feb27_homo_5perc_rswe"];
rswe_run_processing(Experiments=rsweExperiments);
rswe_run_estimation(Experiments=rsweExperiments);
result=rswe_run_analysis(Experiments=rsweExperiments);
~~~

For a pilot, use Experiments="2026Feb27_dl_rswe" and
UseParallel=false in each stage; then expand the experiment list.
Raw test files must match the SP file pattern test1_{frequency}Hz.mat
unless locally confirmed otherwise.

## Output layout

Processed wavefields:

- experiment/processed/reqml_compare_raw_no_spatial_v1/
- experiment/processed/reqml_compare_global_donut_0p8_8_v1/

Frozen estimates are written to:

- experiment/estimates/reqml_rswe_compare_m2_0p8_8_v1/REQ-ML/ARM/FREQHz/M2/reqml_result.mat

ROI statistics, maps and comparison plots are written to:

- experiment/analysis/reqml_rswe_compare_m2_0p8_8_v1_reduced14_5arms_v1_central_homo_v1/
- DataRoot/reqml_rswe_compare_m2_0p8_8_v1_reduced14_5arms_v1_central_homo_v1/all_experiments_roi_statistics.csv

SP outputs and fitted models are not touched. Existing compatible
processed/estimated files are verified and resumed; changed identities
are rejected, not overwritten.

MATLAB inference and plotting cannot be validated until the local
experimental MAT files and frozen bundles are available. Neither spatial
CV nor spatial SD proves experimental SWS accuracy.


## Revision: equal bilayer ROI pixel counts

Current bilayer rectangles have width 16.2 mm and height 2.0 mm.
ROI1 (soft) is centered at [18,11.5] mm and ROI2 (hard) at
[18,24.2] mm. Both use the same nominal area. The homogeneous
central ROI is unchanged (16×14 mm centered at [18,18] mm).

RSWE map coverage has **not** been inspected locally. During analysis,
swseval.metrics.assertEqualBilayerPixelCounts checks every model,
both ROIs and 300/400/500/600 Hz for matching selected counts.
It warns if valid-mask exclusions differ. If the RSWE support differs
from SP, a mismatch is reported and must be resolved before interpreting
frequency curves; a nominal geometric rectangle cannot guarantee
equal actual coverage on an uninspected dataset.

The new RSWE analysis suffix is _matched_bilayer_v2; previous
_central_homo_v1 analysis files are preserved. Predictions are reused.


## Centered bilayer ROIs and single-ROI plots (2026-11-04)

Current ROI1 (soft): center [19,15] mm, size [14.2,2.4] mm;
current ROI2 (hard): center [19,22.5] mm, size [14.2,2.4] mm.
Both span x=11.9–26.1 mm. Their z ranges are 13.8–16.2 mm and
21.3–23.7 mm, respectively. These rectangles supersede the earlier
edge-adjacent bilayer coordinates above and use the same geometry as SP.
The RSWE coverage and pixel counts have **not yet been validated** on
local RSWE maps; the analysis pixel-count assertion remains mandatory.

Homogeneous phantoms continue to use a single central [18,18] mm,
[16,14] mm ROI. `rswe_plot_model_comparison` now handles one-ROI data
without string-array dimension mismatches or an invalid two-panel
layout. The RSWE analysis suffix is now `_centered_bilayer_v3`.
Existing frozen estimates can be reused; rerun
`rswe_run_analysis(MakeComparisonPlots=true)` after pulling the change.


## Interior bilayer ROIs, matched to SP (latest)

The current geometry **supersedes all earlier bilayer placements**:
ROI1 (soft) center [19,13] mm, size [14.2,3.2] mm, extent
x=11.9–26.1 mm, z=11.4–14.6 mm; ROI2 (hard) center [19,24] mm,
size [14.2,3.2] mm, extent x=11.9–26.1 mm, z=22.4–25.6 mm.
These ROIs move away from the interlayer boundary, leaving a small
margin to the 300 Hz image extrema. RSWE pixel-grid support must still
pass `assertEqualBilayerPixelCounts`; an SP-derived nominal count of
~280 points/ROI is only an estimate, not RSWE validation.

The homogeneous ROI remains centered at [18,18] mm with size
[16,14] mm. RSWE analysis now uses the versioned suffix
`_interior_bilayer_v4`, preserving older results. Re-run only
`rswe_run_analysis(MakeComparisonPlots=true)` on saved predictions.


## Homogeneous ROI centered and slightly enlarged (latest)

Both **5% and 10% homogeneous RSWE** phantoms now use one ROI with
center [19,19.25] mm, size [17,15] mm, physical extent x=10.5–27.5 mm,
z=11.75–26.75 mm. This supersedes the old [18,18] mm / [16,14] mm
central ROI and matches the latest SP policy. The placement was chosen
from the 300 Hz 10% SP map, so inspect actual 5% and RSWE coverage before
using final statistics. Bilayer ROIs are unchanged. The current RSWE
analysis suffix is `_interior_bilayer_v4_homo_centered_large_v2`.
Re-run analysis/plots only; existing frozen predictions are reused.
