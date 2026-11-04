function C=swsynth_comparison_config(options)
%SWSYNTH_COMPARISON_CONFIG Frozen REQ-ML comparison for 20 swsynth cases.
% No files are written. Mirrors studies/reqml_sp_comparison model arms.
arguments
    options.StudyRoot (1,1) string = string(fileparts(mfilename("fullpath")))
    options.ReqmlRoot (1,1) string = "/Users/sara/local/req-ml"
    options.OutputRoot (1,1) string = ""
    options.M (1,1) double {mustBeMember(options.M,[2 3])} = 2
    options.StepPixels (1,1) double {mustBeInteger,mustBePositive} = 2
    options.Arms (1,:) string = ["A_raw_v1","B_filtered_v1", ...
        "C_filtered_v2","candidate10","candidate", ...
        "candidate10_filtered","candidate_filtered"]
end
C=struct();
C.studyRoot=options.StudyRoot;
C.reqmlRoot=options.ReqmlRoot;
C.simulationOutputRoot=fullfile(C.studyRoot,"outputs");
C.outputRoot=options.OutputRoot;
if C.outputRoot==""
    C.outputRoot=fullfile(C.simulationOutputRoot,"comparison");
end
C.M=options.M;
C.StepPixels=options.StepPixels;
C.Arms=options.Arms;
C.Frequencies=[300 400 500 600];
C.FilterCsMin=0.8;
C.FilterCsMax=8;
C.FilterTaper=0.06;
C.SWSColorLimits=[1 4];
legacyArms=["A_raw_v1","B_filtered_v1","C_filtered_v2", ...
    "candidate10","candidate","candidate10_filtered","candidate_filtered"];
C.AllArms=[legacyArms,"reduced14"];
C.AllInputs=["raw","filtered","filtered","raw","raw", ...
    "filtered","filtered","raw"];
modelPaths=[ ...
    fullfile(C.reqmlRoot,"models","reduced16","model_bundle.mat"), ...
    fullfile(C.reqmlRoot,"models","reduced16","model_bundle.mat"), ...
    fullfile(C.reqmlRoot,"models","reduced16_filtered_v2","model_bundle.mat"), ...
    fullfile(C.reqmlRoot,"training","q0_v4_physical_noise", ...
        "outputs","full_training","models","candidate10"), ...
    fullfile(C.reqmlRoot,"models","candidate"), ...
    fullfile(C.reqmlRoot,"training","q0_v4_physical_noise", ...
        "outputs","full_training","models","candidate10"), ...
    fullfile(C.reqmlRoot,"models","candidate"), ...
    fullfile(C.reqmlRoot,"training","q0_v5_clean_campaign", ...
        "outputs","reduced14_transfer_bundle_v1","model_bundle.mat")];
assert(numel(unique(C.Arms))==numel(C.Arms) && ...
    all(ismember(C.Arms,C.AllArms)) && ~isempty(C.Arms), ...
    "SynthCompare:UnknownArm","Select unique arms from the registered comparison arms.");
indices=zeros(1,numel(C.Arms));
for i=1:numel(C.Arms)
    indices(i)=find(C.AllArms==C.Arms(i),1);
end
C.Inputs=C.AllInputs(indices);
C.ModelPaths=modelPaths(indices);
C.analysisRoot=fullfile(C.outputRoot,"analysis");
% Preserve the original seven-arm analysis path and all prior outputs.
if ~isequal(C.Arms,legacyArms) || C.M~=2 || C.StepPixels~=2
    tag="M"+string(C.M)+"_step"+string(C.StepPixels)+ ...
        "_"+strjoin(C.Arms,"_");
    C.analysisRoot=fullfile(C.analysisRoot,"alternatives",tag);
end
C.Cases=prepare_swsynth_frequency_study( ...
    OutputRoot=C.simulationOutputRoot,WriteConfigs=false);
C.Cases.series=regexprep(C.Cases.case_id,"_f[0-9]+$","");
assert(height(C.Cases)==20 && numel(unique(C.Cases.series))==5, ...
    "SynthCompare:CaseCount","Expected five four-frequency series.");
end
