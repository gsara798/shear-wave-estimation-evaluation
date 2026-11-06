function report=run_qmv2_experimental_risk_mask(options)
%RUN_QMV2_EXPERIMENTAL_RISK_MASK Frozen QMV2 risk-mask transfer.
% Modes: plan (read-only), run (score existing REQ-ML windows),
% analyze (ROI coverage and descriptive SWS), plot (original/mask/masked).
% All case IDs, mask paths, cutoffs, ROIs and plotting limits are JSON-driven.
% No truth, refitting, threshold adaptation or original SWS modifications.
arguments
    options.ManifestFile (1,1) string
    options.Mode (1,1) string ...
        {mustBeMember(options.Mode,["plan","run","analyze","plot"])} = "plan"
    options.CaseIDs (1,:) string = strings(1,0)
    options.Arms (1,:) string = strings(1,0)
    options.FrequenciesHz (1,:) double = []
    options.ConfirmFullRun (1,1) logical = false
    options.Verbose (1,1) logical = true
end
C=read_qmv2_experiment_manifest(options.ManifestFile);
assert(isfield(C,"mask_transfer") && isscalar(C.mask_transfer), ...
    "ExpQMV2:MaskTransferConfig", ...
    "Add mask_transfer to the experiment manifest JSON.");
settings=C.mask_transfer;
required=["analysis_version","mask_feature_set", ...
    "include_frequency","risk_error_threshold","target_retention","arms"];
assert(all(isfield(settings,cellstr(required))) && ...
    isstruct(settings.arms) && ~isempty(settings.arms), ...
    "ExpQMV2:MaskTransferConfig","Invalid mask_transfer JSON fields.");
analysisID=string(settings.analysis_version);
assert(strlength(analysisID)>0 && ...
    all(isstrprop(char(analysisID),"alphanum") | ...
    ismember(char(analysisID),['_','-'])), ...
    "ExpQMV2:MaskAnalysisID","Unsafe analysis_version directory name.");
entries=settings.arms;
assert(all(isfield(entries,{"arm","mask_file"})), ...
    "ExpQMV2:MaskEntry","Each mask entry needs arm and mask_file.");
configured=string({entries.arm});
assert(numel(unique(configured))==numel(configured) && ...
    all(startsWith(configured,"qmv2_")), ...
    "ExpQMV2:MaskArms","Each mask arm must identify a unique QMV2 q model.");
selected=options.Arms;
if isempty(selected),selected=configured;end
assert(~isempty(selected) && numel(unique(selected))==numel(selected) && ...
    all(ismember(selected,configured)), ...
    "ExpQMV2:MaskArmSelection", ...
    "Selected arms must be listed in mask_transfer.arms.");
cases=options.CaseIDs;
if isempty(cases),cases=string({C.cases.id});end
[jobs,models]=qmv2_experimental_plan(C,cases,selected);
assert(all(models.model_present),"ExpQMV2:MaskQuantileMissing", ...
    "Quantile bundle unavailable. Check REQ-ML export.");
if ~isempty(options.FrequenciesHz)
    assert(all(isfinite(options.FrequenciesHz)) && ...
        all(options.FrequenciesHz>0) && ...
        numel(unique(options.FrequenciesHz))==numel(options.FrequenciesHz), ...
        "ExpQMV2:MaskFrequencies","Frequencies must be positive and distinct.");
    jobs=jobs(ismember(jobs.frequency_hz,options.FrequenciesHz),:);
end
assert(height(jobs)>0 && all(isfinite(jobs.frequency_hz)), ...
    "ExpQMV2:MaskNoJobs","No available jobs for this case/frequency selection.");
paths=strings(height(models),1);
for ai=1:height(models)
    entry=entries(configured==models.arm(ai));
    path=string(entry.mask_file);
    if ~isAbsolutePath(path)
        path=fullfile(C.reqml_root,path);
    end
    paths(ai)=path;
end
models.mask_file=paths;
models.mask_present=isfile(paths);
jobs.estimate_present=false(height(jobs),1);
for ji=1:height(jobs)
    for ai=1:height(models)
        file=estimateFile(C,jobs(ji,:),models.arm(ai));
        if ~isfile(file)
            jobs.estimate_present(ji)=false;
            break
        end
        jobs.estimate_present(ji)=true;
    end
