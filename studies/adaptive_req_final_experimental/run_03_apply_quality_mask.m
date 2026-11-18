%% Adaptive REQ-ML: stage 03 - apply frozen Full21 quality mask
% Reads stage 02's reqml_result.mat (SWS + q + exact patch features).
% No IQ processing, no q/SWS estimation, no retraining, no threshold tuning.
% The risk classifier is loaded ONCE; the large q regressor is not loaded.
% Separate M=1/2/3 and frequency outputs, with safe resumability.
%
% Set Mode="plan" (default) to inspect inputs without writing anything.
% Set Mode="run" to score using the frozen VALIDATION cutoff.

%% Editable settings
Mode = "plan";                        % "plan" or "run"
DataRoot = "/Users/sara/local/experimental-data-reorganized";
ReqMLRoot = "/Users/sara/local/req-ml";
StudyID = "adaptive_req_final_experimental_v1";
ModelLabel = "adaptive_req_full21_unfiltered_v1";
MaskVersion = "quality_mask_full21_locked_v1";
SelectedCaseIDs = strings(1,0);      % empty = all eight experiments
FrequenciesHz = [300 400 500 600];
MValues = [1 2 3];
StepPixels = 5;
ContinueOnError = true;
Verbose = true;

%% Setup
overallTimer=tic;
fprintf("\n[START] Adaptive REQ-ML frozen Full21 mask transfer\n");
assert(ismember(Mode,["plan","run"]), ...
    "AdaptiveREQ:MaskMode","Mode must be 'plan' or 'run'.");
assert(isnumeric(MValues) && isvector(MValues) && ...
    ~isempty(MValues) && all(isfinite(MValues)&MValues>0) && ...
    numel(unique(MValues))==numel(MValues), ...
    "AdaptiveREQ:MaskMValues","MValues must contain unique positive values.");
