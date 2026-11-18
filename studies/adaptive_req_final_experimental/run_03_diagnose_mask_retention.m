%% Adaptive REQ-ML: stage 03 diagnostic - experimental mask retention
% READ-ONLY scientific audit of saved Full21 stage-03 quality_result MATs.
% Focus: spatial selection, score distribution and SWS before/after masking.
% No training, recalibration, thresholds sweeps or model loading.
%
% This script cannot measure experimental SWS error without reference SWS.
% A large SWS change after masking is a SELECTION EFFECT, not proof of gain.

%% Editable settings
Mode = "run";                      % "plan" or "run"
DataRoot = "/Users/sara/local/experimental-data-reorganized";
StudyID = "adaptive_req_final_experimental_v1";
ModelLabel = "adaptive_req_full21_unfiltered_v1";
MaskVersion = "quality_mask_full21_val85_posthoc_v2";
SelectedCaseIDs = strings(1,0);   % empty = all eight
FrequenciesHz = [300 400 500 600];
MValues = [1 2 3];
StepPixels = 3;
MakeDiagnosticFigures = true;      % risk histogram + retention vs SWS (per available job)
Verbose = true;

%% Locate exact same artifacts as stages 02, 03 and 04
timer=tic;
assert(ismember(Mode,["plan","run"]),"AdaptiveREQ:MaskDiagnosticMode");
here=string(fileparts(mfilename("fullpath")));
addpath(here,"-begin");
assert(~isempty(which("adaptive_req_final_case_rois")), ...
    "AdaptiveREQ:MaskDiagnosticROIs","ROI helper missing.");
