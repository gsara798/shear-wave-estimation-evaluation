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

## Subsequent stages (not implemented yet)

2. Estimate SWS and predicted quantile using verified, published Full21.
3. Score the frozen final quality mask without re-fitting.
4. Generate SWS maps with/without the mask, with/without B-mode overlay;
   fixed SWS color scale 1.5–3.5 m/s, coherent figure template and ROIs.
5. Analyze physical ROIs and SWS-vs-frequency plots with spatial
   variability error bars, retaining both combined and individual figures.

The ROIs and display policy will be taken from the previously defined
QMV2 experimental manifest, except that final inclusion plots will
highlight only core and background ROIs. No changes will be made
to the older study outputs.
