%% Adaptive REQ-ML: stage 04 - publication figures for experimental Full21.
% Reads immutable stage-02 SWS and stage-03 frozen-mask results.
% Renders paper-quality individual and combined maps with physical ROIs.
% Uses EWP's raw acquisition provenance for B-mode (no guessed filenames).
% No model loading, no inference, no IQ processing and no quality refitting.
%
% B-mode overlays are produced ONLY when the raw B-mode IQ and displacement
% IQ share the same grid and physical FOV. If not, plain SWS figures still
% render, and the report records that no overlay was possible.

%% Editable settings
Mode = "plan";                        % "plan" or "run"
DataRoot = "/Users/sara/local/experimental-data-reorganized";
StudyID = "adaptive_req_final_experimental_v1";
ProcessedRunName = "adaptive_req_final_unfiltered_v1";
ModelLabel = "adaptive_req_full21_unfiltered_v1";
MaskVersion = "quality_mask_full21_locked_v1";
FigureVersion = "paper_figures_full21_v1";

SelectedCaseIDs = strings(1,0);     % empty = all eight
FrequenciesHz = [300 400 500 600];
MValues = [1 2 3];
StepPixels = 5;

SwsLimits = [1.5 3.5];             % fixed scientific comparison range
SwsTicks = 1.5:0.5:3.5;
TickDecimals = 1;
OverlayAlpha = 0.70;
FigureFormats = ["png","pdf","fig"];
SaveIndividual = true;
SaveCombined = true;
ShowROIs = true;
Visible = false;
Overwrite = false;                   % do not overwrite existing figures
RequireMask = false;                 % still plot originals if stage 03 incomplete
RequireBmode = false;                % still plot plain maps if B-mode unavailable
ContinueOnError = true;
Verbose = true;

%% Setup and preflight
totalTimer=tic;
fprintf("\n[START] Adaptive REQ-ML Full21 experimental paper figures\n");
assert(ismember(Mode,["plan","run"]), ...
    "AdaptiveREQ:PlotMode","Mode must be plan or run.");
assert(isnumeric(MValues) && isvector(MValues) && ...
    ~isempty(MValues) && all(isfinite(MValues)&MValues>0) && ...
    numel(unique(MValues))==numel(MValues), ...
    "AdaptiveREQ:PlotMValues","Expected distinct positive M values.");