MValues=double(MValues(:)');
assert(isnumeric(FrequenciesHz) && isvector(FrequenciesHz) && ...
    all(isfinite(FrequenciesHz)&FrequenciesHz>0), ...
    "AdaptiveREQ:MaskFrequencies","Invalid FrequenciesHz.");
assert(isscalar(StepPixels) && StepPixels>0 && ...
    StepPixels==fix(StepPixels), ...
    "AdaptiveREQ:MaskStepPixels","StepPixels must be a positive integer.");

releaseDir=fullfile(ReqMLRoot,"models","adaptive_req_full21_v1");
releaseFiles=[
    fullfile(releaseDir,"req_model.mat")
    fullfile(releaseDir,"quality_mask.mat")
    fullfile(releaseDir,"operating_spec.mat")
    fullfile(releaseDir,"deployment_manifest.json")
];
studyDir=string(fileparts(mfilename("fullpath")));
assert(isfolder(studyDir),"AdaptiveREQ:MaskStudyDirectory", ...
    "Cannot resolve the stage 03 study directory.");
caseIDs=[
    "2026Feb27_homo_10perc_sp"
    "2026Feb27_homo_10perc_rswe"
    "2026Feb27_homo_5perc_sp"
    "2026Feb27_homo_5perc_rswe"
    "2026Feb27_dl_sp"
    "2026Feb27_dl_rswe"
    "2026Feb19_inc_sp"
    "2026Feb19_inc_rswe"
];
caseDates=[repmat("2026-02-27",6,1);repmat("2026-02-19",2,1)];
if isempty(SelectedCaseIDs),SelectedCaseIDs=caseIDs.';end
SelectedCaseIDs=string(SelectedCaseIDs);
assert(all(ismember(SelectedCaseIDs,caseIDs)), ...
    "AdaptiveREQ:MaskCases","SelectedCaseIDs contains an unknown experiment.");

%% Build observation plan from stage 02's exact layout
fprintf("[PLAN] Finding Full21 SWS maps for eight experiments, %d frequencies, %d M values ...\n", ...
    numel(FrequenciesHz),numel(MValues));
planningTimer=tic;
caseColumn=strings(0,1);
frequencyColumn=zeros(0,1);
mColumn=zeros(0,1);
estimateColumn=strings(0,1);
outputColumn=strings(0,1);
estimateExists=false(0,1);
maskExists=false(0,1);
for ii=1:numel(caseIDs)
    id=caseIDs(ii);
    if ~ismember(id,SelectedCaseIDs),continue;end
    root=fullfile(DataRoot,caseDates(ii),id);
    for f0=FrequenciesHz(:)'
        for m=MValues
            estimate=fullfile(root,"estimates",StudyID,"REQ-ML", ...
                ModelLabel,sprintf("%gHz",f0), ...
                "M"+string(m),"step"+string(StepPixels), ...
                "reqml_result.mat");
            output=fullfile(root,"analysis",StudyID, ...
                "M"+string(m)+"_step"+string(StepPixels), ...
                MaskVersion,"masks",ModelLabel, ...
                sprintf("%gHz",f0),"risk_mask_result.mat");
            caseColumn(end+1,1)=id; %#ok<SAGROW>
            frequencyColumn(end+1,1)=f0; %#ok<SAGROW>
            mColumn(end+1,1)=m; %#ok<SAGROW>
            estimateColumn(end+1,1)=estimate; %#ok<SAGROW>
            outputColumn(end+1,1)=output; %#ok<SAGROW>
            estimateExists(end+1,1)=isfile(estimate); %#ok<SAGROW>
            maskExists(end+1,1)=isfile(output); %#ok<SAGROW>
        end
    end
end
jobs=table(caseColumn,frequencyColumn,mColumn,estimateColumn, ...
    outputColumn,estimateExists,maskExists, ...
    VariableNames=["case_id","frequency_hz","M","estimate_file", ...
    "mask_file","estimate_exists","mask_exists"]);
fprintf("[PLAN] %d jobs, SWS inputs %d, existing masks %d (%.2f s).\n", ...
    height(jobs),nnz(jobs.estimate_exists),nnz(jobs.mask_exists), ...
    toc(planningTimer));
disp(jobs(:,["case_id","frequency_hz","M","estimate_exists","mask_exists"]));
fprintf("[PLAN] Release files: %d/%d present.\n", ...
    nnz(isfile(releaseFiles)),numel(releaseFiles));
if Mode=="plan"
    fprintf("[PLAN] Read-only. Nothing loaded or written (%.2f s).\n", ...
        toc(overallTimer));
    return
end

%% Load only the classifier and the frozen VALIDATION cutoff
assert(all(isfile(releaseFiles)),"AdaptiveREQ:MaskReleaseMissing", ...
    "The published Full21 release is incomplete; do not apply a different mask.");
assert(isfolder(fullfile(ReqMLRoot,"src")), ...
    "AdaptiveREQ:MaskREQRoot","Missing REQ-ML src directory.");
addpath(fullfile(ReqMLRoot,"src"),"-begin");
addpath(studyDir,"-begin");
assert(~isempty(which("load_adaptive_req_full21_quality_mask")) && ...
    ~isempty(which("score_adaptive_req_full21_quality_mask")), ...
    "AdaptiveREQ:MaskFunctionsMissing","Stage 03 helper functions missing.");
fprintf("[PREFLIGHT] Loading frozen classifier and cutoff (not q regressor) ...\n");
loadTimer=tic;
release=load_adaptive_req_full21_quality_mask( ...
    ReleaseDirectory=releaseDir,Verbose=Verbose);
fprintf("[PREFLIGHT] Classifier ready in %.2f s | locked cutoff %.17g.\n", ...
    toc(loadTimer),release.cutoff);

% Fingerprint file metadata, not the contents of huge binary MAT models.
releaseIdentity=cell(numel(releaseFiles),1);
for k=1:numel(releaseFiles)
    releaseIdentity{k}=localFileIdentityMask(releaseFiles(k));
end

%% Apply mask to saved features, once per acquisition/frequency/M
status=strings(height(jobs),1);
message=strings(height(jobs),1);
originalValid=nan(height(jobs),1);
retained=nan(height(jobs),1);
rejected=nan(height(jobs),1);
unscored=nan(height(jobs),1);
invalid=nan(height(jobs),1);
retainedFraction=nan(height(jobs),1);
for j=1:height(jobs)
    tick=tic;
    caseID=jobs.case_id(j);
    f0=jobs.frequency_hz(j);
    m=jobs.M(j);
    source=jobs.estimate_file(j);
    target=jobs.mask_file(j);
    fprintf("[%d/%d] %s | %g Hz | M=%g\n", ...
        j,height(jobs),caseID,f0,m);
    if ~jobs.estimate_exists(j)
        status(j)="missing_estimate";
        message(j)="Stage 02 reqml_result.mat is missing.";
        fprintf("    Missing SWS result; skipping.\n");
        if ~ContinueOnError
            error("AdaptiveREQ:MissingEstimate","Missing: %s",source);
        end
        continue
    end
    try
        if Verbose,fprintf("    [1/3] Loading saved SWS/q/patch features ...\n");end
        saved=load(source,"result","inference_identity");
        assert(isfield(saved,"result") && ...
            isfield(saved,"inference_identity"), ...
            "AdaptiveREQ:MaskStage2Format", ...
            "Stage 02 file lacks result or inference_identity: %s",source);
        R=saved.result;
        assert(isfield(R,"metadata") && isstruct(R.metadata) && ...
            isfield(R.metadata,"frequency_hz") && ...
            double(R.metadata.frequency_hz)==f0 && ...
            isfield(R.metadata,"M") && double(R.metadata.M)==m && ...
            isfield(R.metadata,"step_pixels") && ...
            double(R.metadata.step_pixels)==StepPixels && ...
            isfield(R.metadata,"experimental_study_id") && ...
            string(R.metadata.experimental_study_id)==StudyID && ...
            isfield(R.metadata,"experimental_arm") && ...
            string(R.metadata.experimental_arm)==ModelLabel && ...
            isfield(R.metadata,"experimental_case_id") && ...
            string(R.metadata.experimental_case_id)==caseID && ...
            isfield(R.metadata,"experimental_inference_identity") && ...
            string(R.metadata.experimental_inference_identity)== ...
            string(saved.inference_identity) && ...
            isfield(R.metadata,"experimental_model_release") && ...
            string(R.metadata.experimental_model_release)==releaseDir, ...
            "AdaptiveREQ:MaskEstimateIdentity", ...
            "Saved SWS map does not match its case, frequency, M, or Full21 release.");

        mask_identity=string(jsonencode(struct( ...
            "stage","adaptive_req_full21_quality_mask_v1", ...
            "case_id",caseID,"frequency_hz",f0,"M",m, ...
            "step_pixels",StepPixels, ...
            "mask_version",MaskVersion,"model_label",ModelLabel, ...
            "source_estimate",localFileIdentityMask(source), ...
            "source_inference_identity",string(saved.inference_identity), ...
            "frozen_release",{releaseIdentity}, ...
            "mask_cutoff",double(release.cutoff), ...
            "mask_model_id",release.mask_model_id))); %#ok<NASGU>

        if isfile(target)
            old=load(target,"mask_identity","quality_result");
            assert(isfield(old,"mask_identity") && ...
                string(old.mask_identity)==mask_identity && ...
                isfield(old,"quality_result"), ...
                "AdaptiveREQ:MaskStaleCheckpoint", ...
                "Existing mask has different input/model/cutoff: %s",target);
            Q=old.quality_result;
            status(j)="reused";
            fprintf("    REUSED (%.2f s).\n",toc(tick));
        else
            partial=target+".partial.mat";
            assert(~isfile(partial), ...
                "AdaptiveREQ:MaskPartial", ...
                "Incomplete mask checkpoint exists: %s",partial);
            if Verbose,fprintf("    [2/3] Computing frozen ensemble risk scores ...\n");end
            Q=score_adaptive_req_full21_quality_mask(R,release);
            quality_result=Q; %#ok<NASGU>
            if Verbose,fprintf("    [3/3] Saving score and masked SWS maps ...\n");end
            folder=string(fileparts(target));
            if ~isfolder(folder),mkdir(folder);end
            save(partial,"quality_result","mask_identity","-v7.3");
            [ok,msg]=movefile(partial,target);
            assert(ok,"AdaptiveREQ:MaskWrite", ...
                "Cannot publish complete risk mask: %s",msg);
            status(j)="completed";
            fprintf("    COMPLETED (%.2f s).\n",toc(tick));
        end
        originalValid(j)=double(Q.original_valid_count);
        retained(j)=double(Q.retained_count);
        rejected(j)=double(Q.rejected_count);
        unscored(j)=double(Q.unscored_count);
        invalid(j)=double(Q.invalid_count);
        retainedFraction(j)=double(Q.coverage_on_original_valid);
        fprintf("    Valid=%d | kept=%d | rejected=%d | unscored=%d | retained %.1f%%\n", ...
            Q.original_valid_count,Q.retained_count,Q.rejected_count, ...
            Q.unscored_count,100*Q.coverage_on_original_valid);
    catch ME
        status(j)="failed";
        message(j)=string(ME.message);
        fprintf("    FAILED (%.2f s): %s\n",toc(tick),ME.message);
        if ~ContinueOnError,rethrow(ME);end
    end
end

%% Run-scoped descriptive summary; does not compute accuracy or tune cutoff
jobs.status=status;
jobs.message=message;
jobs.original_valid_count=originalValid;
jobs.retained_count=retained;
jobs.rejected_count=rejected;
jobs.unscored_count=unscored;
jobs.invalid_count=invalid;
jobs.retained_fraction=retainedFraction;
reportRoot=fullfile(DataRoot,"analysis",StudyID,"quality_mask_reports");
stamp=string(datetime("now","Format","yyyyMMdd_HHmmss_SSS"));
reportFolder=fullfile(reportRoot,stamp);
assert(~isfolder(reportFolder), ...
    "AdaptiveREQ:MaskReportCollision","Report folder already exists.");
mkdir(reportFolder);
reportFile=fullfile(reportFolder,"quality_mask_summary.csv");
writetable(jobs,reportFile);
fprintf("\n[DONE] Completed %d | reused %d | missing SWS %d | failed %d\n", ...
    nnz(status=="completed"),nnz(status=="reused"), ...
    nnz(status=="missing_estimate"),nnz(status=="failed"));
fprintf("[DONE] Report: %s\n",reportFile);
fprintf("[DONE] Total: %.1f s. VALIDATION cutoff unchanged; no TEST used.\n", ...
    toc(overallTimer));

%% Local helper: immutable file metadata identity
function spec=localFileIdentityMask(filename)
    assert(isfile(filename),"AdaptiveREQ:MaskFileMissing", ...
        "Missing: %s",filename);
    info=dir(filename);
    spec=struct("path",string(filename), ...
        "bytes",double(info.bytes), ...
        "datenum",double(info.datenum));
end
