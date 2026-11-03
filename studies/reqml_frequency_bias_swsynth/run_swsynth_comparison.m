function out=run_swsynth_comparison(options)
%RUN_SWSYNTH_COMPARISON Filter, predict, analyze and plot frozen model arms.
% No swsynth/k-Wave simulation, no model training and no IQ processing.
arguments
    options.Stage (1,1) string {mustBeMember(options.Stage, ...
        ["plan","filter","estimate","analyze","plot","all"])} = "plan"
    options.ReqmlRoot (1,1) string = "/Users/sara/local/req-ml"
    options.Arms (1,:) string = ["A_raw_v1","B_filtered_v1", ...
        "C_filtered_v2","candidate10","candidate", ...
        "candidate10_filtered","candidate_filtered"]
    options.CaseIDs (1,:) string = strings(1,0)
    options.M (1,1) double {mustBeMember(options.M,[2 3])} = 2
    options.StepPixels (1,1) double {mustBeInteger,mustBePositive} = 2
    options.UseParallel (1,1) logical = false
end
C=swsynth_comparison_config(ReqmlRoot=options.ReqmlRoot, ...
    Arms=options.Arms,M=options.M,StepPixels=options.StepPixels);
here=C.studyRoot;
if options.Stage~="plan"
    addpath(fullfile(C.reqmlRoot,"src"),"-begin");
    addpath(fullfile(C.reqmlRoot,"training","q0_v5_clean_campaign"),"-begin");
    addpath(fullfile(fileparts(fileparts(here)),"src"),"-begin");
end
T=C.Cases;
if ~isempty(options.CaseIDs)
    assert(all(ismember(options.CaseIDs,T.case_id)), ...
        "SynthCompare:UnknownCase","One or more CaseIDs are unknown.");
    T=T(ismember(T.case_id,options.CaseIDs),:);
end
if options.Stage=="plan"
    T.simulation_done=false(height(T),1);
    T.filtered_done=false(height(T),1);
    for i=1:height(T)
        T.simulation_done(i)=isfile(T.status_file(i));
        T.filtered_done(i)=isfile(filteredFile(C,T.case_id(i)));
    end
    out=T;
    disp(T(:,["case_id","series","frequency_hz", ...
        "simulation_done","filtered_done"]));
    fprintf("Plan: %d cases x %d arms = %d predictions, M=%g, StepPixels=%d (read-only).\n", ...
        height(T),numel(C.Arms),height(T)*numel(C.Arms),C.M,C.StepPixels);
    return
end
if options.Stage=="analyze" || options.Stage=="plot"
    assert(isempty(options.CaseIDs),"SynthCompare:AnalysisScope", ...
        "ROI analysis/plots require the complete 20-case series.");
    if options.Stage=="analyze"
        out=analyze_swsynth_comparison(C);
    else
        out=plot_swsynth_comparison(C);
    end
    return
end
assert(~isempty(which("reqml.predictSWS")) && ...
    ~isempty(which("reqml.models.loadQ0Model")), ...
    "SynthCompare:MissingREQML","REQ-ML src is not on MATLAB path.");
if options.Stage=="filter" || options.Stage=="all"
    assert(~isempty(which("q0v5.filter.applyFixedDonut")), ...
        "SynthCompare:MissingDonut","Q0-v5 donut filter unavailable.");
end
models=cell(numel(C.Arms),1);
modelFiles=strings(numel(C.Arms),1);
if options.Stage=="estimate" || options.Stage=="all"
    for a=1:numel(C.Arms)
        modelFiles(a)=resolveBundle(C.ModelPaths(a));
        models{a}=reqml.models.loadQ0Model(Model=modelFiles(a));
        fprintf("Model %s: %d predictors\n",C.Arms(a), ...
            numel(models{a}.predictor_names));
    end