end
report=struct("status","planned","jobs",jobs, ...
    "models",models,"analysis_version",analysisID, ...
    "selected_cases",cases,"selected_arms",selected, ...
    "output_root",fullfile(C.data_root,"analysis",C.study_id, ...
        "M"+string(C.m)+"_step"+string(C.step_pixels),analysisID));
if options.Mode=="plan"
    fprintf("Frozen experimental masks: %d case/frequency jobs, %d arms.\n", ...
        height(jobs),height(models));
    disp(models(:,["arm","mask_present","mask_file"]));
    disp(jobs(:,["case_id","frequency_hz","raw_exists","estimate_present"]));
    return
end
assert(all(models.mask_present) && all(jobs.estimate_present), ...
    "ExpQMV2:MaskInputsMissing", ...
    "Mask bundles or existing SWS estimates missing. Run Mode=plan.");
if options.Mode=="run"
    if height(jobs)*height(models)>8
        assert(options.ConfirmFullRun,"ExpQMV2:MaskRunConfirm", ...
            "Set ConfirmFullRun=true for more than eight mask mappings.");
    end
    newCount=0;reuseCount=0;
    for ai=1:height(models)
        maskFile=models.mask_file(ai);
        bundle=load(maskFile,"classifier","metadata");
        assert(isfield(bundle,"classifier") && isfield(bundle,"metadata"), ...
            "ExpQMV2:MaskBundle","Missing classifier/metadata in %s",maskFile);
        assertMaskConfig(bundle.metadata,settings,models.arm(ai));
        for ji=1:height(jobs)
            job=jobs(ji,:);
            estimate=estimateFile(C,job,models.arm(ai));
            target=maskFileForJob(C,analysisID,job,models.arm(ai));
            fingerprint=makeIdentity(estimate,maskFile, ...
                models.arm(ai),C,analysisID);
            if isfile(target)
                prior=load(target,"mask_identity");
                assert(isfield(prior,"mask_identity") && ...
                    string(prior.mask_identity)==fingerprint, ...
                    "ExpQMV2:MaskStale", ...
                    "Existing mask checkpoint has different inputs: %s",target);
                reuseCount=reuseCount+1;
                if options.Verbose
                    fprintf("Reused risk mask: %s %gHz / %s\n", ...
                        job.case_id,job.frequency_hz,models.arm(ai));
                end
                continue
            end
            saved=load(estimate,"result","comparison_identity");
            assert(isfield(saved,"result") && ...
                isfield(saved,"comparison_identity"), ...
                "ExpQMV2:MaskEstimateFormat", ...
                "Expected original immutable experimental result: %s",estimate);
            quality_result=qmv2_score_experimental_risk_mask( ...
                saved.result,bundle.classifier,bundle.metadata,models.arm(ai)); %#ok<NASGU>
            mask_identity=fingerprint; %#ok<NASGU>
            folder=string(fileparts(target));
            if ~isfolder(folder),mkdir(folder);end
            partial=target+".partial.mat";
            assert(~isfile(partial),"ExpQMV2:MaskPartial", ...
                "Inspect incomplete checkpoint before proceeding: %s",partial);
            save(partial,"quality_result","mask_identity","-v7.3");
            [ok,msg]=movefile(partial,target);
            assert(ok,"ExpQMV2:MaskWrite","%s",msg);
            newCount=newCount+1;
            if options.Verbose
                fprintf("Mask scored: %s %gHz / %s | retained %.1f%%, "+ ...
                    "rejected %d, unscored %d\n", ...
                    job.case_id,job.frequency_hz,models.arm(ai), ...
                    100*quality_result.coverage_on_original_valid, ...
                    quality_result.rejected_count,quality_result.unscored_count);
            end
        end
    end
    report.status="completed";
    report.new_maps=newCount;
    report.reused_maps=reuseCount;
    return
end
if options.Mode=="analyze"
    [T,contrasts,outputFiles]=analyzeMaskResults(C,settings, ...
        jobs,models,analysisID);
    report.status="analyzed";
    report.roi_summary=T;
    report.contrasts=contrasts;
    report.files=outputFiles;
    return
