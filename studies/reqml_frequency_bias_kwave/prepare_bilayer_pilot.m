function T=prepare_bilayer_pilot(options)
%PREPARE_BILAYER_PILOT Prepare a nondispersive z-layered 3D k-Wave study.
% It clones the frozen homogeneous case configs, preserving ALL actuator
% geometry, drive/polarization, time stepping and observation settings.
% WriteConfigs=false is a read-only plan and never runs the 3D solver.
arguments
    options.SimulationRoot (1,1) string = ...
        "/Users/sara/local/shear-wave-simulation-framework"
    options.OutputRoot (1,1) string = ...
        "/Users/sara/local/experimental-data-reorganized/2026-02-27/_simulation_studies/reqml_frequency_bias_kwave_v1"
    options.GridSpacingM (1,1) double {mustBePositive} = 0.0005
    options.InterfaceZM (1,1) double {mustBeFinite} = 0
    options.WriteConfigs (1,1) logical = false
end
here=string(fileparts(mfilename("fullpath")));
plan=jsondecode(fileread(fullfile(here,"study_config.json")));
assert(isfield(plan,"bilayer"),"FreqBias:BilayerPlanMissing", ...
    "study_config.json must contain the frozen bilayer parameters.");
B=plan.bilayer;
soft=double(B.negative_z_cs_m_s);
hard=double(B.positive_z_cs_m_s);
freqs=double(B.frequencies_hz(:).');
fovZ=double(plan.observation.fov_size_m_xz(2));
assert(isfinite(soft) && soft>0 && isfinite(hard) && hard>0 && ...
    abs(soft-hard)>eps && all(isfinite(freqs)) && all(freqs>0), ...
    "FreqBias:BilayerPlan","Invalid bilayer speeds/frequencies.");
assert(abs(options.InterfaceZM)<fovZ/2-0.005, ...
    "FreqBias:BilayerInterfaceROI", ...
    "Interface must leave at least 5 mm of each layer inside the ROI.");
% This call is read-only unless WriteConfigs is explicitly true. The
% homogeneous builder defines the exact source policy for both studies.
H=prepare_homogeneous_pilot( ...
    SimulationRoot=options.SimulationRoot,OutputRoot=options.OutputRoot, ...
    GridSpacingM=options.GridSpacingM,WriteConfigs=options.WriteConfigs);
if abs(options.GridSpacingM-0.0005)<1e-12
    resolutionFolder=fullfile(options.OutputRoot,"resolution_pilots","dx0p5mm");
elseif abs(options.GridSpacingM-double(plan.compute_domain.grid_spacing_m))<1e-12
    resolutionFolder=options.OutputRoot;
else
    error("FreqBias:UnsupportedResolution", ...
        "Bilayer must use the same 0.2 or 0.5 mm grid as homogeneous.");
end
if options.InterfaceZM>=0,signLabel="plus";else,signLabel="minus";end
zifLabel="interface_z_"+signLabel+ ...
    replace(sprintf("%.1f",abs(options.InterfaceZM)*1e3),".","p")+"mm";
root=fullfile(resolutionFolder,"bilayer",zifLabel);
ids=strings(numel(freqs),1);
configFiles=strings(numel(freqs),1);
runFiles=strings(numel(freqs),1);
completed=false(numel(freqs),1);
for i=1:numel(freqs)
    f=freqs(i);
    row=find(abs(H.cs_m_s-soft)<1e-10 & abs(H.frequency_hz-f)<1e-10);
    assert(isscalar(row),"FreqBias:HomogeneousBasisMissing", ...
        "Expected matching homogeneous source config for cs=%g f=%g",soft,f);
    ids(i)=sprintf("bilayer_soft%03d_hard%03d_f%03d", ...
        round(soft*100),round(hard*100),round(f));
    configFiles(i)=fullfile(root,"configs",ids(i)+".json");
    runDir=fullfile(root,"runs",ids(i));
    runFiles(i)=fullfile(runDir,"run.mat");
    completed(i)=isfile(runFiles(i));
    if ~options.WriteConfigs
        continue
    end
    % The homogeneous generator has now written/validated its immutable
    % config. Clone it; do not rebuild or approximate actuator masks.
    base=jsondecode(fileread(H.config_file(row)));
    assert(string(base.experiment)=="opposed_x_disks_3d" && ...
        isequal(double(base.source_polarization_xyz(:).'),[1 0 0]), ...
        "FreqBias:SourceBaseline","Unexpected opposed-disk actuation.");
    cfg=base;
    cfg.experiment="opposed_x_disks_bilayer_3d";
    cfg.bilayer=struct("enabled",true, ...
        "interface_z_m",options.InterfaceZM, ...
        "negative_z_cs_m_s",soft,"positive_z_cs_m_s",hard);
    cfg.output_dir=char(runDir);
    cfg.overwrite=false;
    % Source geometry, velocity amplitude, temporal phase and excitation
    % are bit-for-bit identical to the corresponding homogeneous JSON.
    actuatorFields=["disk_radius_m","source_plane_inset_m", ...
        "source_node_spacing_points","source_velocity_amplitude_m_s", ...
        "source_relative_phase_rad","source_polarization_xyz", ...
        "grid_spacing_m","domain_size_m_xyz","roi_size_m_xz", ...
        "frequency_hz","density_kg_m3","compressional_speed_factor", ...
        "cfl","settling_cycles","analysis_cycles","pml_size_points"];
    for name=actuatorFields
        assert(isequaln(base.(name),cfg.(name)), ...
            "FreqBias:ActuatorChanged","Cloned actuator parameter changed: %s",name);
    end
    folder=string(fileparts(configFiles(i)));
    if ~isfolder(folder),mkdir(folder);end
    if isfile(configFiles(i))
        old=jsondecode(fileread(configFiles(i)));
        assert(strcmp(canonicalJson(old),canonicalJson(cfg)), ...
            "FreqBias:BilayerConfigChanged", ...
            "Existing bilayer config differs; preserving %s",configFiles(i));
    else
        fid=fopen(configFiles(i),"w");
        assert(fid>0,"FreqBias:ConfigWrite","Cannot create %s",configFiles(i));
        cleanup=onCleanup(@()fclose(fid));
        fprintf(fid,"%s\n",jsonencode(cfg,PrettyPrint=true));
        clear cleanup
    end
end
T=table(ids,freqs(:),configFiles,runFiles,completed, ...
    VariableNames=["case_id","frequency_hz","config_file","run_file","completed"]);
disp(T(:,["case_id","frequency_hz","completed"]));
fprintf("Bilayer cs(-z)=%.2f, cs(+z)=%.2f m/s, z-interface=%.1f mm\n", ...
    soft,hard,options.InterfaceZM*1e3);
fprintf("Same opposed x-driven disks as homogeneous; output: %s\n",root);
if ~logical(B.interface_position_matches_experiment)
    fprintf("WARNING: z-interface is a CONTROL location, not verified experimental depth.\n");
end
if ~options.WriteConfigs
    fprintf("Read-only preview; use WriteConfigs=true before solver execution.\n");
end
end

function encoded=canonicalJson(value)
encoded=char(jsonencode(orderNested(value)));
end

function value=orderNested(value)
if isstruct(value)
    value=orderfields(value);
    names=fieldnames(value);
    for i=1:numel(value)
        for j=1:numel(names)
            key=names{j};
            value(i).(key)=orderNested(value(i).(key));
        end
    end
elseif iscell(value)
    for i=1:numel(value)
        value{i}=orderNested(value{i});
    end
end
end
