%% Adaptive REQ-ML: stage 02 - Full21 SWS inference on processed wavefields
% Uses step 01's UNFILTERED EWP wavefield_sample.mat acquisitions.
% No IQ reprocessing, denoising, model training, spatial filtering or
% quality-mask application. Quality masking is deliberately stage 03.
%
% Run this script from any MATLAB working directory:
%   run("studies/adaptive_req_final_experimental/run_02_estimate_sws.m")
%
% MODE="plan" is READ-ONLY (default). Change to "run" after the Full21
% release is published/verified and stage 01 has completed.
% Pilot by setting SelectedCaseIDs and/or FrequenciesHz.

%% Editable settings
Mode = "plan";                         % "plan" or "run"
DataRoot = "/Users/sara/local/experimental-data-reorganized";
ReqMLRoot = "/Users/sara/local/req-ml";
ProcessedRunName = "adaptive_req_final_unfiltered_v1";
StudyID = "adaptive_req_final_experimental_v1";
ModelLabel = "adaptive_req_full21_unfiltered_v1";
SelectedCaseIDs = strings(1,0);       % empty = all eight
FrequenciesHz = [300 400 500 600];   % only available processed samples
M = 2;
StepPixels = 5;
UseParallel = true;
ContinueOnError = true;

%% Verify paths and immutable model release identity
assert(ismember(Mode,["plan","run"]),"Mode must be 'plan' or 'run'.");
assert(isscalar(M) && isfinite(M) && M>0,"M must be positive.");
assert(isscalar(StepPixels) && isfinite(StepPixels) && ...
    StepPixels>0 && StepPixels==fix(StepPixels), ...
    "StepPixels must be a positive integer.");

% This path is set by publish_adaptive_req_full21. It is intentionally
% explicit: never fall back silently to models/current or Reduced14.
ReleaseDir = fullfile(ReqMLRoot,"models","adaptive_req_full21_v1");
ModelFile = fullfile(ReleaseDir,"req_model.mat");
MaskFile = fullfile(ReleaseDir,"quality_mask.mat");
OperatingSpecFile = fullfile(ReleaseDir,"operating_spec.mat");
ReleaseManifestFile = fullfile(ReleaseDir,"deployment_manifest.json");
releaseFiles = [ModelFile,MaskFile,OperatingSpecFile,ReleaseManifestFile];
releaseReady = all(isfile(releaseFiles));

caseIDs = [
    "2026Feb27_homo_10perc_sp"
    "2026Feb27_homo_10perc_rswe"
    "2026Feb27_homo_5perc_sp"
    "2026Feb27_homo_5perc_rswe"
    "2026Feb27_dl_sp"
    "2026Feb27_dl_rswe"
    "2026Feb19_inc_sp"
    "2026Feb19_inc_rswe"
];
caseDates = [
    repmat("2026-02-27",6,1)
    repmat("2026-02-19",2,1)
];
if isempty(SelectedCaseIDs)
    SelectedCaseIDs = caseIDs.';
end
SelectedCaseIDs = string(SelectedCaseIDs);
assert(all(ismember(SelectedCaseIDs,caseIDs)), ...
    "Unknown SelectedCaseIDs. Check the eight case IDs in the script.");

% Resolve this SWSEval checkout independently of the MATLAB working folder.
studyDir = string(fileparts(mfilename("fullpath")));
evalRoot = string(fileparts(fileparts(studyDir)));
assert(isfolder(fullfile(evalRoot,"src")), ...
    "Expected SWSEval/src relative to this script: %s",evalRoot);

fprintf("\nAdaptive REQ-ML: final Full21 experimental estimation\n");
fprintf("Mode       : %s\n",Mode);
fprintf("Input run  : %s\n",ProcessedRunName);
fprintf("Model      : %s\n",ModelFile);
fprintf("Release    : %s\n",string(releaseReady));
fprintf("M=%g | step=%g | unfiltered | no quality mask\n\n",M,StepPixels);

%% Read-only observation plan, including missing processed frequencies
caseColumn = strings(0,1);
frequencyColumn = zeros(0,1);
sourceColumn = strings(0,1);
destinationColumn = strings(0,1);
inputPresentColumn = false(0,1);
existingEstimateColumn = false(0,1);

for ii = 1:numel(caseIDs)
    caseID = caseIDs(ii);
    if ~ismember(caseID,SelectedCaseIDs),continue;end
    datasetRoot = fullfile(DataRoot,caseDates(ii),caseID);
    for f0 = FrequenciesHz(:).'
        sampleFile = fullfile(datasetRoot,"processed",ProcessedRunName, ...
            sprintf("%gHz",f0),"wavefield_sample.mat");
        outputFile = fullfile(datasetRoot,"estimates",StudyID,"REQ-ML", ...
            ModelLabel,sprintf("%gHz",f0), ...
            "M"+string(M),"step"+string(StepPixels),"reqml_result.mat");
        caseColumn(end+1,1) = caseID; %#ok<SAGROW>
        frequencyColumn(end+1,1) = f0; %#ok<SAGROW>
        sourceColumn(end+1,1) = sampleFile; %#ok<SAGROW>
        destinationColumn(end+1,1) = outputFile; %#ok<SAGROW>
        inputPresentColumn(end+1,1) = isfile(sampleFile); %#ok<SAGROW>
        existingEstimateColumn(end+1,1) = isfile(outputFile); %#ok<SAGROW>
    end
