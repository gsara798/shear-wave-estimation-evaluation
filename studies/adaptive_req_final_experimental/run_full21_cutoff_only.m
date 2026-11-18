function report=run_full21_cutoff_only(options)
%RUN_FULL21_CUTOFF_ONLY Explore risk-score cutoffs, with NO spatial filtering.
% Uses ONLY the saved, unfiltered Full21 quality_result from stage 03.
% No IQ, wavefield, model loading, SWS estimation, mask inference or retraining.
% Original VALIDATION cutoff is never changed. Others are exploratory.
%
% Example:
% run_full21_cutoff_only(Mode="run",StepPixels=3,FrequencyHz=500,M=2);
arguments
    options.Mode (1,1) string = "plan"
    options.DataRoot (1,1) string = "/Users/sara/local/experimental-data-reorganized"
    options.StudyID (1,1) string = "adaptive_req_final_experimental_v1"
    options.ModelLabel (1,1) string = "adaptive_req_full21_unfiltered_v1"
    options.MaskVersion (1,1) string = "quality_mask_full21_locked_v1"
    options.CaseID (1,1) string = "2026Feb27_homo_5perc_rswe"
    options.CaseDate (1,1) string = "2026-02-27"
    options.FrequencyHz (1,1) double = 500
    options.M (1,1) double = 2
    options.StepPixels (1,1) double = 3
    options.ExploratoryCutoffs (1,:) double = [.20 .24 .30 .40]
    options.SaveFigures (1,1) logical = true
    options.Visible (1,1) logical = false
end
assert(ismember(options.Mode,["plan","run"]) && ...
    all(isfinite(options.ExploratoryCutoffs)) && ...
    all(options.ExploratoryCutoffs>0 & options.ExploratoryCutoffs<=1) && ...
    numel(unique(options.ExploratoryCutoffs))==numel(options.ExploratoryCutoffs) && ...
    options.FrequencyHz>0 && isfinite(options.FrequencyHz) && ...
    options.M>0 && isfinite(options.M) && ...
    options.StepPixels>0 && ...
    options.StepPixels==fix(options.StepPixels), ...
    "AdaptiveREQ:CutoffOnlySettings","Invalid cutoff-only settings.");

clock=tic;
here=string(fileparts(mfilename("fullpath")));
caseRoot=fullfile(options.DataRoot,options.CaseDate,options.CaseID);
maskFile=fullfile(caseRoot,"analysis",options.StudyID, ...
    "M"+string(options.M)+"_step"+string(options.StepPixels), ...
    options.MaskVersion,"masks",options.ModelLabel, ...
    sprintf("%gHz",options.FrequencyHz),"risk_mask_result.mat");
outputRoot=fullfile(caseRoot,"analysis",options.StudyID, ...
    "cutoff_only_full21_exploratory_v1", ...
    "M"+string(options.M)+"_step"+string(options.StepPixels), ...
    sprintf("%gHz",options.FrequencyHz));
fprintf("\n[CUTOFF ONLY] %s | %g Hz | M=%g | step=%g\n", ...
    options.CaseID,options.FrequencyHz,options.M,options.StepPixels);
fprintf("[PLAN] Frozen unfiltered mask: %s\n",maskFile);
fprintf("[PLAN] Saved mask present: %d\n",isfile(maskFile));
fprintf("[PLAN] No filtered source or filter_manifest.mat needed.\n");
report=struct("status","planned","mask_file",maskFile, ...
    "output_root",outputRoot);
if options.Mode=="plan"
    fprintf("[PLAN] No files written (%.2f s).\n",toc(clock));
    return
end

assert(isfile(maskFile),"AdaptiveREQ:CutoffOnlyMissingMask", ...
    "Run stage 03 with step=%g before this diagnostic: %s", ...
    options.StepPixels,maskFile);
S=load(maskFile,"quality_result","mask_identity");
assert(isfield(S,"quality_result") && isfield(S,"mask_identity"), ...
    "AdaptiveREQ:CutoffOnlySchema","Saved stage-03 mask lacks provenance.");
I=jsondecode(char(S.mask_identity));
assert(isfield(I,"case_id") && string(I.case_id)==options.CaseID && ...
    double(I.frequency_hz)==options.FrequencyHz && ...
    double(I.M)==options.M && ...
    double(I.step_pixels)==options.StepPixels && ...
    string(I.mask_version)==options.MaskVersion && ...
    string(I.model_label)==options.ModelLabel, ...
    "AdaptiveREQ:CutoffOnlyIdentity", ...
    "Saved quality mask was generated for a different configuration.");
Q=S.quality_result;
fields=["original_sws_map","risk_score_map","original_valid_mask", ...
    "retained_mask","rejected_mask","unscored_mask", ...
    "cutoff","x_mm","z_mm","release_id"];
