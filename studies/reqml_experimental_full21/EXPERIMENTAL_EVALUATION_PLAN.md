# Frozen Adaptive REQ Full21 + quality-mask — phantom evaluation plan

**Status:** design locked for implementation; not executed.  
**Repository:** `shear-wave-estimation-evaluation`, derived from the existing
`studies/reqml_experimental_qmv2` campaign.  
**Models:** frozen paired release in `/Users/sara/local/req-ml/models/adaptive_req_full21_v1/`
(REQ q: 160 bagged trees, minimum leaf 2; risk mask: 160 bagged trees,
minimum leaf 8). Both trained **without spatial filtering** on TRAIN.
The risk threshold was frozen on independent VALIDATION to retain 80%
there (approximately 0.14764) and evaluated once on synthetic TEST
without rethresholding (82.13% retained, SWS MAPE 3.964% to 1.7295%,
ROC-AUC 0.93265). **Do not tune any part of this pair using phantom
results.**

## 1. Scientific question and primary/secondary arms

**Primary:** transfer of the exact frozen unfiltered Full21 REQ estimator
and frozen mask to unfiltered experimental SP and RSWE phantoms.
The EWP input is the processed complex harmonic wavefield, **not raw
ultrasound RF/IQ**; "unfiltered" means **no additional spatial filtering**.
Retain the existing temporal extraction/isotropic resampling policy and
`RemoveSVDModes=0` when already used.

**Secondary, sensitivity only:** run the **same frozen unfiltered-trained**
REQ + mask on a *separately saved* global complex FFT donut-filtered
version of each raw complex harmonic wavefield. Because the model did
not train on donut-filtered spectra, this is an out-of-distribution
preprocessing perturbation, **not** an independently validated
"filtered model." Do not make this the primary accuracy claim or
change the risk threshold.

Use the historical QMV2 matched-filter estimators only for background
comparison (if required for the paper); their masks and thresholds
are **not interchangeable** with Full21.

| Preprocessing | Estimator | Mask | Role |
|---|---|---|---|
| No spatial filter | Frozen Full21 | Off | Primary baseline, full map |
| No spatial filter | Frozen Full21 | Frozen, cutoff from VALIDATION | Primary selective inference |
| Fixed global donut | **Same frozen Full21** | Off | Exploratory filter sensitivity |
| Fixed global donut | **Same frozen Full21** | **Same frozen mask and cutoff** | Exploratory filter+mask sensitivity |

The original predeclared donut is `q0v5.filter.applyFixedDonut`,
`CsMinMS=0.8`, `CsMaxMS=8`, `TaperRelative=0.06` from the
QMV2 experimental manifest. Use it unchanged and only once on the
unfiltered wavefield. No frequency-specific or ROI-specific cutoff
tuning. Its k-space support changes the radial/angular descriptors;
even a visually smoother SWS map is not evidence of improved accuracy.

## 2. Fixed acquisitions and ROIs: reuse the prior manifest

Source manifest:
`studies/reqml_experimental_qmv2/experiment_manifest.example.json`
(`data_root=/Users/sara/local/experimental-data-reorganized`,
`m=2`, `step_pixels=5`). Copy the eight case definitions into a
NEW versioned Full21 manifest rather than editing QMV2 outputs.
The established source cases are:

| Phantom | SP | RSWE | Predeclared physical ROIs |
|---|---|---|---|
| Homogeneous gelatin 10% | `2026Feb27_homo_10perc_sp` | `2026Feb27_homo_10perc_rswe` | central [19,19.25] mm, 17×15 mm |
| Homogeneous gelatin 5% | `2026Feb27_homo_5perc_sp` | `2026Feb27_homo_5perc_rswe` | same central ROI |
| Bilayer | `2026Feb27_dl_sp` | `2026Feb27_dl_rswe` | soft [19,13] mm, 14.2×3.2 mm; hard [19,24.1] mm, 14.2×3.2 mm |
| Inclusion | `2026Feb19_inc_sp` | `2026Feb19_inc_rswe` | core [19.5,24.5] mm, 8×8 mm; large [19.5,24.5] mm, 12×12 mm; background [28,13.5] mm, 6×6 mm |