MValues=double(MValues(:)');
assert(isnumeric(FrequenciesHz) && isvector(FrequenciesHz) && ...
    ~isempty(FrequenciesHz) && ...
    all(isfinite(FrequenciesHz)&FrequenciesHz>0), ...
    "AdaptiveREQ:PlotFrequencies","Invalid FrequenciesHz.");
assert(isscalar(StepPixels) && isfinite(StepPixels) && ...
    StepPixels>0 && StepPixels==fix(StepPixels), ...
    "AdaptiveREQ:PlotStep","StepPixels must be a positive integer.");

studyDir=string(fileparts(mfilename("fullpath")));
evalRoot=string(fileparts(fileparts(studyDir)));
assert(isfolder(fullfile(evalRoot,"src")), ...
    "AdaptiveREQ:PlotRepo","Cannot locate SWSEval/src.");
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
dates=[repmat("2026-02-27",6,1);repmat("2026-02-19",2,1)];
if isempty(SelectedCaseIDs),SelectedCaseIDs=caseIDs.';end
SelectedCaseIDs=string(SelectedCaseIDs);
assert(all(ismember(SelectedCaseIDs,caseIDs)), ...
    "AdaptiveREQ:PlotCaseID","Unknown SelectedCaseIDs.");

%% Read-only plan; does not load huge MAT files or B-mode
fprintf("[PLAN] Checking stage 02/03 files for %d cases, %d frequencies, %d M values ...\n", ...
    numel(SelectedCaseIDs),numel(FrequenciesHz),numel(MValues));
ids=strings(0,1); freq=zeros(0,1); ms=zeros(0,1);
samples=strings(0,1); originalFiles=strings(0,1);
maskFiles=strings(0,1); figureDirs=strings(0,1);
originalFound=false(0,1); maskFound=false(0,1);
for k=1:numel(caseIDs)
    id=caseIDs(k);
    if ~ismember(id,SelectedCaseIDs),continue;end
    root=fullfile(DataRoot,dates(k),id);
    for hz=FrequenciesHz(:)'
        sample=fullfile(root,"processed",ProcessedRunName, ...
            sprintf("%gHz",hz),"wavefield_sample.mat");
        for m=MValues
            estimate=fullfile(root,"estimates",StudyID,"REQ-ML", ...
                ModelLabel,sprintf("%gHz",hz), ...
                "M"+string(m),"step"+string(StepPixels), ...
                "reqml_result.mat");
            quality=fullfile(root,"analysis",StudyID, ...
                "M"+string(m)+"_step"+string(StepPixels), ...
                MaskVersion,"masks",ModelLabel, ...
                sprintf("%gHz",hz),"risk_mask_result.mat");
            figures=fullfile(root,"analysis",StudyID, ...
                "M"+string(m)+"_step"+string(StepPixels), ...
                FigureVersion,ModelLabel,sprintf("%gHz",hz));
            ids(end+1,1)=id; %#ok<SAGROW>
            freq(end+1,1)=hz; %#ok<SAGROW>
            ms(end+1,1)=m; %#ok<SAGROW>
            samples(end+1,1)=sample; %#ok<SAGROW>
            originalFiles(end+1,1)=estimate; %#ok<SAGROW>
            maskFiles(end+1,1)=quality; %#ok<SAGROW>
            figureDirs(end+1,1)=figures; %#ok<SAGROW>
            originalFound(end+1,1)=isfile(estimate); %#ok<SAGROW>
            maskFound(end+1,1)=isfile(quality); %#ok<SAGROW>
        end
    end
end
jobs=table(ids,freq,ms,samples,originalFiles,maskFiles,figureDirs, ...
    originalFound,maskFound, ...
    VariableNames=["case_id","frequency_hz","M","sample_file", ...
    "estimate_file","mask_file","figure_dir", ...
    "estimate_exists","mask_exists"]);
fprintf("[PLAN] %d figure jobs | stage 02 ready: %d | stage 03 ready: %d\n", ...
    height(jobs),nnz(jobs.estimate_exists),nnz(jobs.mask_exists));
disp(jobs(:,["case_id","frequency_hz","M","estimate_exists","mask_exists"]));
if Mode=="plan"
    fprintf("[PLAN] Read-only finished (%.2f s).\n",toc(totalTimer));
    return
end

%% Rendering setup
addpath(fullfile(evalRoot,"src"),"-begin");
addpath(studyDir,"-begin");
assert(~isempty(which("swseval.viz.mapColormap")) && ...
    ~isempty(which("adaptive_req_final_case_rois")) && ...
    ~isempty(which("load_adaptive_req_final_bmode")) && ...
    ~isempty(which("render_adaptive_req_final_sws_figures")), ...
    "AdaptiveREQ:PlotHelpersMissing","Plotting helpers not found.");
fprintf("[RUN] Rendering available maps (saved originals are never modified).\n");
statuses=strings(height(jobs),1);
messages=strings(height(jobs),1);
hasBmode=false(height(jobs),1);
hasMask=false(height(jobs),1);
figureCount=zeros(height(jobs),1);
for j=1:height(jobs)
    tick=tic;
    id=jobs.case_id(j);
    hz=jobs.frequency_hz(j);
    m=jobs.M(j);
    fprintf("[%d/%d] %s | %g Hz | M=%g\n", ...
        j,height(jobs),id,hz,m);
    if ~jobs.estimate_exists(j)
        statuses(j)="missing_estimate";
        messages(j)="Stage 02 SWS result absent.";
        fprintf("    SKIPPED: original SWS map missing.\n");
        if ~ContinueOnError
            error("AdaptiveREQ:PlotNoSWS","Missing %s",jobs.estimate_file(j));
        end
        continue
    end
    if RequireMask && ~jobs.mask_exists(j)
        statuses(j)="missing_mask";
        messages(j)="Stage 03 quality mask absent (RequireMask=true).";
        fprintf("    SKIPPED: required quality-mask map missing.\n");
        if ~ContinueOnError
            error("AdaptiveREQ:PlotNoMask","Missing %s",jobs.mask_file(j));
        end
        continue
    end
    try
        if Verbose,fprintf("    [1/4] Loading stage 02 SWS ...\n");end
        E=load(jobs.estimate_file(j),"result","inference_identity");
        assert(isfield(E,"result") && isfield(E,"inference_identity"), ...
            "AdaptiveREQ:PlotEstimateFormat","Invalid stage 02 file.");
        R=E.result;
        assert(isfield(R,"metadata") && isstruct(R.metadata) && ...
            isfield(R.metadata,"experimental_case_id") && ...
            string(R.metadata.experimental_case_id)==id && ...
            isfield(R.metadata,"experimental_study_id") && ...
            string(R.metadata.experimental_study_id)==StudyID && ...
            isfield(R.metadata,"experimental_arm") && ...
            string(R.metadata.experimental_arm)==ModelLabel && ...
            isfield(R.metadata,"frequency_hz") && ...
            double(R.metadata.frequency_hz)==hz && ...
            isfield(R.metadata,"M") && double(R.metadata.M)==m && ...
            isfield(R.metadata,"step_pixels") && ...
            double(R.metadata.step_pixels)==StepPixels, ...
            "AdaptiveREQ:PlotEstimateIdentity", ...
            "Stage 02 map does not match case/frequency/M.");
        Q=struct();
        if jobs.mask_exists(j)
            if Verbose,fprintf("    [2/4] Loading frozen quality mask ...\n");end
            K=load(jobs.mask_file(j),"quality_result","mask_identity");
            assert(isfield(K,"quality_result") && isfield(K,"mask_identity"), ...
                "AdaptiveREQ:PlotMaskFormat","Stage 03 mask lacks provenance.");
            identity=jsondecode(char(K.mask_identity));
            assert(isfield(identity,"source_estimate") && ...
                isfield(identity.source_estimate,"path") && ...
                string(identity.source_estimate.path)== ...
                    jobs.estimate_file(j) && ...
                isfield(identity,"source_inference_identity") && ...
                string(identity.source_inference_identity)== ...
                    string(E.inference_identity) && ...
                isfield(identity,"M") && double(identity.M)==m && ...
                isfield(identity,"frequency_hz") && ...
                double(identity.frequency_hz)==hz && ...
                isfield(K.quality_result,"release_id") && ...
                string(K.quality_result.release_id)== ...
                    "adaptive_req_full21_v1", ...
                "AdaptiveREQ:PlotMaskIdentity", ...
                "Stage 03 mask was not derived from this exact stage 02 estimate.");
            Q=K.quality_result;
        elseif Verbose
            fprintf("    [2/4] Mask not available; drawing originals only.\n");
        end
        hasMask(j)=~isempty(fieldnames(Q));
        if Verbose,fprintf("    [3/4] Resolving recorded raw B-mode and physical ROIs ...\n");end
        spec=adaptive_req_final_case_rois(id);
        processedFolder=string(fileparts(jobs.sample_file(j)));
        manifest=fullfile(processedFolder,"processing_manifest.json");
        B=load_adaptive_req_final_bmode(manifest,R);
        hasBmode(j)=logical(B.available);
        if ~B.available
            fprintf("    B-mode overlay unavailable: %s\n",string(B.reason));
            if RequireBmode
                error("AdaptiveREQ:PlotUnalignedBmode", ...
                    "B-mode is required but cannot be aligned: %s",string(B.reason));
            end
        end
        if Verbose,fprintf("    [4/4] Rendering PNG/PDF/FIG with shared SWS limits ...\n");end
        S=render_adaptive_req_final_sws_figures( ...
            R,Q,B,spec,jobs.figure_dir(j), ...
            SwsLimits=SwsLimits,SwsTicks=SwsTicks, ...
            TickDecimals=TickDecimals, ...
            OverlayAlpha=OverlayAlpha, ...
            FigureFormats=FigureFormats, ...
            SaveIndividual=SaveIndividual, ...
            SaveCombined=SaveCombined, ...
            ShowROIs=ShowROIs,Visible=Visible,Overwrite=Overwrite);
        assert(all(S.files_present), ...
            "AdaptiveREQ:PlotIncompleteExports", ...
            "At least one requested figure was not saved.");
        figureCount(j)=numel(S.files);
        if ~hasMask(j)
            statuses(j)="original_only";
        elseif ~hasBmode(j)
            statuses(j)="without_bmode";
        elseif S.n_rendered==0
            statuses(j)="reused";
        else
            statuses(j)="completed";
        end
        fprintf("    %s | %d files | %d new panels | %.2f s\n", ...
            statuses(j),figureCount(j),S.n_rendered,toc(tick));
    catch ME
        statuses(j)="failed";
        messages(j)=string(ME.message);
        fprintf("    FAILED in %.2f s: %s\n",toc(tick),ME.message);
        if ~ContinueOnError,rethrow(ME);end
    end
end

%% Immutable run report (re-running does not delete or change old figures)
jobs.status=statuses;
jobs.message=messages;
jobs.has_aligned_bmode=hasBmode;
jobs.has_quality_mask=hasMask;
jobs.figure_files=figureCount;
reportRoot=fullfile(DataRoot,"analysis",StudyID,"figure_reports");
stamp=string(datetime("now","Format","yyyyMMdd_HHmmss_SSS"));
reportDir=fullfile(reportRoot,stamp);
assert(~isfolder(reportDir), ...
    "AdaptiveREQ:PlotReportCollision","Report timestamp collision.");
mkdir(reportDir);
reportFile=fullfile(reportDir,"sws_figure_summary.csv");
writetable(jobs,reportFile);
fprintf("\n[DONE] %d completed | %d reused | %d original-only | %d no B-mode | %d missing SWS | %d failed\n", ...
    nnz(statuses=="completed"),nnz(statuses=="reused"), ...
    nnz(statuses=="original_only"),nnz(statuses=="without_bmode"), ...
    nnz(statuses=="missing_estimate"),nnz(statuses=="failed"));
fprintf("[DONE] Report: %s\n",reportFile);
fprintf("[DONE] Total: %.1f s. Fixed SWS range %.1f to %.1f m/s.\n", ...
    toc(totalTimer),SwsLimits(1),SwsLimits(2));
