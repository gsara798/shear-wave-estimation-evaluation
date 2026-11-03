function R=run_swsynth_frequency_study(options)
%RUN_SWSYNTH_FREQUENCY_STUDY Plan, dry-run-validate, or run the 20-case study.
% Mode="plan" (default) is read-only; "validate" writes JSONs but no
% synthetic wavefields; "run" requires explicit confirmation.
arguments
    options.Mode (1,1) string {mustBeMember(options.Mode, ...
        ["plan","validate","run"])} = "plan"
    options.SimulationRoot (1,1) string = ...
        "/Users/sara/local/shear-wave-simulation-framework"
    options.OutputRoot (1,1) string = ""
    options.ConfirmFullRun (1,1) logical = false
    options.MakePlots (1,1) logical = true
end
here=string(fileparts(mfilename("fullpath")));
if options.OutputRoot==""
    options.OutputRoot=fullfile(here,"outputs");
end
if options.Mode=="run"
    assert(options.ConfirmFullRun,"ReqmlSynth:RunGate", ...
        "Set ConfirmFullRun=true to execute the 20-case study.");
end
T=prepare_swsynth_frequency_study(OutputRoot=options.OutputRoot, ...
    WriteConfigs=options.Mode~="plan");
if options.Mode=="plan"
    R=T;
    return
end
runnerFile=fullfile(options.SimulationRoot,"run_simulation.m");
assert(isfile(runnerFile),"ReqmlSynth:FrameworkMissing", ...
    "Expected V2 run_simulation.m under %s",options.SimulationRoot);
addpath(options.SimulationRoot,"-begin");
addpath(fullfile(options.SimulationRoot,"src"),"-begin");
assert(~isempty(which("run_simulation")),"ReqmlSynth:RunnerUnavailable", ...
    "run_simulation is not visible on the MATLAB path.");
statuses=strings(height(T),1);
directories=strings(height(T),1);
for i=1:height(T)
    id=T.case_id(i);
    group=T.group(i);
    cfgFile=T.config_file(i);
    runRoot=fullfile(options.OutputRoot,"runs",group);
    fprintf("\n[%d/%d] %s\n",i,height(T),id);
    if options.Mode=="run" && isfile(T.status_file(i))
        saved=jsondecode(fileread(T.status_file(i)));
        assert(string(saved.case_id)==id && ...
            string(saved.config_file)==cfgFile && ...
            isfile(string(saved.sample_file)), ...
            "ReqmlSynth:ExistingStatusMismatch", ...
            "Existing success marker does not match a valid sample: %s", ...
            T.status_file(i));
        statuses(i)="skipped_verified_existing";
        directories(i)=string(saved.run_directory);
        continue
    end
    d=run_simulation(cfgFile,DryRun=true, ...
        OutputRoot=runRoot,PlotFigures=false);
    assert(string(d.status)=="dry_run_valid", ...
        "ReqmlSynth:DryRunFailed","Validation failed for %s",id);
    if options.Mode=="validate"
        statuses(i)="dry_run_valid";
        continue
    end
    out=run_simulation(cfgFile,OutputRoot=runRoot, ...
        PlotFigures=options.MakePlots);
    runDir=string(out.run_directory);
    sampleFile=fullfile(runDir,"data","wavefield_sample.mat");
    assert(isfile(sampleFile),"ReqmlSynth:MissingSample", ...
        "Simulation completed without wavefield_sample.mat: %s",sampleFile);
    folder=string(fileparts(T.status_file(i)));
    if ~isfolder(folder),mkdir(folder);end
    marker=struct("case_id",char(id),"group",char(group), ...
        "frequency_hz",T.frequency_hz(i), ...
        "reference_cs_m_s",T.reference_cs_m_s(i), ...
        "config_file",char(cfgFile),"run_directory",char(runDir), ...
        "sample_file",char(sampleFile),"status","completed");
    partial=T.status_file(i)+".partial";
    assert(~isfile(T.status_file(i)) && ~isfile(partial), ...
        "ReqmlSynth:StatusRace", ...
        "Existing marker or partial marker requires inspection: %s",partial);
    fid=fopen(partial,"w");
    assert(fid>0,"ReqmlSynth:StatusWrite","Cannot write %s",partial);
    cleanup=onCleanup(@()fclose(fid));
    fprintf(fid,"%s\n",jsonencode(marker,PrettyPrint=true));
    clear cleanup
    [ok,msg]=movefile(partial,T.status_file(i));
    assert(ok,"ReqmlSynth:StatusPublish","Cannot publish marker: %s",msg);
    statuses(i)="completed";
    directories(i)=runDir;
end
R=table(T.case_id,T.group,T.reference_cs_m_s,T.frequency_hz, ...
    statuses,directories,VariableNames= ...
    ["case_id","group","reference_cs_m_s","frequency_hz","status","run_directory"]);
disp(R);
fprintf("Study mode %s finished: %d rows, output root %s\n", ...
    options.Mode,height(R),options.OutputRoot);
end
