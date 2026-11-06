function out=run_qmv2_experimental_study(options)
%RUN_QMV2_EXPERIMENTAL_STUDY Config-driven SP/RSWE/QMV2 evaluation.
% Stage plan: pure preflight; process: EWP IQ->raw field; estimate: frozen
% models on raw or canonical donut; analyze: common-valid physical ROI
% descriptive statistics; plot: versioned maps & frequency comparisons.
% No model training and no estimates/ROI locations hard-coded by dataset.
arguments
    options.ManifestFile (1,1) string
    options.Stage (1,1) string {mustBeMember(options.Stage, ...
        ["plan","process","estimate","analyze","plot"])} = "plan"
    options.CaseIDs (1,:) string = strings(1,0)
    options.Arms (1,:) string = strings(1,0)
    options.UseParallel (1,1) logical = false
    options.ConfirmFullRun (1,1) logical = false
    options.Verbose (1,1) logical = true
end
C=read_qmv2_experiment_manifest(options.ManifestFile);
cases=options.CaseIDs;
if isempty(cases),cases=string({C.cases.id});end
arms=options.Arms;
if isempty(arms),arms=C.arms;end
[jobs,models]=qmv2_experimental_plan(C,cases,arms);
fprintf("Experimental QMV2: %d datasets, %d observation jobs, %d arms; stage=%s.\n", ...
    numel(cases),height(jobs),height(models),options.Stage);
if options.Stage=="plan"
    disp(models);
    disp(jobs(:,["case_id","modality","phantom_type", ...
        "frequency_hz","raw_run","raw_exists","donut_exists", ...
        "rois_defined","run_candidates"]));
    out=struct("stage","plan","jobs",jobs,"models",models, ...
        "selected_cases",cases,"selected_arms",arms);
    return
end
if options.Stage=="process"
    ensurePaths(C,true);
    for id=cases
        spec=caseByID(C,id);
        r=jobs(jobs.case_id==id,:);
        assert(~isempty(r) && all(isfinite(r.frequency_hz)) && ...
            numel(unique(r.frequency_hz))>0, ...
            "ExpQMV2:NoFrequencies", ...
            "Cannot discover frequencies for %s. Set frequencies_hz in manifest.",id);
        runName=string(spec.raw_run);
        assert(runName~="" && runName~="auto", ...
            "ExpQMV2:RawRun", ...
            "Set a unique raw_run name for IQ processing of %s.",id);
        pattern=string(spec.raw_file_pattern);
        assert(pattern~="" && contains(pattern,"{frequency}"), ...
            "ExpQMV2:RawPattern", ...
            "Set raw_file_pattern in manifest after checking actual IQ filenames for %s.",id);
        root=fullfile(C.data_root,string(spec.relative_path));
        assert(isfolder(fullfile(root,"raw")), ...
            "ExpQMV2:MissingIQ","IQ acquisition folder missing: %s",root);
        svdModes=0;
        if isfield(spec,"remove_svd_modes")
            svdModes=double(spec.remove_svd_modes);
        end
        isotropic=true;
        if isfield(spec,"make_isotropic")
            isotropic=logical(spec.make_isotropic);
        end
        fprintf("EWP %s (%s), %d frequencies, %d SVD modes removed.\n", ...
            id,string(spec.modality),numel(r.frequency_hz),svdModes);
        ewp.runFrequencySweep( ...
            InputRoot=fullfile(root,"raw"), ...
            FilePattern=pattern, ...
            Frequencies=unique(double(r.frequency_hz))', ...
            RunName=runName, ...
            SpatialFilterMode="none",DonutEnabled=false, ...
            RemoveSVDModes=svdModes,MakeIsotropic=isotropic, ...
            SaveFigures=false,SaveMovies=false, ...
            UseParallel=options.UseParallel,Resume=true);
    end
    out=struct("stage","process","status","finished", ...
        "next_stage","plan");
    return
end
assert(all(models.model_present),"ExpQMV2:ModelsMissing", ...
    "Some deployable model bundles are missing. Run Stage=plan and export from REQ-ML first.");
assert(all(isfinite(jobs.frequency_hz)) && ...
    all(jobs.raw_run~="") && all(jobs.raw_exists), ...
    "ExpQMV2:RawMissing", ...
    "Some frequency/run or raw wavefield inputs are missing. Run Stage=plan; process IQ only if necessary.");