Frequencies: 300, 400, 500, 600 Hz **when samples exist**. The
inclusion manifest currently discovers frequencies from physical
files. Do not assume all 32 samples exist until the read-only preflight
checks actual paths. If all exist: 8 cases × 4 frequencies = 32
acquisitions; × 2 pre-processing branches = 64 Full21 SWS/risk
inference maps (each also supports mask-off and mask-on views).

Carry forward the original contrast pairs: inclusion core/background
and large/background. Respect the existing
`roi_min_fov_fraction=0.90` and flag clipped reference ROIs;
do not silently move or resize ROIs after seeing Full21 results.

## 3. Preflight and deterministic inference contract

Implement a read-only `Stage="plan"` first, reusing existing
`qmv2_experimental_plan` style. It must report:

1. Eight case IDs, available frequencies, `raw_run` paths and source
   `wavefield_sample.mat` availability, M=2, step=5, dx/dz and
   original EWP preprocessing/provenance.
2. Both published model files and `operating_spec.mat` plus
   `deployment_manifest.json`; validate their 21/22 ordered features,
   original model IDs and exact MATLAB-double frozen cutoff.
3. Source wavefield dimensions / frequency and ROI overlap with map
   centers for each case. Source reference should be unfiltered EWP
   harmonic output; reject accidentally filtered or already-donut inputs.
4. A pilot-compatible new output identity (source bytes/mtime,
   model SHA-256/IDs, threshold, M, step, filter params, feature config,
   ROI version, repository commit) and a collision-safe resume policy.

**Important implementation distinction:** the existing
`run_qmv2_experimental_study` calls `reqml.predictSWS` with the old
`loadQ0Model` bundle. **Do NOT pass the new Full21 `req_model.mat`
through this old API.** The new model is a fitted regression checkpoint
with a separate risk classifier, not the legacy bundle schema.
Implement a dedicated adapter, reusing the same canonical REQ
feature-extraction and q-to-k-to-SWS mapping:

- `reqml.io.load_wavefield_sample` and
  `reqml.features.extractPatchFeatures` on M=2, StepX=StepZ=5,
  with identical `cs_guess_m_s=3`/feature configuration to the frozen
  REQ-ML inference code.
- Add `campaign_frequency_hz` to the truth-free patch table, verify
  the exact ordered `final21_predictors` columns and finite values;
  use the shipped release `reqml.models.predictAdaptiveReqFull21`
  or a loaded-once equivalent with identical arithmetic.
- Use `reqml.quantile.convertQPredictionsToSws` with the **same**
  patch `req_mapping` and predicted q. Map retained/rejected/
  unscorable classifications to exactly the same patch centers. Do
  not use oracle q, phantom true SWS, experimental reference values
  or quality labels as mask inputs.
- Pair both filter arms on exactly the same physical map-center grid
  and preserve original pre-mask validity. Compare full and retained
  maps only on declared common eligible support; separately report
  each arm's native coverage. Keep original, rejected and unscorable
  counts, and NaN for absent retained measurements.

Before full processing, compare output numerics for a tiny known
synthetic feature matrix with `reqml.models.predictAdaptiveReqFull21`
in REQ-ML; the SWSEval adapter should reproduce q, risk and decisions
without restandardizing features or clipping scores.

## 4. Execute in controlled stages

**Stage A — preflight:** read-only file availability, model provenance,
ROI geometry and filter identity. If all samples already exist, do
not run IQ processing or replace source wavefields.

**Stage B — small pilot:** two difficult RSWE cases
(`2026Feb27_homo_5perc_rswe`, `2026Feb19_inc_rswe`) at
300 and 600 Hz, both input branches. Pilot additionally one stable
SP reference, preferably `2026Feb27_homo_10perc_sp` at 300 and 600 Hz.
This is at most 6 physical acquisitions / 12 branch maps, conditional
on actual data availability. Produce per-case original SWS, predicted
q, risk score, retained SWS, and ROI overlay maps. Verify orientation,
physical coordinates, integer patch-index-to-map correspondence,
nonfinite handling and identical threshold between branches.
Do not vary hyperparameters, filter cutoff or threshold based on
pilot outcomes.

