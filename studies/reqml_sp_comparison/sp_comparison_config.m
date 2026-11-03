function c=sp_comparison_config(options)
%SP_COMPARISON_CONFIG Freeze the five-arm experimental SP comparison.
% Shared policy, independent of execution stage or local working directory.
arguments
    options.DataRoot (1,1) string = ...
        "/Users/sara/local/experimental-data-reorganized/2026-02-27"
    options.ReqmlRoot (1,1) string = "/Users/sara/local/req-ml"
    options.EwpRoot (1,1) string = "/Users/sara/local/experimental-wavefield-processing"
    options.EvalRoot (1,1) string = "/Users/sara/local/shear-wave-estimation-evaluation"
    options.Experiments (1,:) string = ["2026Feb27_dl_sp", ...
        "2026Feb27_homo_5perc_sp","2026Feb27_homo_10perc_sp"]
    options.Frequencies (1,:) double = [300 400 500 600]
    options.M (1,1) double {mustBePositive} = 2
    options.StepPixels (1,1) double {mustBeInteger,mustBePositive} = 2
    options.Resume (1,1) logical = true
    options.UseParallel (1,1) logical = true
    options.MakeComparisonPlots (1,1) logical = true
end
assert(all(endsWith(options.Experiments,"_sp")) && ...
    numel(unique(options.Experiments))==numel(options.Experiments), ...
    "SPCompare:Experiments","Use unique *_sp experiments only.");
assert(isequal(options.Frequencies,[300 400 500 600]) && options.M==2, ...
    "SPCompare:Protocol","This first comparison freezes 300-600 Hz, M=2.");
o=options;
c=comparisonConfig(o);
for name=string(fieldnames(o))'
    c.(name)=o.(name);
end
addLocalPaths(o);
end

function addLocalPaths(o)
assert(isfolder(o.ReqmlRoot),"SPCompare:ReqmlRoot", ...
    "REQ-ML folder not found: %s",o.ReqmlRoot);
addpath(fullfile(o.ReqmlRoot,"src"));
addpath(fullfile(o.ReqmlRoot,"training","q0_v5_clean_campaign"));
if isfolder(fullfile(o.EwpRoot,"src")),addpath(fullfile(o.EwpRoot,"src"));end
if isfolder(fullfile(o.EvalRoot,"src")),addpath(fullfile(o.EvalRoot,"src"));end
end

function c=comparisonConfig(o)
c.comparisonName="reqml_sp_compare_m2_0p8_8_v1";
c.rawRun="reqml_compare_raw_no_spatial_v1";
c.filteredRun="reqml_compare_global_donut_0p8_8_v1";
c.arms=["A_raw_v1","B_filtered_v1","C_filtered_v2", ...
    "candidate10","candidate"];
c.inputKinds=["raw","filtered","filtered","raw","raw"];
c.csMin=0.8;c.csMax=8;c.taper=0.06;
c.v1=fullfile(o.ReqmlRoot,"models","reduced16","model_bundle.mat");
c.v2Checkpoint=fullfile(o.ReqmlRoot,"training","q0_v5_clean_campaign", ...
    "outputs","reduced16_filtered_cs0p8_8_v1","training", ...
    "models","reduced16_filtered_v2.mat");
c.v2Bundle=fullfile(o.ReqmlRoot,"models", ...
    "reduced16_filtered_v2","model_bundle.mat");
c.candidate10=fullfile(o.ReqmlRoot,"training", ...
    "q0_v4_physical_noise","outputs","full_training","models","candidate10");
c.candidate=fullfile(o.ReqmlRoot,"models","candidate");
end