ensurePaths(C,false);
if options.Stage=="estimate"
    if height(jobs)*height(models)>8
        assert(options.ConfirmFullRun,"ExpQMV2:RunConfirmation", ...
            "Set ConfirmFullRun=true for more than eight predictions.");
    end
    loaded=cell(height(models),1);
    for i=1:height(models)
        loaded{i}=reqml.models.loadQ0Model(Model=models.bundle_file(i));
        meta=loaded{i}.model_metadata;
        arm=models.arm(i);
        if startsWith(arm,"qmv2_")
            expected="unfiltered";
            if startsWith(arm,"qmv2_fixed_donut_"),expected="fixed_donut";end
            assert(isfield(meta,"filter_arm") && ...
                string(meta.filter_arm)==expected && ...
                isfield(meta,"test_partition_excluded") && ...
                logical(meta.test_partition_excluded), ...
                "ExpQMV2:Provenance", ...
                "Missing TEST-safe QMV2 source or filter identity: %s",arm);
        end
    end
    total=height(jobs)*height(models);
    done=0;reused=0;
    for ji=1:height(jobs)
        j=jobs(ji,:);
        needDonut=any(models.input_kind=="donut");
        if needDonut
            status=qmv2_prepare_filtered_sample(j.raw_sample, ...
                j.donut_sample,C.filter);
            if options.Verbose
                fprintf("[%s %gHz] donut: %s\n",j.case_id, ...
                    j.frequency_hz,status);
            end
        end
        for ai=1:height(models)
            model=models(ai,:);
            sample=j.raw_sample;
            if model.input_kind=="donut",sample=j.donut_sample;end
            dest=estimateFile(C,j,model.arm);
            resultStatus=predictOne(sample,model.bundle_file, ...
                loaded{ai},dest,j,C,options.UseParallel);
            done=done+1;reused=reused+double(resultStatus=="reused");
            if options.Verbose
                fprintf("QMV2 experimental %d/%d | %s %gHz | %s: %s\n", ...
                    done,total,j.case_id,j.frequency_hz, ...
                    model.arm,resultStatus);
            end
        end
    end
    out=struct("stage","estimate","status","finished", ...
        "completed",done,"reused",reused,"jobs",jobs,"models",models);
    return
end
if options.Stage=="analyze"
    [tableRows,files,contrastRows]=analyzeJobs(C,jobs,models);
    out=struct("stage","analyze","summary",tableRows, ...
        "contrasts",contrastRows,"files",files, ...
        "jobs",jobs,"models",models);
    return
end
if options.Stage=="plot"
    files=qmv2_plot_experimental_study(C,jobs,models);
    out=struct("stage","plot","files",files, ...
        "jobs",jobs,"models",models);
    return
end
end

function ensurePaths(C,needEwp)
repo=string(fileparts(fileparts(mfilename("fullpath"))));
evalRoot=fileparts(repo);
src=fullfile(evalRoot,"src");
reqmlSrc=fullfile(C.reqml_root,"src");
q0v5=fullfile(C.reqml_root,"training","q0_v5_clean_campaign");
assert(isfolder(src) && isfolder(reqmlSrc) && isfolder(q0v5), ...
    "ExpQMV2:CodeRoots","Source repos not found. Inspect manifest reqml_root.");
addpath(src,"-begin");
addpath(reqmlSrc,"-begin");
addpath(q0v5,"-begin");
if needEwp
    assert(isfield(C,"ewp_root"),"ExpQMV2:EWPRoot", ...
        "Set ewp_root in manifest to process IQ data.");
    ewpSrc=fullfile(string(C.ewp_root),"src");
    assert(isfolder(ewpSrc),"ExpQMV2:EWPRoot", ...
        "Expected experimental-wavefield-processing/src under ewp_root.");
    addpath(ewpSrc,"-begin");
    assert(~isempty(which("ewp.runFrequencySweep")), ...
        "ExpQMV2:EWPUnavailable","EWP package unavailable.");
else
    assert(~isempty(which("reqml.predictSWS")) && ...
        ~isempty(which("swseval.io.loadReqmlResult")), ...
        "ExpQMV2:CodeMissing","REQ-ML or swseval source missing.");
end
end

function spec=caseByID(C,id)
ids=string({C.cases.id});
index=find(ids==id);
assert(isscalar(index),"ExpQMV2:UnknownCase","Unknown dataset ID: %s",id);
spec=C.cases(index);
end

function dest=estimateFile(C,j,arm)
dest=fullfile(j.dataset_root, "estimates",C.study_id,"REQ-ML", ...
    arm,sprintf("%gHz",j.frequency_hz), ...
    "M"+string(C.m),"step"+string(C.step_pixels), ...
    "reqml_result.mat");
end

function status=predictOne(sample,modelFile,loaded,dest,j,C,parallel)
src=dir(sample);mdl=dir(modelFile);
identity=struct("source",sample,"source_bytes",double(src.bytes), ...
    "source_datenum",double(src.datenum), ...
    "model_file",modelFile,"model_bytes",double(mdl.bytes), ...
    "model_datenum",double(mdl.datenum), ...
    "case_id",j.case_id,"frequency_hz",j.frequency_hz, ...
    "M",C.m,"step_pixels",C.step_pixels);
