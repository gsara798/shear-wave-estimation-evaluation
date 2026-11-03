function T=prepare_homogeneous_pilot(options)
%PREPARE_HOMOGENEOUS_PILOT Plan or write 3-D k-Wave homogeneous controls.
% No simulation is executed here. Requires the custom "develop/v2"
% examples/kwave/3d/opposed_x_disks/config.json (not public run_simulation).
%
% T=prepare_homogeneous_pilot(); % read-only plan
% T=prepare_homogeneous_pilot(WriteConfigs=true); % write 8 JSONs
arguments
    options.SimulationRoot (1,1) string = ...
        "/Users/sara/local/shear-wave-simulation-framework"
    options.OutputRoot (1,1) string = ...
        "/Users/sara/local/experimental-data-reorganized/2026-02-27/_simulation_studies/reqml_frequency_bias_kwave_v1"
    options.WriteConfigs (1,1) logical = false
end
here=string(fileparts(mfilename("fullpath")));
plan=jsondecode(fileread(fullfile(here,"study_config.json")));
template=fullfile(options.SimulationRoot, ...
    "examples","kwave","3d","opposed_x_disks","config.json");
assert(isfile(template),"FreqBias:TemplateNotFound", ...
    "Missing custom develop/v2 opposed-disks config: %s",template);
base=jsondecode(fileread(template));
assert(string(base.experiment)=="opposed_x_disks_3d" && ...
    isequal(double(base.source_polarization_xyz(:).'),[1 0 0]) && ...
    ~logical(base.attenuation_enabled), ...
    "FreqBias:TemplateMismatch","Expected the lossless x-driven 3D disk pilot.");
obs=plan.observation;
g=plan.compute_domain;
velocities=double(plan.homogeneous.cs_m_s(:).');
freqs=double(plan.homogeneous.frequencies_hz(:).');
spacing=double(g.grid_spacing_m);
dims=double(g.domain_size_m_xyz(:).');
fov=double(obs.fov_size_m_xz(:).');
assert(abs(spacing-double(obs.dx_m))<1e-12 && ...
    abs(spacing-double(obs.dz_m))<1e-12 && ...
    all(dims([1 3])>=fov+0.010), ...
    "FreqBias:Geometry","Requested observation/FOV or spacing inconsistent.");
N=max(32,round(dims/spacing)+1);
npoints=prod(N);
% Only an order-of-magnitude memory indicator: solver uses many arrays,
% k-Wave FFT temporaries, sensor time series, MATLAB overhead, etc.
lowBoundGiB=npoints*4*32/1024^3;
fprintf("\n3D computational grid: [%d %d %d], %.3f mm\n", ...
    N(1),N(2),N(3),spacing*1e3);
fprintf("Observation FOV: %.1f x %.1f mm; %g grid points\n", ...
    fov(1)*1e3,fov(2)*1e3,npoints);
fprintf("Memory indicative: %.2f GiB for merely 32 single grid arrays; NOT full peak RAM.\n", ...
    lowBoundGiB);
fprintf("Warning: 3D time-domain at 0.2 mm may need very large RAM/time.\n");
ids=strings(0,1);
csValues=zeros(0,1);fValues=zeros(0,1);
configs=strings(0,1);runfiles=strings(0,1);
existed=false(0,1);
for cs=velocities
    for f=freqs
        id=sprintf("homo_cs%03d_f%03d",round(cs*100),round(f));
        configFile=fullfile(options.OutputRoot,"configs",id+".json");
        runDir=fullfile(options.OutputRoot,"runs",id);
        caseCfg=base;
        caseCfg.cs_m_s=cs;
        caseCfg.frequency_hz=f;
        caseCfg.grid_spacing_m=spacing;
        caseCfg.domain_size_m_xyz=dims;
        caseCfg.roi_size_m_xz=fov;
        caseCfg.attenuation_enabled=false;
        caseCfg.output_dir=char(runDir);
        caseCfg.overwrite=false;
        caseCfg.source_relative_phase_rad=double(plan.source.phase_offset_rad);
        caseCfg.disk_radius_m=double(plan.source.disk_radius_m);
        caseCfg.source_node_spacing_points= ...
            double(plan.source.source_node_spacing_points);
        caseCfg.source_plane_inset_m=double(plan.source.source_plane_inset_m);
        assert(isequal(caseCfg.source_polarization_xyz(:).',[1 0 0]));
        rendered=string(jsonencode(caseCfg,PrettyPrint=true));
        if options.WriteConfigs
            configDir=string(fileparts(configFile));
            if ~isfolder(configDir),mkdir(configDir);end
            if isfile(configFile)
                old=jsondecode(fileread(configFile));
                assert(isequaln(old,caseCfg),"FreqBias:ConfigChanged", ...
                    "Existing simulation config differs; preserving: %s",configFile);
            else
                fid=fopen(configFile,"w");
                assert(fid>0,"FreqBias:ConfigWrite","Cannot write %s",configFile);
                cleanup=onCleanup(@()fclose(fid));
                fprintf(fid,"%s\n",rendered);
                clear cleanup
            end
        end
        ids(end+1,1)=string(id); %#ok<AGROW>
        csValues(end+1,1)=cs; %#ok<AGROW>
        fValues(end+1,1)=f; %#ok<AGROW>
        configs(end+1,1)=configFile; %#ok<AGROW>
        runfiles(end+1,1)=fullfile(runDir,"run.mat"); %#ok<AGROW>
        existed(end+1,1)=isfile(runfiles(end)); %#ok<AGROW>
    end
end
T=table(ids,csValues,fValues,configs,runfiles,existed, ...
    VariableNames=["case_id","cs_m_s","frequency_hz", ...
    "config_file","run_file","completed"]);
disp(T(:,["case_id","cs_m_s","frequency_hz","completed"]));
if ~options.WriteConfigs
    fprintf("Read-only preview. Use WriteConfigs=true to write JSON configs; no solver runs.\n");
else
    fprintf("Homogeneous configs prepared. Pilot one case before full sweep.\n");
end
end