end
if options.Mode=="plot"
    report.files=plotRiskMasks(C,settings,jobs,models,analysisID);
    report.status="plotted";
    return
end
end

function yes=isAbsolutePath(path)
path=string(path);
yes=startsWith(path,"/") || startsWith(path,"\") || ...
    ~isempty(regexp(char(path),"^[A-Za-z]:[\\/]","once"));
end

function assertMaskConfig(meta,settings,arm)
assert(isfield(meta,"filter_arm") && ...
    isfield(meta,"quantile_predictor_set") && ...
    isfield(meta,"mask_feature_set") && ...
    isfield(meta,"include_frequency") && ...
    isfield(meta,"risk_error_threshold") && ...
    isfield(meta,"target_retention") && ...
    isfield(meta,"test_used") && ~logical(meta.test_used) && ...
    arm=="qmv2_"+string(meta.filter_arm)+"_"+ ...
        string(meta.quantile_predictor_set) && ...
    string(meta.mask_feature_set)==string(settings.mask_feature_set) && ...
    logical(meta.include_frequency)==logical(settings.include_frequency) && ...
    abs(double(meta.risk_error_threshold)- ...
        double(settings.risk_error_threshold))<1e-12 && ...
    abs(double(meta.target_retention)- ...
        double(settings.target_retention))<1e-12, ...
    "ExpQMV2:MaskConfigMismatch", ...
    "Mask %s does not match JSON configuration or TRAIN-only provenance.",arm);
end

function filename=estimateFile(C,job,arm)
filename=fullfile(job.dataset_root,"estimates",C.study_id, ...
    "REQ-ML",arm,sprintf("%gHz",job.frequency_hz), ...
    "M"+string(C.m),"step"+string(C.step_pixels), ...
    "reqml_result.mat");
end

function filename=maskFileForJob(C,version,job,arm)
filename=fullfile(job.dataset_root,"analysis",C.study_id, ...
    "M"+string(C.m)+"_step"+string(C.step_pixels), ...
    version,"masks",arm,sprintf("%gHz",job.frequency_hz), ...
    "risk_mask_result.mat");
end

function identity=makeIdentity(estimate,modelFile,arm,C,version)
a=dir(estimate);b=dir(modelFile);
identity=string(jsonencode(struct( ...
    "estimate",estimate,"estimate_bytes",double(a.bytes), ...
    "estimate_modified",double(a.datenum), ...
    "mask_file",modelFile,"mask_bytes",double(b.bytes), ...
    "mask_modified",double(b.datenum), ...
    "arm",arm,"M",double(C.m), ...
    "step_pixels",double(C.step_pixels), ...
    "analysis_version",version)));
end

function [rows,contrasts,files]=analyzeMaskResults(C,settings,jobs,models,version)
results=cell(0,1);
contrastParts=cell(0,1);
files=strings(0,1);
for ji=1:height(jobs)
    job=jobs(ji,:);
    caseInfo=C.cases(string({C.cases.id})==job.case_id);
    if isfield(caseInfo,"rois") && ~isempty(caseInfo.rois)
        rois=caseInfo.rois;
    else
        rois=struct("name","whole_FOV_unsegmented", ...
            "center_mm",[],"size_mm",[]);
    end
    perJob=cell(0,1);
    for ai=1:height(models)
        arm=models.arm(ai);
        file=maskFileForJob(C,version,job,arm);
        assert(isfile(file),"ExpQMV2:MaskMissing", ...
            "Run Mode=run before analyzing: %s",file);
        saved=load(file,"quality_result");
        assert(isfield(saved,"quality_result"), ...
            "ExpQMV2:MaskFormat","Missing risk map in %s.",file);
        Q=saved.quality_result;
        for ri=1:numel(rois)
            roi=rois(ri);
            r=spatialROI(Q,roi);
            valid=r & logical(Q.original_valid_mask);
            kept=r & logical(Q.retained_mask);
            rejected=r & logical(Q.rejected_mask);
            unscored=r & logical(Q.unscored_mask);
            n=nnz(valid);nk=nnz(kept);
            before=double(Q.original_sws_map(valid));
            after=double(Q.masked_sws_map(kept));
            meanBefore=NaN;medianBefore=NaN;cvBefore=NaN;
            meanAfter=NaN;medianAfter=NaN;cvAfter=NaN;
            if ~isempty(before)
                meanBefore=mean(before);medianBefore=median(before);
                cvBefore=100*std(before)/meanBefore;
            end
            if ~isempty(after)
                meanAfter=mean(after);medianAfter=median(after);
                cvAfter=100*std(after)/meanAfter;
            end
            frac=NaN;
            if n>0,frac=nk/n;end
            row=table(job.case_id,job.modality,job.phantom_type, ...
                job.frequency_hz,arm,string(roi.name), ...
                nnz(r),n,nk,nnz(rejected),nnz(unscored),frac, ...
                double(Q.cutoff),meanBefore,medianBefore,cvBefore, ...
                meanAfter,medianAfter,cvAfter, ...
                'VariableNames',["case_id","modality","phantom_type", ...
                "frequency_hz","arm","roi","roi_total_pixels", ...
                "original_valid_pixels","retained_pixels","rejected_pixels", ...
                "unscored_pixels","retained_fraction", ...
                "frozen_risk_cutoff","mean_sws_before", ...
                "median_sws_before","cv_percent_before", ...
                "mean_sws_after","median_sws_after","cv_percent_after"]);
            perJob{end+1,1}=row; %#ok<AGROW>
            results{end+1,1}=row; %#ok<AGROW>
        end
    end
    if isfield(caseInfo,"contrasts") && ~isempty(caseInfo.contrasts)
        tab=vertcat(perJob{:});
        for p=1:numel(caseInfo.contrasts)
            rule=caseInfo.contrasts(p);
            for arm=models.arm'
                a=tab(tab.arm==arm & tab.roi==string(rule.target_roi),:);
                b=tab(tab.arm==arm & tab.roi==string(rule.reference_roi),:);
                assert(height(a)==1 && height(b)==1, ...
                    "ExpQMV2:MaskContrastROI", ...
                    "Inclusion/background ROI pair missing.");
                contrastBefore=NaN;contrastAfter=NaN;
                if isfinite(b.median_sws_before) && b.median_sws_before>0
                    contrastBefore=100*(a.median_sws_before/b.median_sws_before-1);
                end
                if isfinite(b.median_sws_after) && b.median_sws_after>0
                    contrastAfter=100*(a.median_sws_after/b.median_sws_after-1);
                end
                contrastParts{end+1,1}=table( ...
                    job.case_id,job.modality,job.frequency_hz,arm, ...
                    string(rule.name),string(rule.target_roi), ...
                    string(rule.reference_roi),a.retained_fraction, ...
                    b.retained_fraction,contrastBefore,contrastAfter, ...
                    'VariableNames',["case_id","modality","frequency_hz", ...
                    "arm","contrast_name","target_roi","reference_roi", ...
                    "target_retained_fraction","background_retained_fraction", ...
                    "contrast_before_percent","contrast_after_percent"]); %#ok<AGROW>
            end
        end
    end
end
rows=vertcat(results{:});
contrasts=table();
if ~isempty(contrastParts),contrasts=vertcat(contrastParts{:});end
folder=fullfile(C.data_root,"analysis",C.study_id, ...
    "M"+string(C.m)+"_step"+string(C.step_pixels),version);
if ~isfolder(folder),mkdir(folder);end
% A subset and the full cohort are different reports: fingerprint scope.
identity=string(jsonencode(struct( ...
    "case_ids",unique(string(jobs.case_id),"stable")', ...
    "frequencies",unique(double(jobs.frequency_hz),"stable")', ...
    "arms",string(models.arm(:))', ...
    "version",version,"settings",settings)));
sigFile=fullfile(folder,"mask_roi_analysis_identity.mat");
if isfile(sigFile)
    prev=load(sigFile,"identity");
    assert(isfield(prev,"identity") && string(prev.identity)==identity, ...
        "ExpQMV2:MaskAnalysisScope", ...
        "Previous combined ROI analysis used a different case/arm scope. "+ ...
        "Use a distinct mask_transfer.analysis_version.");
else
    save(sigFile,"identity");
end
summaryFile=fullfile(folder,"quality_mask_experimental_roi_summary.csv");
writetable(rows,summaryFile);
files(end+1,1)=summaryFile;
if ~isempty(contrasts)
    file=fullfile(folder,"quality_mask_inclusion_contrasts.csv");
    writetable(contrasts,file);
    files(end+1,1)=file;
end
end

function selected=spatialROI(Q,roi)
if isempty(roi.center_mm)
    selected=true(size(Q.original_valid_mask));
    return
end
x=double(Q.x_mm(:))';
z=double(Q.z_mm(:));
p=double(roi.center_mm(:));
w=double(roi.size_mm(:));
selected=(z>=p(2)-w(2)/2 & z<=p(2)+w(2)/2) & ...
    (x>=p(1)-w(1)/2 & x<=p(1)+w(1)/2);
assert(isequal(size(selected),size(Q.original_valid_mask)), ...
    "ExpQMV2:MaskROIGeometry", ...
    "ROI mask is not aligned with saved SWS grid.");
end

function files=plotRiskMasks(C,settings,jobs,models,version)
files=strings(0,1);
for ji=1:height(jobs)
    job=jobs(ji,:);
    caseInfo=C.cases(string({C.cases.id})==job.case_id);
    for ai=1:height(models)
        arm=models.arm(ai);
        saved=load(maskFileForJob(C,version,job,arm),"quality_result");
        Q=saved.quality_result;
        fig=figure("Visible","off","Color","w", ...
            "Position",[50 50 1480 510]);
        lay=tiledlayout(fig,1,3,"TileSpacing","compact", ...
            "Padding","compact");
        ax=nexttile(lay);
        imagesc(ax,Q.x_mm,Q.z_mm,Q.original_sws_map);
        set(ax,"YDir","normal");axis(ax,"image");
        clim(ax,C.sws_limits);colormap(ax,"turbo");colorbar(ax);
        title(ax,"Original SWS (m/s)");
        bx=nexttile(lay);
        imagesc(bx,Q.x_mm,Q.z_mm,Q.risk_score_map);
        set(bx,"YDir","normal");axis(bx,"image");
        clim(bx,[0 1]);colormap(bx,"parula");colorbar(bx);
        title(bx,"Risk score (not calibrated)");
        cx=nexttile(lay);
        imagesc(cx,Q.x_mm,Q.z_mm,Q.masked_sws_map);
        set(cx,"YDir","normal");axis(cx,"image");
        clim(cx,C.sws_limits);colormap(cx,"turbo");colorbar(cx);
        title(cx,sprintf("Retained %.1f%% of valid", ...
            100*Q.coverage_on_original_valid));
        for a=[ax bx cx]
            xlabel(a,"x (mm)");ylabel(a,"z (mm)");
            if isfield(caseInfo,"rois") && ~isempty(caseInfo.rois)
                hold(a,"on");
                for ri=1:numel(caseInfo.rois)
                    roi=caseInfo.rois(ri);
                    p=double(roi.center_mm(:));
                    w=double(roi.size_mm(:));
                    rectangle(a,"Position",[p(1)-w(1)/2, ...
                        p(2)-w(2)/2,w(1),w(2)], ...
                        "LineStyle","--","LineWidth",1.0, ...
                        "EdgeColor","white");
                end
            end
        end
        title(lay,job.case_id+" | "+arm+" | "+ ...
            string(job.frequency_hz)+"Hz | TRAIN-OOF cutoff "+ ...
            string(Q.cutoff),"Interpreter","none");
        folder=fullfile(job.dataset_root,"analysis",C.study_id, ...
            "M"+string(C.m)+"_step"+string(C.step_pixels), ...
            version,"comparison_figures");
        if ~isfolder(folder),mkdir(folder);end
        path=fullfile(folder,"mask_"+arm+"_"+ ...
            string(job.frequency_hz)+"Hz.png");
        exportgraphics(fig,path,Resolution=170);
        close(fig);
        files(end+1,1)=path; %#ok<AGROW>
        if isfield(settings,"analysis_version") %#ok<*ISFLD>
            % settings is kept for provenance; never adapt cutoff here.
        end
    end
end
end