end

jobs = table(caseColumn,frequencyColumn,sourceColumn, ...
    destinationColumn,inputPresentColumn,existingEstimateColumn, ...
    "VariableNames",["case_id","frequency_hz","sample_file", ...
    "estimate_file","sample_exists","estimate_exists"]);
disp(jobs(:,["case_id","frequency_hz","sample_exists","estimate_exists"]));
fprintf("Processed samples: %d/%d\n",nnz(jobs.sample_exists),height(jobs));
if ~releaseReady
    fprintf("Full21 release is incomplete or not present in this checkout:\n");
    for releaseFile = releaseFiles
        if ~isfile(releaseFile),fprintf("  MISSING: %s\n",releaseFile);end
    end
end

if Mode=="plan"
    fprintf("\nPlan only: no inference or output writing performed.\n");
    return
end

%% Run preflight. No TEST recomputation or model re-fitting.
assert(releaseReady, ...
    "Full21 publication incomplete. Finish publish_adaptive_req_full21 and verification.");
assert(isfolder(fullfile(ReqMLRoot,"src")), ...
    "REQ-ML/src not found: %s",ReqMLRoot);
addpath(fullfile(ReqMLRoot,"src"),"-begin");
addpath(fullfile(evalRoot,"src"),"-begin");
assert(~isempty(which("reqml.predictSWS")) && ...
    ~isempty(which("reqml.models.loadQ0Model")), ...
    "REQ-ML inference API not found.");
assert(~isempty(which("swseval.io.loadReqmlResult")), ...
    "SWSEval result loader not found.");

% Current documented REQ-ML public API accepts a Q0-compatible MAT bundle
% with these variables. The new publisher has a distinct filename:
% inspect its contents explicitly instead of silently assuming a format.
fileInfo = whos("-file",char(ModelFile));
variables = string({fileInfo.name});
requiredVariables = ["model","model_metadata","predictor_names"];
missingVariables = setdiff(requiredVariables,variables);
assert(isempty(missingVariables), ...
    ["Published req_model.mat lacks REQ-ML public-inference variables: %s. " + ...
     "The Full21 publisher/inference interface must be reconciled before estimating."], ...
    strjoin(missingVariables,", "));

loaded = reqml.models.loadQ0Model(Model=ModelFile);
predictorNames = string(loaded.predictor_names(:));
assert(numel(predictorNames)==21 && ...
    all(strlength(predictorNames)>0) && ...
    numel(unique(predictorNames))==21, ...
    "Expected exactly 21 unique predictor names in published Full21.");
if isfield(loaded.model_metadata,"filter_arm")
    filterArm = string(loaded.model_metadata.filter_arm);
    assert(ismember(filterArm,["unfiltered","none"]), ...
        "The published model does not declare unfiltered training: %s",filterArm);
end

% Keep output IDs tied to input/model files AND all versioned release files.
% The identity is a file-metadata guard, not a cryptographic hash.
releaseInfo = cell(size(releaseFiles));
for k = 1:numel(releaseFiles)
    releaseInfo{k} = localFileIdentity(releaseFiles(k));
end