end
completed=0;
for i=1:height(T)
    caseID=T.case_id(i);
    sample=simulationSample(T(i,:));
    fprintf("\n[%d/%d] %s (%g Hz)\n",i,height(T),caseID,T.frequency_hz(i));
    if options.Stage=="filter" || options.Stage=="all"
        createFiltered(C,sample,caseID);
    end
    if options.Stage=="estimate" || options.Stage=="all"
        for a=1:numel(C.Arms)
            source=sample;
            if C.Inputs(a)=="filtered"
                source=filteredFile(C,caseID);
                assert(isfile(source),"SynthCompare:FilterFirst", ...
                    "Run Stage=filter first: %s",source);
            end
            destination=swsynth_comparison_estimate_file(C,T(i,:),C.Arms(a));
            makeEstimate(C,source,modelFiles(a),models{a}, ...
                destination,C.Arms(a),caseID,options.UseParallel);
            completed=completed+1;
        end
    end
end
if options.Stage=="all"
    out=analyze_swsynth_comparison(C);
    plot_swsynth_comparison(C);
else
    out=struct("stage",options.Stage,"cases",height(T), ...
        "completed_or_verified_estimates",completed,"arms",C.Arms);
end
end

function sample=simulationSample(row)
statusFile=row.status_file(1);
assert(isfile(statusFile),"SynthCompare:MissingSimulation", ...
    "Simulation is not finished: %s",row.case_id(1));
record=jsondecode(fileread(statusFile));
assert(string(record.case_id)==row.case_id(1) && ...
    string(record.group)==row.group(1) && ...
    double(record.frequency_hz)==row.frequency_hz(1) && ...
    string(record.config_file)==row.config_file(1), ...
    "SynthCompare:SimulationIdentity","Invalid simulation marker %s",statusFile);
sample=string(record.sample_file);
assert(isfile(sample),"SynthCompare:MissingSample", ...
    "Simulation sample missing: %s",sample);
end

function source=filteredFile(C,id)
source=fullfile(C.outputRoot,"filtered",id,"wavefield_sample.mat");
end

function createFiltered(C,source,destID)
dest=filteredFile(C,destID);
stamp=dir(source);
identity=struct("source_file",char(source), ...
    "source_bytes",double(stamp.bytes), ...
    "source_datenum",double(stamp.datenum), ...
    "method","q0v5_global_complex_donut", ...
    "cs_min_m_s",C.FilterCsMin,"cs_max_m_s",C.FilterCsMax, ...
    "taper",C.FilterTaper);
signature=string(jsonencode(identity));
folder=string(fileparts(dest));
manifest=fullfile(folder,"filter_manifest.mat");
if isfile(dest) || isfile(manifest)
    assert(isfile(dest) && isfile(manifest), ...
        "SynthCompare:IncompleteFilter","Inspect incomplete filtered output: %s",dest);
    prior=load(manifest,"signature");
    assert(isfield(prior,"signature") && ...
        string(prior.signature)==signature, ...
        "SynthCompare:StaleFilter","Filtered sample has different source/settings: %s",dest);
    fprintf("  filtered: resumed\n");
    return
end
s=load(source,"wavefield_sample");
assert(isfield(s,"wavefield_sample"),"SynthCompare:SampleSchema", ...
    "Missing wavefield_sample struct: %s",source);
wavefield_sample=s.wavefield_sample; %#ok<NASGU>
assert(isfield(wavefield_sample,"coordinates") && ...
    isfield(wavefield_sample,"wavefield") && ...
    isfield(wavefield_sample.wavefield,"data_zx") && ...
    isfield(wavefield_sample.wavefield,"frequency_hz"), ...
    "SynthCompare:SampleSchema","Unexpected wavefield sample fields.");
if ~isfield(wavefield_sample,"provenance")
    wavefield_sample.provenance=struct();
end
assert(~isfield(wavefield_sample.provenance,"swsynth_comparison_filter"), ...
    "SynthCompare:DoubleFilter","Sample already has this spatial filter.");
fx=q0v5.filter.applyFixedDonut( ...
    wavefield_sample.wavefield.data_zx, ...
    double(wavefield_sample.coordinates.dx_m), ...
    double(wavefield_sample.coordinates.dz_m), ...
    double(wavefield_sample.wavefield.frequency_hz), ...
    CsMinMS=C.FilterCsMin,CsMaxMS=C.FilterCsMax, ...
    TaperRelative=C.FilterTaper);
