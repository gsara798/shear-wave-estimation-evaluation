function c=sp_comparison_config(options)
%SP_COMPARISON_CONFIG Frozen seven-arm defaults; optional Reduced14 transfer arms.
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
    options.Arms (1,:) string = ["A_raw_v1","B_filtered_v1","C_filtered_v2", ...
        "candidate10","candidate", ...
        "candidate10_filtered","candidate_filtered"]
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
% Original seven arms retain their exact saved identities and default.
% Reduced14 filtered applies the RAW-trained bundle to a filtered field:
% it is a transfer/sensitivity arm, not a model trained with filtering.
c.legacyArms=["A_raw_v1","B_filtered_v1","C_filtered_v2", ...
    "candidate10","candidate", ...
    "candidate10_filtered","candidate_filtered"];
c.allArms=[c.legacyArms,"reduced14","reduced14_filtered"];
c.fourArms=["A_raw_v1","reduced14","B_filtered_v1","reduced14_filtered"];
c.fiveArms=[c.fourArms,"candidate10_filtered"];
c.allInputs=["raw","filtered","filtered","raw","raw", ...
    "filtered","filtered","raw","filtered"];
c.arms=o.Arms;
assert(~isempty(c.arms) && numel(unique(c.arms))==numel(c.arms) && ...
    all(ismember(c.arms,c.allArms)), ...
    "SPCompare:Arms","Select unique arms from the registered nine.");
idx=zeros(1,numel(c.arms));
for k=1:numel(c.arms)
    idx(k)=find(c.allArms==c.arms(k),1);
end
c.inputKinds=c.allInputs(idx);
% Write nine-arm or subset analyses separately; keep the original
% seven-arm analysis and estimate roots unchanged.
c.analysisName=c.comparisonName;
if ~isequal(c.arms,c.legacyArms)
    if isequal(c.arms,c.allArms)
        c.analysisName=c.comparisonName+"_reduced14_9arms_v1";
    elseif isequal(c.arms,c.fourArms)
        c.analysisName=c.comparisonName+"_reduced14_4arms_v1";
    elseif isequal(c.arms,c.fiveArms)
        c.analysisName=c.comparisonName+"_reduced14_5arms_v1";
    else
        c.analysisName=c.comparisonName+"_subset_"+strjoin(c.arms,"_");
    end
end
% New ROI policy is versioned: retain earlier two-ROI analyses intact.
c.analysisName=c.analysisName+"_matched_bilayer_v3";
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
c.reduced14Bundle=fullfile(o.ReqmlRoot,"training", ...
    "q0_v5_clean_campaign","outputs","reduced14_transfer_bundle_v1", ...
    "model_bundle.mat");
modelFiles=[c.v1;c.v1;c.v2Bundle;c.candidate10;c.candidate; ...
    c.candidate10;c.candidate;c.reduced14Bundle;c.reduced14Bundle];
c.modelPaths=modelFiles(idx);
assert(numel(c.modelPaths)==numel(c.arms) && ...
    numel(c.inputKinds)==numel(c.arms), ...
    "SPCompare:ArmMapping","Every arm needs one model and one input.");
end
