function out=run_one_homogeneous_case(options)
%RUN_ONE_HOMOGENEOUS_CASE Single-case guarded execution of the 3-D custom
% opposed x-normal disk experiment. Does NOT run whole 8-condition sweep.
%
% out=run_one_homogeneous_case(); % preview only
% out=run_one_homogeneous_case(Execute=true,ResourcesReviewed=true);
arguments
    options.CaseID (1,1) string = "homo_cs180_f500"
    options.SimulationRoot (1,1) string = ...
        "/Users/sara/local/shear-wave-simulation-framework"
    options.OutputRoot (1,1) string = ...
        "/Users/sara/local/experimental-data-reorganized/2026-02-27/_simulation_studies/reqml_frequency_bias_kwave_v1"
    options.Execute (1,1) logical = false
    options.ResourcesReviewed (1,1) logical = false
end
% Never write even a config file before the explicit 3-D resource gate.
if options.Execute
    assert(options.ResourcesReviewed,"FreqBias:ResourceGate", ...
        "3D 0.2 mm simulations are large. Inspect RAM/runtime first; " + ...
        "then explicitly set ResourcesReviewed=true.");
end
T=prepare_homogeneous_pilot(SimulationRoot=options.SimulationRoot, ...
    OutputRoot=options.OutputRoot, ...
    WriteConfigs=options.Execute);
match=find(T.case_id==options.CaseID);
assert(isscalar(match),"FreqBias:UnknownCase", ...
    "Unknown homogeneous control case: %s",options.CaseID);
out=struct("case_id",options.CaseID,"run_file",T.run_file(match), ...
    "config_file",T.config_file(match),"status","planned");
fprintf("Selected: %s; completed=%d\n", ...
    options.CaseID,T.completed(match));
if ~options.Execute
    fprintf("Preview only: call Execute=true,ResourcesReviewed=true AFTER solver preflight.\n");
    return
end

if T.completed(match)
    saved=load(T.run_file(match),"result");
    assert(isfield(saved,"result") && ...
        string(saved.result.config.experiment)=="opposed_x_disks_3d" && ...
        double(saved.result.config.cs_m_s)==T.cs_m_s(match) && ...
        double(saved.result.config.frequency_hz)==T.frequency_hz(match), ...
        "FreqBias:ExistingRunMismatch", ...
        "Existing 3D output identity disagrees with requested condition.");
    out.status="skipped_verified_existing";
    return
end
runnerDir=fullfile(options.SimulationRoot, ...
    "examples","kwave","3d","opposed_x_disks");
assert(isfile(fullfile(runnerDir,"run_opposed_x_disks_3d.m")), ...
    "FreqBias:RunnerNotFound", ...
    "Expected develop/v2 custom opposed-disk runner not found.");
addpath(fullfile(options.SimulationRoot,"src"))
addpath(runnerDir);
% setup_simulation_framework(KWavePath=...) stores KWSIM_KWAVE_PATH, but
% does not add k-Wave's root to MATLAB's search path. Resolve it here,
% without assuming the path was already added to this session.
runner=string(which("run_opposed_x_disks_3d"));
assert(strlength(runner)>0,"FreqBias:RunnerUnavailable", ...
    "Custom run_opposed_x_disks_3d.m is not visible under %s.",runnerDir);
solver=string(which("pstdElastic3D"));
if strlength(solver)==0
    kwavePath=string(getenv("KWSIM_KWAVE_PATH"));
    if strlength(kwavePath)>0 && isfolder(kwavePath)
        addpath(kwavePath);
        % Some installations put the k-Wave MATLAB sources inside
        % an additional k-Wave directory under the configured folder.
        if isempty(which("pstdElastic3D")) && ...
                isfolder(fullfile(kwavePath,"k-Wave"))
            addpath(fullfile(kwavePath,"k-Wave"));
        end
    end
    solver=string(which("pstdElastic3D"));
end
assert(strlength(solver)>0,"FreqBias:KWaveUnavailable", ...
    ["pstdElastic3D is not on the MATLAB path. " + ...
     "The framework's setup stores KWSIM_KWAVE_PATH but does not add " + ...
     "the external toolbox functions to the path. " + ...
     "Run addpath('/Users/sara/local/k-wave-toolbox-version-1.4.1') " + ...
     "or configure the correct external toolbox directory."]);
fprintf("Custom runner: %s\n",runner);
fprintf("k-Wave solver: %s\n",solver);
outcome=run_opposed_x_disks_3d(T.config_file(match));
assert(isfile(outcome.run_file), ...
    "FreqBias:MissingSolverOutput", ...
    "Solver returned but no run.mat exists: %s",outcome.run_file);
out.run_file=string(outcome.run_file);
out.status="completed";
out.elapsed_s=outcome.elapsed_s;
fprintf("3D homogeneous control completed: %s\n",out.run_file);
end