wavefield_sample.wavefield.data_zx=fx.field_zx;
wavefield_sample.provenance.swsynth_comparison_filter=struct( ...
    "type","q0v5_global_complex_donut", ...
    "raw_sample",char(source), ...
    "cs_min_m_s",C.FilterCsMin,"cs_max_m_s",C.FilterCsMax, ...
    "taper",C.FilterTaper, ...
    "retained_power_fraction",fx.retained_energy_fraction);
if ~isfolder(folder),mkdir(folder);end
partial=dest+".partial.mat";
assert(~isfile(partial),"SynthCompare:PartialFilter", ...
    "Inspect existing partial file %s",partial);
save(partial,"wavefield_sample","-v7.3");
[ok,msg]=movefile(partial,dest);
assert(ok,"SynthCompare:FilterWrite","Cannot publish filter output: %s",msg);
save(manifest,"signature","identity");
fprintf("  filtered: retained %.1f%% power\n",100*fx.retained_energy_fraction);
end

function makeEstimate(C,source,modelFile,loaded,dest,arm,caseID,useParallel)
a=dir(source);b=dir(modelFile);
identity=struct("arm",char(arm),"case_id",char(caseID), ...
    "input_file",char(source),"input_bytes",double(a.bytes), ...
    "input_datenum",double(a.datenum), ...
    "model_file",char(modelFile),"model_bytes",double(b.bytes), ...
    "model_datenum",double(b.datenum), ...
    "M",C.M,"step_pixels",C.StepPixels);
comparison_identity=string(jsonencode(identity)); %#ok<NASGU>
if isfile(dest)
    saved=load(dest,"comparison_identity");
    assert(isfield(saved,"comparison_identity"), ...
        "SynthCompare:EstimateIdentityMissing", ...
        "Existing estimate has no comparison_identity; preserving %s",dest);
    if string(saved.comparison_identity)~=comparison_identity
        changed=strings(0,1);
        try
            previous=jsondecode(char(string(saved.comparison_identity)));
            keys=string(fieldnames(identity));
            for j=1:numel(keys)
                key=keys(j);
                if ~isfield(previous,key) || ...
                        ~isequaln(previous.(key),identity.(key))
                    changed(end+1,1)=key; %#ok<AGROW>
                end
            end
        catch
            changed="unreadable_previous_identity";
        end
        error("SynthCompare:EstimateStale", ...
            "Existing estimate differs in: %s. Preserving %s", ...
            strjoin(changed,", "),dest);
    end
    fprintf("  %s: resumed\n",arm);
    return
end
folder=string(fileparts(dest));
if ~isfolder(folder),mkdir(folder);end
partial=dest+".partial.mat";
assert(~isfile(partial),"SynthCompare:PartialEstimate", ...
    "Inspect existing partial file %s",partial);
result=reqml.predictSWS(source,ModelBundle=loaded, ...
    M=C.M,StepPixels=C.StepPixels, ...
    UseParallel=useParallel,Verbose=false); %#ok<NASGU>
result.metadata.comparison_arm=arm;
result.metadata.comparison_case_id=caseID;
result.metadata.comparison_input_file=source;
save(partial,"result","comparison_identity","-v7.3");
[ok,msg]=movefile(partial,dest);
assert(ok,"SynthCompare:EstimateWrite", ...
    "Cannot publish estimate for %s: %s",arm,msg);
fprintf("  %s: predicted (%d valid patches)\n", ...
    arm,result.metadata.valid_patch_count);
end

function file=resolveBundle(path)
path=string(path);
if isfile(path),file=path;return,end
assert(isfolder(path),"SynthCompare:ModelMissing", ...
    "Frozen model not found: %s",path);
direct=fullfile(path,"model_bundle.mat");
if isfile(direct),file=direct;return,end
matches=dir(fullfile(path,"**","model_bundle.mat"));
assert(numel(matches)==1,"SynthCompare:ModelBundle", ...
    "Expected one unique model_bundle.mat under %s, found %d.", ...
    path,numel(matches));
file=fullfile(string(matches(1).folder),string(matches(1).name));
end