status = strings(height(jobs),1);
message = strings(height(jobs),1);
validFraction = nan(height(jobs),1);
for j = 1:height(jobs)
    caseID = jobs.case_id(j);
    frequency = jobs.frequency_hz(j);
    sampleFile = jobs.sample_file(j);
    estimateFile = jobs.estimate_file(j);
    fprintf("[%d/%d] %s | %g Hz ... ",j,height(jobs),caseID,frequency);

    if ~jobs.sample_exists(j)
        status(j) = "missing_sample";
        message(j) = "Stage 01 wavefield_sample.mat missing.";
        fprintf("missing processed sample\n");
        if ~ContinueOnError
            error("AdaptiveREQ:MissingSample","Missing: %s",sampleFile);
        end
        continue
    end

    try
        % Confirm provenance of the actual sample, not merely its folder.
        runConfigFile = fullfile(fileparts(fileparts(sampleFile)),"run_config.json");
        sampleManifestFile = fullfile(fileparts(sampleFile),"processing_manifest.json");
        assert(isfile(runConfigFile) && isfile(sampleManifestFile), ...
            "EWP run_config.json or processing_manifest.json is missing: %s",sampleFile);
        processingConfig = jsondecode(fileread(runConfigFile));
        assert(isfield(processingConfig,"spatial_filter_mode") && ...
            string(processingConfig.spatial_filter_mode)=="none" && ...
            isfield(processingConfig,"donut_enabled") && ...
            ~logical(processingConfig.donut_enabled) && ...
            isfield(processingConfig,"remove_svd_modes") && ...
            double(processingConfig.remove_svd_modes)==0, ...
            "Input run is not verified as unfiltered with SVD=0: %s",runConfigFile);
        identity = struct( ...
            "study_id",StudyID,"case_id",caseID, ...
            "frequency_hz",frequency, ...
            "processed_run",ProcessedRunName, ...
            "model_label",ModelLabel, ...
            "sample",localFileIdentity(sampleFile), ...
            "processing_config",localFileIdentity(runConfigFile), ...
            "processing_manifest",localFileIdentity(sampleManifestFile), ...
            "release",{releaseInfo}, ...
            "M",M,"step_pixels",StepPixels, ...
            "filter_arm","unfiltered");
        % Preserve a stable, inspectable inference identity across reruns.
        inference_identity = string(jsonencode(identity)); %#ok<NASGU>
        if isfile(estimateFile)
            saved = load(estimateFile,"inference_identity");
            assert(isfield(saved,"inference_identity") && ...
                string(saved.inference_identity)==inference_identity, ...
                "Existing result has a different input, model or configuration: %s", ...
                estimateFile);
            status(j) = "reused";
            fprintf("reused\n");
            continue
        end

        outputFolder = string(fileparts(estimateFile));
        if ~isfolder(outputFolder),mkdir(outputFolder);end
        partialFile = estimateFile+".partial.mat";
        assert(~isfile(partialFile), ...
            "Interrupted partial output exists; inspect it before retry: %s",partialFile);

        result = reqml.predictSWS(sampleFile, ...
            ModelBundle=loaded, ...
            M=M,StepPixels=StepPixels, ...
            UseParallel=UseParallel,RequireTruth=false,Verbose=false);
        % Keep the original predictor outputs, including patch_examples.
        % Stage 03 needs these same features and q predictions for mask scoring.
        assert(isstruct(result) && ...
            all(isfield(result,["cs_map","q_map","valid_mask", ...
                "x_mm","z_mm","patch_examples","metadata"])), ...
            "REQ-ML prediction does not meet the expected result schema.");
        assert(isequal(size(result.cs_map),size(result.q_map), ...
            size(result.valid_mask)), ...
            "SWS/q/validity maps do not have matching dimensions.");
        assert(nnz(result.valid_mask)>0, ...
            "No valid SWS patches in %s at %g Hz.",caseID,frequency);
        assert(isfield(result.metadata,"frequency_hz") && ...
            isfinite(double(result.metadata.frequency_hz)) && ...
            double(result.metadata.frequency_hz)==frequency, ...
            "Saved sample frequency differs from requested frequency %g Hz.",frequency);
        result.metadata.experimental_case_id = caseID;
        result.metadata.experimental_study_id = StudyID;
        result.metadata.experimental_arm = ModelLabel;
        result.metadata.experimental_processed_run = ProcessedRunName;
        result.metadata.experimental_model_release = ReleaseDir;
        result.metadata.experimental_inference_identity = inference_identity;
        result.metadata.experimental_mask_applied = false;

        % Only publish complete MAT files; leave old data untouched.
        save(partialFile,"result","inference_identity","-v7.3");
        [ok,moveMessage] = movefile(partialFile,estimateFile);
        assert(ok,"Failed to publish completed MAT: %s",moveMessage);
        status(j) = "completed";
        validFraction(j) = nnz(result.valid_mask)/numel(result.valid_mask);
        fprintf("completed | %.1f%% valid patches\n",100*validFraction(j));

    catch ME
        status(j) = "failed";
        message(j) = string(ME.message);
        fprintf("FAILED: %s\n",ME.message);
        if ~ContinueOnError,rethrow(ME);end
    end
end

%% Keep a separate dated report; do not overwrite prior pilot reports.
jobs.status = status;
jobs.message = message;
jobs.valid_fraction = validFraction;
reportRoot = fullfile(DataRoot,"analysis",StudyID,"estimation_reports");
stamp = string(datetime("now","Format","yyyyMMdd_HHmmss_SSS"));
reportFolder = fullfile(reportRoot,stamp);
if ~isfolder(reportFolder),mkdir(reportFolder);end
summaryFile = fullfile(reportFolder,"sws_estimation_summary.csv");
writetable(jobs,summaryFile);
fprintf("\nInference report: %s\n",summaryFile);
fprintf("Completed: %d | reused: %d | missing input: %d | failed: %d\n", ...
    nnz(status=="completed"),nnz(status=="reused"), ...
    nnz(status=="missing_sample"),nnz(status=="failed"));

%% Local file-provenance helper
function spec = localFileIdentity(filename)
    assert(isfile(filename),"File not found: %s",filename);
    info = dir(filename);
    spec = struct("path",string(filename), ...
        "bytes",double(info.bytes),"datenum",double(info.datenum));
end