**Stage C — full inference:** all available 8 × 4 acquisitions at
M=2, step=5; only the two predeclared preprocessing branches.
Save source/model fingerprinted, resuming immutable checkpoints.
The four outputs per acquisition are the 2 preprocessings ×
(mask off/on); only 2 estimators/mask passes per acquisition.

**Stage D — fixed ROIs and paired analysis:** central homogeneous;
soft/hard bilayer; core/large/background inclusion.
First compare raw-versus-donut maps on matching patch-center pixels
within each frequency/ROI. For frequency trends, preserve the same
physical ROI footprint; also report actual pixel counts / map
coverage and explicitly document any changing spatial support
between frequencies (never infer equal pixel counts without
verification). Report per ROI:

- Median SWS, mean, SD, IQR, spatial coefficient of variation;
- original valid count, eligible count, retained/rejected/unscored,
  total ROI coverage, retained fraction on original-valid patches;
- quantiles q and risk-score distribution (median, IQR);
- positive-looking hotspots/outliers visually and whether rejected;
- bilayer hard/soft median SWS ratio and inclusion/background contrast;
- SP versus RSWE behavior **within matching phantom and frequency**.

Compare within-ROI SWS summary *before vs after* both on (i) native
retained support and (ii) a common matched support to make clear
whether changes arise from selection or numerical estimation.
When no retained pixels exist, report `NaN` for retained SWS/CV/
contrast and 0% retention; never report 0% CV as a success.

**Stage E — publication figure candidates:** for selected SP, RSWE,
bilayer and inclusion, paired maps of unfiltered and donut SWS,
risk scores, and retained SWS; fixed colors/axes; ROI outlines;
frequency plots of median SWS with coverage next to it; bilayer
contrast and inclusion contrast with target/background coverage.
Use the current `reqml.viz.figureTheme` palette and paper export
(PNG 300 DPI + vector PDF). Avoid selecting only visually attractive
examples; include the difficult RSWE failures/very low coverage.

## 5. Interpretation, scope, and stop conditions

- **Primary endpoint:** reproducible descriptive experimental
  estimability and frequency consistency **without spatial filtering**
  of frozen Full21 + mask, showing actual retained fraction and ROI
  spatial variation. No patient/device-level clinical claims.
- **Secondary endpoint:** paired fixed-donut sensitivity. If donut
  appears better, label as exploratory domain-shift evidence. It is
  not a deployment validation of the raw-trained model. A separately
  trained/calibrated filtered model would require new frozen training
  and independent validation and is **outside the scope** of this
  study unless motivated later by a new, explicitly separate paper.
- Without independently measured shear-wave speeds in each phantom,
  spatial CV, frequency stability and inter-ROI contrast are **not
  ground-truth accuracy or MAPE**. If independent measurements exist,
  store them with source/uncertainty and analyze separately; do not
  equate constant speed with physical truth or presume gelatin is
  perfectly nondispersive.
- Use the existing four QMV2 arm results as historical context,
  not as interchangeable mask scores, and never retroactively change
  the frozen Full21 TEST operating threshold.
- Pilot must pass source identity, feature-order, model-score alignment
  and no-data-lost invariants before full execution. Stop on an
  unsupported feature, clipped ROI, different grids or inconsistent
  model provenance, rather than filling data or silently filtering.
- After the planned 32 acquisitions are examined, close model scope
  for the TMI paper. Further filters (lowpass, variable donut, SVD
  denoising, filtering before/after harmonic extraction, or additional
  M values) are **not** part of this frozen 2-arm campaign.

## 6. Implementation entry points (not yet written)

Propose new dedicated study folder `studies/reqml_experimental_full21/`
with `experiment_manifest_full21.json`, a read-only preflight,
`run_full21_experimental_study.m` (plan/pilot/run/analyze/plot),
a strict Full21 estimator+mask adapter, fixed-donut derivation reusing
`qmv2_prepare_filtered_sample` only if source/filter identity matches,
and paper-style plots. Preserve the old `studies/reqml_experimental_qmv2`
implementation and previously generated outputs unchanged.

The first code change should be **preflight + a single-case inference
identity test**, before introducing full-case plotting.