cases=[
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
if isempty(SelectedCaseIDs),SelectedCaseIDs=cases';end
SelectedCaseIDs=string(SelectedCaseIDs);
assert(all(ismember(SelectedCaseIDs,cases)), ...
    "AdaptiveREQ:MaskDiagnosticCaseID","Unknown case ID.");
jobIDs=strings(0,1);
jobHz=zeros(0,1);
jobM=zeros(0,1);
jobPaths=strings(0,1);
jobExists=false(0,1);
for i=1:numel(cases)
    id=cases(i);
    if ~ismember(id,SelectedCaseIDs),continue;end
    root=fullfile(DataRoot,dates(i),id);
    for hz=FrequenciesHz(:)'
        for m=MValues
            f=fullfile(root,"analysis",StudyID, ...
                "M"+string(m)+"_step"+string(StepPixels), ...
                MaskVersion,"masks",ModelLabel, ...
                sprintf("%gHz",hz),"risk_mask_result.mat");
            jobIDs(end+1,1)=id; %#ok<SAGROW>
            jobHz(end+1,1)=hz; %#ok<SAGROW>
            jobM(end+1,1)=m; %#ok<SAGROW>
            jobPaths(end+1,1)=f; %#ok<SAGROW>
            jobExists(end+1,1)=isfile(f); %#ok<SAGROW>
        end
    end
end
J=table(jobIDs,jobHz,jobM,jobPaths,jobExists, ...
    VariableNames=["case_id","frequency_hz","M","mask_file","exists"]);
fprintf("[RETENTION PLAN] %d jobs, %d saved quality masks found.\n", ...
    height(J),nnz(J.exists));
disp(J(:,["case_id","frequency_hz","M","exists"]));
if Mode=="plan"
    fprintf("[RETENTION PLAN] No files written (%.2f s).\n",toc(timer));
    return
end

%% Only analyze existing masks. Never modify or reinterpret frozen cutoff.
rows=cell(0,1);
failures=cell(0,4);
figurePaths=strings(0,1);
reportRoot=fullfile(DataRoot,"analysis",StudyID, ...
    "mask_retention_diagnostics",MaskVersion);
stamp=string(datetime("now","Format","yyyyMMdd_HHmmss_SSS"));
reportDir=fullfile(reportRoot,stamp);
assert(~isfolder(reportDir), ...
    "AdaptiveREQ:MaskDiagnosticCollision","Timestamp collision.");
mkdir(reportDir);
for j=1:height(J)
    if ~J.exists(j),continue;end
    id=J.case_id(j);
    hz=J.frequency_hz(j);
    m=J.M(j);
    try
        saved=load(J.mask_file(j),"quality_result");
        assert(isfield(saved,"quality_result"), ...
            "AdaptiveREQ:MaskDiagnosticMissingResult", ...
            "Saved mask MAT has no quality_result.");
        Q=saved.quality_result;
        required=["original_sws_map","masked_sws_map", ...
            "original_valid_mask","retained_mask","rejected_mask", ...
            "unscored_mask","risk_score_map","cutoff","x_mm","z_mm"];
        assert(all(isfield(Q,cellstr(required))), ...
            "AdaptiveREQ:MaskDiagnosticSchema", ...
            "Saved mask is missing required maps.");
        C=adaptive_req_final_case_rois(id);
        [nz,nx]=size(Q.original_sws_map);
        assert(isequal(size(Q.risk_score_map),[nz nx]) && ...
            isequal(size(Q.original_valid_mask),[nz nx]) && ...
            isequal(size(Q.retained_mask),[nz nx]) && ...
            numel(Q.x_mm)==nx && numel(Q.z_mm)==nz, ...
            "AdaptiveREQ:MaskDiagnosticGrid", ...
            "Mask maps/coordinates have incompatible dimensions.");

        rows{end+1,1}=diagnosticRow(Q,id,hz,m,"full_fov", ...
            true(nz,nx)); %#ok<SAGROW>
        for k=1:numel(C.rois)
            roi=C.rois(k);
            center=double(roi.center_mm(:));
            width=double(roi.size_mm(:));
            x=double(Q.x_mm(:)');
            z=double(Q.z_mm(:));
            inside=(x>=center(1)-width(1)/2 & ...
                x<=center(1)+width(1)/2) & ...
                (z>=center(2)-width(2)/2 & ...
                z<=center(2)+width(2)/2);
            rows{end+1,1}=diagnosticRow(Q,id,hz,m, ...
                string(roi.name),inside); %#ok<SAGROW>
        end
        if MakeDiagnosticFigures
            base=fullfile(reportDir,"figures", ...
                id+"_"+string(hz)+"Hz_M"+string(m)+"_step"+ ...
                string(StepPixels));
            figFile=diagnosticFigure(Q,base,id,hz,m);
            figurePaths(end+1,1)=figFile; %#ok<SAGROW>
        end
        if Verbose
            fprintf("[MASK %d/%d] %s %g Hz M=%g: retained %.1f%% of valid SWS\n", ...
                j,height(J),id,hz,m, ...
                100*nnz(Q.retained_mask)/max(1,nnz(Q.original_valid_mask)));
        end
    catch ME
        fprintf(2,"[MASK %d/%d] FAILED: %s\n",j,height(J),ME.message);
        failures(end+1,:)={id,hz,m,string(ME.message)}; %#ok<SAGROW>
    end
end

if isempty(rows)
    error("AdaptiveREQ:MaskDiagnosticNoRows", ...
        "No quality mask data could be summarized; check step3 outputs.");
end
T=vertcat(rows{:});
summaryFile=fullfile(reportDir,"mask_retention_by_roi.csv");
writetable(T,summaryFile);
fprintf("\n[DONE] %d ROI/FOV rows from %d masks | %.2f s\n", ...
    height(T),nnz(J.exists),toc(timer));
fprintf("[DONE] %s\n",summaryFile);
fprintf("[CAUTION] SWS before/after differences measure selection, not accuracy.\n");
if ~isempty(failures)
    F=cell2table(failures,VariableNames= ...
        ["case_id","frequency_hz","M","message"]);
    writetable(F,fullfile(reportDir,"mask_retention_failures.csv"));
end

%% Local helpers
function T=diagnosticRow(Q,id,hz,m,roi,within)
    valid=logical(Q.original_valid_mask)&within;
    retained=logical(Q.retained_mask)&within;
    rejected=logical(Q.rejected_mask)&within;
    unscored=logical(Q.unscored_mask)&within;
    assert(~any(retained&rejected,"all") && ...
        nnz(retained)+nnz(rejected)+nnz(unscored)==nnz(valid), ...
        "AdaptiveREQ:MaskDiagnosticPartition", ...
        "ROI kept/rejected/unscored does not partition original-valid.");
    original=double(Q.original_sws_map);
    score=double(Q.risk_score_map);
    finiteScores=score(valid&isfinite(score));
    origSWS=original(valid);
    keptSWS=original(retained);
    n=nnz(valid);
    kept=nnz(retained);
    nScores=numel(finiteScores);
    pctRet=NaN;pctScored=NaN;
    if n>0,pctRet=100*kept/n;pctScored=100*nScores/n;end
    allMedian=safeMedian(origSWS);
    keptMedian=safeMedian(keptSWS);
    medianShift=keptMedian-allMedian;
    meanShift=safeMean(keptSWS)-safeMean(origSWS);
    pctOriginalAbove35=NaN;pctKeptAbove35=NaN;
    if n>0,pctOriginalAbove35=100*nnz(origSWS>3.5)/n;end
    if kept>0,pctKeptAbove35=100*nnz(keptSWS>3.5)/kept;end
    T=table(id,hz,m,roi,nnz(within),n,kept,nnz(rejected), ...
        nnz(unscored),pctRet,pctScored,double(Q.cutoff), ...
        safeQuantile(finiteScores,.10),safeQuantile(finiteScores,.50), ...
        safeQuantile(finiteScores,.90), ...
        safeMean(origSWS),allMedian, ...
        safeMean(keptSWS),keptMedian,meanShift,medianShift, ...
        pctOriginalAbove35,pctKeptAbove35, ...
        VariableNames=["case_id","frequency_hz","M","roi", ...
        "total_pixels","original_valid","retained","rejected","unscored", ...
        "retention_percent","scored_percent","frozen_cutoff", ...
        "score_p10","score_median","score_p90", ...
        "original_mean_sws_m_s","original_median_sws_m_s", ...
        "retained_mean_sws_m_s","retained_median_sws_m_s", ...
        "mean_shift_m_s","median_shift_m_s", ...
        "original_gt_3p5_percent","retained_gt_3p5_percent"]);
end
function v=safeMedian(x)
    v=NaN;if ~isempty(x),v=median(x);end
end
function v=safeMean(x)
    v=NaN;if ~isempty(x),v=mean(x);end
end
function v=safeQuantile(x,q)
    v=NaN;if ~isempty(x),v=quantile(x,q);end
end
function file=diagnosticFigure(Q,base,id,hz,m)
    score=double(Q.risk_score_map);
    valid=logical(Q.original_valid_mask);
    selected=valid&isfinite(score);
    v=score(selected);
    if isempty(v),returnFile="";file=returnFile;return;end
    s=double(Q.original_sws_map);
    keep=logical(Q.retained_mask);
    fig=figure("Visible","off","Color","w", ...
        "Position",[100 100 1100 440]);
    cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
    L=tiledlayout(fig,1,2,"TileSpacing","compact","Padding","compact");
    a=nexttile(L);histogram(a,v,40);
    xline(a,double(Q.cutoff),"r--","Frozen cutoff", ...
        "LineWidth",1.5);
    xlabel(a,"Frozen mask risk score (not calibrated)");
    ylabel(a,"Patch count");
    b=nexttile(L);
    sws=s(selected);
    % Binned retention as a function of unmasked SWS; no truth is assumed.
    limits=[min(sws),max(sws)];
    if limits(1)==limits(2),limits=limits+[-.01 .01];end
    edges=linspace(limits(1),limits(2),21);
    [~,~,idx]=histcounts(sws,edges);
    frac=nan(20,1);counts=zeros(20,1);
    ret=keep(selected);
    for k=1:20
        use=idx==k;
        counts(k)=nnz(use);
        if counts(k)>0,frac(k)=100*mean(ret(use));end
    end
    centers=(edges(1:end-1)+edges(2:end))/2;
    plot(b,centers,frac,"-o","LineWidth",1.2,"MarkerSize",4);
    ylim(b,[0 100]);xlabel(b,"Original SWS (m/s)");
    ylabel(b,"Retained valid patches (%)");grid(b,"on");
    subtitle=sprintf("%s | %g Hz | M=%g",id,hz,m);
    title(L,subtitle,"Interpreter","none","FontWeight","normal");
    folder=string(fileparts(base));
    if ~isfolder(folder),mkdir(folder);end
    file=base+".png";
    exportgraphics(fig,file,"Resolution",200);
end