comparison_identity=string(jsonencode(identity)); %#ok<NASGU>
if isfile(dest)
    saved=load(dest,"comparison_identity");
    assert(isfield(saved,"comparison_identity") && ...
        string(saved.comparison_identity)==comparison_identity, ...
        "ExpQMV2:EstimateStale", ...
        "Existing estimate differs in model/input/config: %s",dest);
    status="reused";return
end
folder=string(fileparts(dest));
if ~isfolder(folder),mkdir(folder);end
tmp=dest+".partial.mat";
assert(~isfile(tmp),"ExpQMV2:EstimatePartial", ...
    "Inspect interrupted output: %s",tmp);
result=reqml.predictSWS(sample,ModelBundle=loaded, ...
    M=C.m,StepPixels=C.step_pixels, ...
    UseParallel=parallel,Verbose=false); %#ok<NASGU>
result.metadata.experimental_qmv2_case=j.case_id;
result.metadata.experimental_qmv2_study=C.study_id;
save(tmp,"result","comparison_identity","-v7.3");
[ok,msg]=movefile(tmp,dest);
assert(ok,"ExpQMV2:EstimateWrite","%s",msg);
status="created";
end

function [T,files,contrasts]=analyzeJobs(C,jobs,models)
rows=cell(0,1);
files=strings(0,1);
contrasts=table();
for ji=1:height(jobs)
    j=jobs(ji,:);
    caseSpec=caseByID(C,j.case_id);
    maps=cell(height(models),1);
    for ai=1:height(models)
        file=estimateFile(C,j,models.arm(ai));
        assert(isfile(file),"ExpQMV2:EstimateMissing", ...
            "Run Stage=estimate first: %s",file);
        maps{ai}=swseval.io.loadReqmlResult(file);
    end
    ref=maps{1};
    common=logical(ref.valid_mask);
    for ai=2:height(models)
        q=maps{ai};
        assert(isequal(size(ref.cs_map),size(q.cs_map)) && ...
            isequal(double(ref.x_mm),double(q.x_mm)) && ...
            isequal(double(ref.z_mm),double(q.z_mm)), ...
            "ExpQMV2:UnpairedGrids", ...
            "Mismatch in %s at %g Hz.",j.case_id,j.frequency_hz);
        common=common & q.valid_mask;
    end
    hasROIs=isfield(caseSpec,"rois") && ~isempty(caseSpec.rois);
    if hasROIs, roiDefs=caseSpec.rois;
    else,roiDefs=struct("name","whole_FOV_unsegmented", ...
            "center_mm",[NaN NaN],"size_mm",[NaN NaN]);
    end
    for ri=1:numel(roiDefs)
        def=roiDefs(ri);
        roiName=string(def.name);
        roiFovFraction=1;
        if hasROIs
            x=double(ref.x_mm(:)');
            z=double(ref.z_mm(:));
            center=double(def.center_mm(:)');
            width=double(def.size_mm(:)');
            selected=(z>=center(2)-width(2)/2 & ...
                z<=center(2)+width(2)/2) & ...
                (x>=center(1)-width(1)/2 & ...
                x<=center(1)+width(1)/2);
            % Geometric fraction covered by the SWS map-center grid.
            % This is a conservative FOV diagnostic, not a pixel-fraction
            % estimator and not an ultrasound B-mode segmentation.
            overlapX=max(0,min(max(x),center(1)+width(1)/2)- ...
                max(min(x),center(1)-width(1)/2));
            overlapZ=max(0,min(max(z),center(2)+width(2)/2)- ...
                max(min(z),center(2)-width(2)/2));
            roiFovFraction=(overlapX/width(1))*(overlapZ/width(2));
            if roiFovFraction<0.90
                warning("ExpQMV2:ROIPartialFOV", ...
                    "ROI %s in %s at %g Hz covers only %.0f%% of "+ ...
                    "its physical extent on the SWS-map grid.", ...
                    roiName,j.case_id,j.frequency_hz,100*roiFovFraction);
            end
        else
            selected=true(size(common));
        end
        support=selected & common;
        nSelected=nnz(selected);nCommon=nnz(support);
        if nSelected==0 || nCommon==0
            warning("ExpQMV2:ROIEmpty", ...
                "No ROI/support in %s, %g Hz, %s.", ...
                j.case_id,j.frequency_hz,roiName);
        end
        referenceSpeed=NaN;
        if hasROIs && isfield(def,"reference_sws_m_s") && ...
                ~isempty(def.reference_sws_m_s)
            referenceSpeed=double(def.reference_sws_m_s);
            assert(isscalar(referenceSpeed) && isfinite(referenceSpeed) ...
                && referenceSpeed>0,"ExpQMV2:Reference", ...
                "Reference speed must be a known positive value.");
        end
        for ai=1:height(models)
            y=double(maps{ai}.cs_map(support));
            q=double(maps{ai}.q_map(support));
            meanSWS=NaN;medianSWS=NaN;stdSWS=NaN;cv=NaN; ...
                biasPercent=NaN;mape=NaN;medianQ=NaN;
            if ~isempty(y) && all(isfinite(y))
                meanSWS=mean(y);
                medianSWS=median(y);
                stdSWS=std(y);
                cv=100*stdSWS/meanSWS;
                if isfinite(referenceSpeed)
                    biasPercent=100*(meanSWS-referenceSpeed)/referenceSpeed;
                    mape=100*mean(abs(y-referenceSpeed))/referenceSpeed;
                end
            end
            q=q(isfinite(q));
            if ~isempty(q),medianQ=median(q);end
            rows{end+1,1}=table(j.case_id,j.modality, ...
                j.phantom_type,j.frequency_hz,models.arm(ai),roiName, ...
                hasROIs,referenceSpeed,nSelected,nCommon, ...
                nCommon/max(nSelected,1),roiFovFraction, ...
                meanSWS,medianSWS,stdSWS,cv,medianQ, ...
                biasPercent,mape, ...
                'VariableNames',["case_id","modality","phantom_type", ...
                "frequency_hz","model","roi","roi_configured", ...
                "reference_sws_m_s","selected_pixels", ...
                "common_valid_pixels","common_valid_fraction", ...
                "roi_extent_in_sample_fraction", ...
                "mean_sws_m_s","median_sws_m_s","spatial_sd_m_s", ...
                "cv_percent","median_q","bias_percent","mape_percent"]); %#ok<AGROW>
        end
    end
end
assert(~isempty(rows),"ExpQMV2:NoRows","No analysis rows.");
T=vertcat(rows{:});
for id=unique(string(T.case_id))'
    subset=T(T.case_id==id,:);
    spec=caseByID(C,id);
    folder=fullfile(C.data_root, ...
        string(spec.relative_path), ...
        "analysis",C.study_id, ...
        "M"+string(C.m)+"_step"+string(C.step_pixels), ...
        C.analysis_version);
    if ~isfolder(folder),mkdir(folder);end
    signature=string(jsonencode(struct( ...
        "roi_config",getROIConfig(spec), ...
        "contrasts",getContrastConfig(spec), ...
        "M",C.m,"step_pixels",C.step_pixels, ...
        "arms",string(models.arm(:))', ...
        "frequency_hz",unique(double(subset.frequency_hz))')));
    sigFile=fullfile(folder,"roi_analysis_identity.mat");
    if isfile(sigFile)
        previous=load(sigFile,"signature");
        assert(isfield(previous,"signature") && ...
            string(previous.signature)==signature, ...
            "ExpQMV2:ROIVersionConflict", ...
            "ROI/model selection changed. Bump analysis_version in JSON; preserving %s",folder);
    else
        save(sigFile,"signature");
    end
    filename=fullfile(folder,"qmv2_experimental_roi_summary.csv");
    writetable(subset,filename);
    files(end+1,1)=filename; %#ok<AGROW>
    fprintf("Experimental ROI results %s -> %s\n",id,filename);
    % Quantify ROI contrasts without processing IQ or predicting SWS.
    if isfield(spec,"contrasts") && ~isempty(spec.contrasts)
        localContrasts=qmv2_inclusion_contrasts(subset,spec.contrasts);
        if isempty(contrasts)
            contrasts=localContrasts;
        else
            contrasts=[contrasts;localContrasts]; %#ok<AGROW>
        end
        contrastFile=fullfile(folder,"qmv2_inclusion_contrasts.csv");
        writetable(localContrasts,contrastFile);
        files(end+1,1)=contrastFile; %#ok<AGROW>
        fprintf("Experimental ROI contrasts %s -> %s\n",id,contrastFile);
    end
end
% A combined descriptive table makes modality/phantom comparisons possible
% without assuming identical acquisition grids or a measured ground truth.
allRoot=fullfile(C.data_root,"analysis",C.study_id, ...
    "M"+string(C.m)+"_step"+string(C.step_pixels),C.analysis_version);
if ~isfolder(allRoot),mkdir(allRoot);end
file=fullfile(allRoot,"all_experiments_roi_summary.csv");
writetable(T,file);
files(end+1,1)=file;
if ~isempty(contrasts)
    file=fullfile(allRoot,"all_inclusion_contrasts.csv");
    writetable(contrasts,file);
    files(end+1,1)=file;
end
end

function contrasts=getContrastConfig(spec)
contrasts=[];
if isfield(spec,"contrasts"),contrasts=spec.contrasts;end
end

function roi=getROIConfig(spec)
roi=[];
if isfield(spec,"rois"),roi=spec.rois;end
end
