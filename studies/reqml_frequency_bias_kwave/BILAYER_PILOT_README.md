# REQ-ML controlled bilayer: same opposed x-driven disks

This is a **separate, nondispersive 3D k-Wave validation study**, not a new
REQ-ML training campaign. The homogeneous configurations and saved outputs
are never overwritten. No solver is launched by the configuration builder.

## Frozen physics and what changes

| Quantity | Bilayer setting |
| --- | --- |
| Material | z < interface: 1.8 m/s; z >= interface: 3.0 m/s |
| Interface normal | z (horizontal in the x-z observation image) |
| Interface position | **z=0 mm provisional**, configurable via `InterfaceZM`; NOT measured experimental depth |
| Frequencies | 300, 400, 500, 600 Hz, one case per frequency |
| Attenuation / constitutive dispersion | Both disabled |
| Solver | `pstdElastic3D`, reduced `cp=10*cs` per layer |
| Observation FOV | Same 50 × 50 mm x-z FOV |
| Resolution | Pilot 0.5 mm; frozen homogeneous reference remains at 0.2 mm |

The **two actuators are cloned from the matching homogeneous JSON** for
each frequency. The bilayer builder does not recreate or reposition them:
identical 3 mm-radius disks at facing x boundaries, same source-node
sampling, x-directed velocity with amplitude 1e-6 m/s, phase difference
zero, source-plane inset, ramp, total cycles, source masks and grid.
At 0.5 mm the sparse nodes are spaced 3 cells (~1.5 mm); at 0.2 mm they
are spaced 8 cells (~1.6 mm), exactly as in the homogeneous study.
The solver source-construction code is shared, not forked.

**Important physical limitation:** The x-normal disks are driven
longitudinally in x. This can yield a substantial compressional component;
the axial measured component `U_z` must be inspected before any shear
estimator comparison. The reduced compressional speed is a computational
approximation, not the true gelatin compressional speed.

## Required code (two repositories)

- `shear-wave-simulation-framework`: branch
  `feature/reqml-bilayer-opposed-disks-20261103`, branched from `develop/v2`.
  Its existing `run_opposed_x_disks_3d.m` now calls
  `build_opposed_disk_material.m`; the same source, time-domain solver
  and output layout are retained.
- `shear-wave-estimation-evaluation`: the identically named branch,
  based on `main`, containing the builder, guarded runner and exporter.

**Do not switch framework branches while homogeneous parfor jobs are
running.** Finish those simulations first and inspect the outputs.

## Configuration-only preflight (no simulation)

MATLAB (after updating both checkouts):

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"studies","reqml_frequency_bias_kwave"),"-begin")
clear prepare_bilayer_pilot run_one_bilayer_case
rehash

tests=runtests("tests/test_reqml_bilayer_configuration.m");
disp(table(tests))
assert(all([tests.Passed]))

% Read-only preview: four proposed frequency cases
T=prepare_bilayer_pilot(GridSpacingM=0.0005);

% Explicitly write the four bilayer configs; homogeneous originals preserved
T=prepare_bilayer_pilot(GridSpacingM=0.0005,WriteConfigs=true);
```

The framework includes a separate no-solver material-map unit test:

```matlab
cd("/Users/sara/local/shear-wave-simulation-framework")
tests=runtests("tests/unit/test_opposed_x_disks_bilayer_medium.m");
disp(table(tests))
assert(all([tests.Passed]))
```

The runner and the builder will refuse to overwrite an existing run or
a config whose physical values differ from what was previously frozen.

## Execute one bilayer and inspect before sweeping

Return to the SWS evaluation repo, then:

```matlab
cd("/Users/sara/local/shear-wave-estimation-evaluation")
addpath(fullfile(pwd,"studies","reqml_frequency_bias_kwave"),"-begin")

% Same 0.5-mm settings and SAME actuators as the homogeneous pilot
pilot=run_one_bilayer_case( ...
    CaseID="bilayer_soft180_hard300_f500", ...
    GridSpacingM=0.0005,InterfaceZM=0, ...
    Execute=true,ResourcesReviewed=true);

% Check run.mat and central_xz_plane.png before the full sweep.
```

If the pilot is finite and the P/S amplitude components and interface
truth map look sensible, run the remaining four-frequency campaign
**sequentially** (or at most a resource-reviewed few parallel workers):

```matlab
T=prepare_bilayer_pilot(GridSpacingM=0.0005, ...
    InterfaceZM=0,WriteConfigs=true);
for i=1:height(T)
    out=run_one_bilayer_case( ...
        CaseID=T.case_id(i),GridSpacingM=0.0005,InterfaceZM=0, ...
        Execute=true,ResourcesReviewed=true);
    fprintf("%s: %s\n",out.case_id,out.status);
end
```

All runs have independent output directories and already-verified
completed runs are skipped. They are stored under:

```text
<original-output-root>/resolution_pilots/dx0p5mm/bilayer/
  interface_z_plus0p0mm/
    configs/bilayer_soft180_hard300_f300.json
    ...
    runs/bilayer_soft180_hard300_f300/run.mat
    ...
```

Moving the interface with e.g. `InterfaceZM=0.005` chooses a **distinct
output directory**. Do not use a provisional midpoint interface to claim
agreement with experimental layer geometry. The experimental interface
location and layer orientation must be confirmed first.

## Export to REQ-ML and check truth

The study exporter accepts homogeneous and bilayer `run.mat` files,
converting the **spatial** `cs_m_s_zx` truth into `cs_map_zx` and the
corresponding `k_map_zx=2*pi*f./cs_map_zx`, with material IDs 2/3.
It does not equate the physical total axial signal with the separated
shear component.

```matlab
sample=export_opposed_disk_sample(pilot.run_file, ...
    Component="axial_total",ApplyFixedDonut=false);
```

The first evaluation should inspect raw axial total, axial shear-only and
compressional maps, and compare estimates at the same valid physical ROI
across frequencies. A 0.5-mm result is **not** a converged quantitative
reference; test resolution convergence before claiming systematic SWS bias.

No MATLAB solver or MATLAB unit test has been run in the preparation
environment; execute the above tests on the local checkouts before k-Wave.
