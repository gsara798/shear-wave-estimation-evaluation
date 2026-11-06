function [jobs,models]=qmv2_experimental_plan(C,selectedCases,selectedArms)
%QMV2_EXPERIMENTAL_PLAN Read-only discovery of experimental inputs & bundles.
% No simulation, IQ processing, model fitting or output writes.
if nargin<2 || isempty(selectedCases)
    selectedCases=string({C.cases.id});
end
if nargin<3 || isempty(selectedArms),selectedArms=C.arms;end
selectedCases=string(selectedCases);
selectedArms=string(selectedArms);
assert(all(ismember(selectedCases,string({C.cases.id}))) && ...
    ~isempty(selectedCases),"ExpQMV2:UnknownCase","Unknown dataset ID.");
assert(all(ismember(selectedArms,C.arms)) && ...
    ~isempty(selectedArms),"ExpQMV2:UnknownArm","Unknown model arm.");
modelRows=cell(numel(selectedArms),1);
for i=1:numel(selectedArms)
    arm=selectedArms(i);
    [path,inputKind]=resolveArm(C,arm);
    modelRows{i}=table(arm,inputKind,path,isfile(path), ...
        'VariableNames',["arm","input_kind","bundle_file","model_present"]);
end
models=vertcat(modelRows{:});
rows=cell(0,1);
for i=1:numel(C.cases)
    item=C.cases(i);
    id=string(item.id);
    if ~ismember(id,selectedCases),continue,end
    root=fullfile(C.data_root,string(item.relative_path));
    [frequencies,run,runCandidates]=discoverCase(item,root);
    if isempty(frequencies)
        rows{end+1,1}=table(id,string(item.modality),string(item.type), ...
            NaN,root,run,runCandidates, ...
            "",false,"",false,false, ...
            'VariableNames',["case_id","modality","phantom_type", ...
            "frequency_hz","dataset_root","raw_run","run_candidates", ...
            "raw_sample","raw_exists","donut_sample","donut_exists", ...
            "rois_defined"]); %#ok<AGROW>
        continue
    end
    roiDefined=isfield(item,"rois") && ~isempty(item.rois);
    for frequency=frequencies(:)'
        fName=sprintf("%gHz",frequency);
        raw=fullfile(root,"processed",run,fName,"wavefield_sample.mat");
        donut=fullfile(root,"processed",C.filtered_run, ...
            fName,"wavefield_sample.mat");
        rows{end+1,1}=table(id,string(item.modality),string(item.type), ...
            frequency,root,run,runCandidates, ...
            raw,isfile(raw),donut,isfile(donut),roiDefined, ...
            'VariableNames',["case_id","modality","phantom_type", ...
            "frequency_hz","dataset_root","raw_run","run_candidates", ...
            "raw_sample","raw_exists","donut_sample","donut_exists", ...
            "rois_defined"]); %#ok<AGROW>
    end
end
jobs=vertcat(rows{:});
end

function [path,kind]=resolveArm(C,arm)
repo=C.reqml_root;
if isfield(C,"model_bundles") && isfield(C.model_bundles,char(arm))
    entry=C.model_bundles.(char(arm));
    path=string(entry.file);
    kind=string(entry.input_kind);
    assert(ismember(kind,["raw","donut"]), ...
        "ExpQMV2:InputKind","Custom model input kind must be raw or donut.");
    if ~startsWith(path,["/","~"]) && ~contains(path,":\")
        path=fullfile(repo,path);
    end
    return
end
if arm=="reduced14" || arm=="reduced14_filtered"
    path=fullfile(repo,"training","q0_v5_clean_campaign", ...
        "outputs","reduced14_transfer_bundle_v1","model_bundle.mat");
    kind="raw";
    if arm=="reduced14_filtered",kind="donut";end
    return
end
if startsWith(arm,"qmv2_unfiltered_")
    subset=extractAfter(arm,"qmv2_unfiltered_");
    filterName="unfiltered";
    kind="raw";
elseif startsWith(arm,"qmv2_fixed_donut_")
    subset=extractAfter(arm,"qmv2_fixed_donut_");
    filterName="fixed_donut";
    kind="donut";
else
    error("ExpQMV2:UnknownArm","Arm %s is not a registered QMV2 model.",arm);
end
sets=["reduced14","reduced14_frequency", ...
    "expanded20","expanded20_frequency"];
assert(ismember(subset,sets),"ExpQMV2:UnknownPredictorSet", ...
    "Unexpected QMV2 predictor subset: %s",subset);
path=fullfile(repo,"training","quality_mask_v2_campaign", ...
    "outputs","full_clean_plane_v2","postprocess_v1", ...
    "quantile_oof_M1to3_v1",filterName, ...
    "transfer_bundles_v1",subset,"model_bundle.mat");
end

function [frequencies,run,candidates]=discoverCase(item,root)
run=string(item.raw_run);
frequencies=double(item.frequencies_hz(:))';
% Support datasets with unknown frequency lists by inspecting recorded Hz
% values in existing processed samples and acquisition filenames.
if isempty(frequencies)
    samples=dir(fullfile(root,"processed","*","*Hz", ...
        "wavefield_sample.mat"));
    freqValues=nan(numel(samples),1);
    for k=1:numel(samples)
        [~,folder]=fileparts(samples(k).folder);
        freqValues(k)=str2double(erase(string(folder),"Hz"));
    end
    rawFiles=dir(fullfile(root,"raw","*.mat"));
    rawFreq=nan(numel(rawFiles),1);
    for k=1:numel(rawFiles)
        match=regexp(rawFiles(k).name,"(\d+)Hz","tokens","once");
        if ~isempty(match),rawFreq(k)=str2double(match{1});end
    end
    frequencies=sort(unique([freqValues(isfinite(freqValues)); ...
        rawFreq(isfinite(rawFreq))]')) ;
end
candidates=strings(0,1);
processedDir=fullfile(root,"processed");
if isfolder(processedDir)
    dirs=dir(processedDir);
    dirs=dirs([dirs.isdir]);
    dirs=dirs(~ismember(string({dirs.name}),[".",".."]));
    for j=1:numel(dirs)
        candidate=string(dirs(j).name);
        if candidate==run || candidate=="" || candidate==string(item.id)
            continue
        end
        if candidate=="" ,continue,end
        if ~isempty(frequencies) && all(arrayfun(@(f) ...
                isfile(fullfile(processedDir,candidate, ...
                    sprintf("%gHz",f),"wavefield_sample.mat")),frequencies))
            candidates(end+1,1)=candidate; %#ok<AGROW>
        end
    end
end
if run=="auto" || run==""
    if numel(candidates)==1
        run=candidates(1);
    else
        run="";
    end
end
candidates=join(candidates,", ");
end