assert(all(isfield(Q,cellstr(fields))) && ...
    string(Q.release_id)=="adaptive_req_full21_v1", ...
    "AdaptiveREQ:CutoffOnlyMask","Not a published Full21 quality result.");
sws=double(Q.original_sws_map);
risk=double(Q.risk_score_map);
valid=logical(Q.original_valid_mask);
x=double(Q.x_mm(:)');
z=double(Q.z_mm(:));
tauFrozen=double(Q.cutoff);
assert(isequal(size(sws),size(risk),size(valid)) && ...
    isequal(size(sws),[numel(z),numel(x)]) && ...
    all(diff(x)>0) && all(diff(z)>0) && ...
    isfinite(tauFrozen) && tauFrozen>0 && tauFrozen<1 && ...
    all(isfinite(sws(valid))) && ...
    all(risk(isfinite(risk))>=0 & risk(isfinite(risk))<=1), ...
    "AdaptiveREQ:CutoffOnlyGrid","Invalid mask geometry or risk scores.");
scored=valid&isfinite(risk);
assert(isequal(logical(Q.retained_mask),scored&risk<=tauFrozen) && ...
    isequal(logical(Q.rejected_mask),scored&risk>tauFrozen) && ...
    isequal(logical(Q.unscored_mask),valid&~scored), ...
    "AdaptiveREQ:CutoffOnlyFrozen", ...
    "The stored frozen-mask labels disagree with its scores.");
if isfield(I,"mask_cutoff")
    assert(abs(double(I.mask_cutoff)-tauFrozen)<1e-12, ...
        "AdaptiveREQ:CutoffOnlyFrozen","Provenance cutoff differs from saved cutoff.");
end
addpath(here,"-begin");
C=adaptive_req_final_case_rois(options.CaseID);
cutoffs=unique([tauFrozen options.ExploratoryCutoffs],"sorted");
names=["full_fov",string({C.rois.name})];
within=cell(numel(names),1);
within{1}=true(size(valid));
for j=1:numel(C.rois)
    c=double(C.rois(j).center_mm(:));
    d=double(C.rois(j).size_mm(:));
    within{j+1}=(z>=c(2)-d(2)/2 & z<=c(2)+d(2)/2) & ...
        (x>=c(1)-d(1)/2 & x<=c(1)+d(1)/2);
end
rows=cell(numel(names)*numel(cutoffs),1);
idx=0;
for j=1:numel(names)
    base=valid&within{j};
    n=nnz(base);
    eligible=scored&within{j};
    original=sws(base);
    for k=1:numel(cutoffs)
        tau=cutoffs(k);
        keep=eligible&risk<=tau;
        reject=eligible&risk>tau;
        unscored=base&~scored;
        assert(nnz(keep)+nnz(reject)+nnz(unscored)==n, ...
            "AdaptiveREQ:CutoffOnlyPartition","Mask partition inconsistent.");
        selection=sws(keep);
        kind="exploratory_unvalidated";
        if abs(tau-tauFrozen)<1e-12,kind="frozen_VALIDATION";end
        idx=idx+1;
        rows{idx}=table(options.CaseID,options.FrequencyHz, ...
            options.M,options.StepPixels,names(j),tau,kind, ...
            n,nnz(eligible),nnz(keep),nnz(reject),nnz(unscored), ...
            proportion(nnz(keep),n),finiteMean(original), ...
            finiteMedian(original),finiteMean(selection), ...
            finiteMedian(selection),finiteStd(original), ...
            finiteStd(selection), ...
            'VariableNames',["case_id","frequency_hz","M", ...
            "step_pixels","roi","cutoff","cutoff_type", ...
            "original_valid","scored","retained","rejected","unscored", ...
            "retention_percent","sws_mean_original","sws_median_original", ...
            "sws_mean_retained","sws_median_retained", ...
            "sws_sd_original","sws_sd_retained"]);
    end
end
T=vertcat(rows{:});
stamp=string(datetime("now","Format","yyyyMMdd_HHmmss_SSS"));
out=fullfile(outputRoot,"reports",stamp);
assert(~isfolder(out),"AdaptiveREQ:CutoffOnlyReportExists", ...
    "Report already exists: %s",out);
mkdir(out);
csv=fullfile(out,"retention_vs_cutoff_by_roi.csv");
writetable(T,csv);
fprintf("[RESULT] Frozen cutoff %.6f | retained %.1f%% of original-valid FOV.\n", ...
    tauFrozen,proportion(nnz(Q.retained_mask),nnz(valid)));
disp(T(T.roi=="full_fov", ...
    ["cutoff","cutoff_type","retention_percent","sws_median_retained"]));

figures=strings(0,1);
if options.SaveFigures
    root=string(fileparts(fileparts(here)));
    assert(isfolder(fullfile(root,"src")),"AdaptiveREQ:CutoffOnlyViz", ...
        "SWSEval src missing.");
    addpath(fullfile(root,"src"),"-begin");
    colors=swseval.viz.mapColormap();
    vis="off";if options.Visible,vis="on";end
    nPanels=numel(cutoffs)+1;
    nCols=min(3,nPanels);
    nRows=ceil(nPanels/nCols);
    fig=figure("Visible",vis,"Color","w", ...
        "Position",[40 40 1150 350*nRows]);
    guard=onCleanup(@()close(fig)); %#ok<NASGU>
    layout=tiledlayout(fig,nRows,nCols, ...
        "Padding","compact","TileSpacing","compact");
    for k=1:nPanels
        ax=nexttile(layout,k);
        map=sws;
        map(~valid)=NaN;
        if k==1
            panelLabel="Original SWS";
        else
            tau=cutoffs(k-1);
            keep=scored&risk<=tau;
            map(~keep)=NaN;
            panelLabel=sprintf("Cutoff %.3f",tau);
            if abs(tau-tauFrozen)<1e-12
                panelLabel=panelLabel+" (frozen)";
            else
                panelLabel=panelLabel+" (exploratory)";
            end
        end
        imagesc(ax,x,z,map,"AlphaData",double(isfinite(map)));
        set(ax,"YDir","normal","Color","w","TickDir","out");
        axis(ax,"image");
        colormap(ax,colors);clim(ax,[1.5 3.5]);
        xlabel(ax,"x (mm)");ylabel(ax,"z (mm)");
        xtickformat(ax,"%.1f");ytickformat(ax,"%.1f");
        hold(ax,"on");
        for roi=C.rois
            c=double(roi.center_mm(:));
            d=double(roi.size_mm(:));
            rectangle(ax,"Position", ...
                [c(1)-d(1)/2,c(2)-d(2)/2,d(1),d(2)], ...
                "EdgeColor","k","LineStyle","--","LineWidth",1.2);
        end
        title(ax,panelLabel,"FontWeight","normal");
    end
    cb=colorbar(ax);cb.Layout.Tile="east";
    cb.Ticks=1.5:.5:3.5;
    cb.Ruler.TickLabelFormat="%.1f";
    cb.Label.String="SWS (m/s)";
    f=fullfile(out,"sws_cutoff_sweep.png");
    exportgraphics(fig,f,"Resolution",250);
    figures(end+1,1)=f;
    clear guard

    fig=figure("Visible",vis,"Color","w", ...
        "Position",[70 70 1040 460]);
    guard=onCleanup(@()close(fig)); %#ok<NASGU>
    L=tiledlayout(fig,1,2, ...
        "Padding","compact","TileSpacing","compact");
    a=nexttile(L);
    histogram(a,risk(scored),40);
    xline(a,tauFrozen,"r--","Frozen",LineWidth=1.5);
    xlabel(a,"Risk score (not calibrated)");ylabel(a,"Patch count");
    b=nexttile(L);hold(b,"on");
    t=unique([linspace(0,1,101),tauFrozen]);
    for j=1:numel(names)
        base=valid&within{j};
        y=nan(size(t));
        if any(base(:))
            for k=1:numel(t)
                y(k)=proportion(nnz(base&scored&risk<=t(k)),nnz(base));
            end
        end
        plot(b,t,y,"LineWidth",1.5, ...
            "DisplayName",names(j));
    end
    xline(b,tauFrozen,"k--","Frozen",HandleVisibility="off");
    xlim(b,[0 1]);ylim(b,[0 100]);
    xlabel(b,"Hypothetical cutoff (exploratory)");
    ylabel(b,"Retained original-valid patches (%)");
    grid(b,"on");legend(b,"Location","best","Interpreter","none");
    f=fullfile(out,"risk_scores_and_retention.png");
    exportgraphics(fig,f,"Resolution",250);
    figures(end+1,1)=f;
    clear guard
end
report=struct("status","completed", ...
    "source_mask",maskFile,"report_dir",out, ...
    "frozen_cutoff",tauFrozen,"cutoffs",cutoffs, ...
    "summary_file",csv,"figures",figures);
fprintf("[DONE] %s (%.2f s)\n",csv,toc(clock));
fprintf("[CAUTION] Other cutoffs are exploratory; apparent SWS changes are selection, not accuracy.\n");
end

function p=proportion(n,d)
p=NaN;if d>0,p=100*double(n)/double(d);end
end
function v=finiteMean(x)
v=NaN;if ~isempty(x),v=mean(x);end
end
function v=finiteMedian(x)
v=NaN;if ~isempty(x),v=median(x);end
end
function v=finiteStd(x)
v=NaN;if numel(x)>1,v=std(x,0);end
end
