function T=prepare_homogeneous_pilot(options)
%PREPARE_HOMOGENEOUS_PILOT Plan or write 3-D k-Wave homogeneous controls.
% No simulation is executed here. Requires the custom "develop/v2"
% examples/kwave/3d/opposed_x_disks/config.json (not public run_simulation).
%
% T=prepare_homogeneous_pilot(); % read-only plan
% T=prepare_homogeneous_pilot(WriteConfigs=true); % 0.2-mm reference configs
% T=prepare_homogeneous_pilot(GridSpacingM=0.0005,WriteConfigs=true);
% % Writes a separate 0.5-mm resolution-pilot set.
arguments
    options.SimulationRoot (1,1) string = ...
        "/Users/sara/local/shear-wave-simulation-framework"
    options.OutputRoot (1,1) string = ""
    options.WriteConfigs (1,1) logical = false
    options.GridSpacingM (1,1) double {mustBePositive} = 0.0002
end
here=string(fileparts(mfilename("fullpath")));
if options.OutputRoot==""
    options.OutputRoot=fullfile(here,"homogeneous","outputs");
end
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
spacing=double(options.GridSpacingM);
baseSpacing=double(g.grid_spacing_m);
% Keep the original 0.2-mm protocol immutable while allowing a separate
% 0.5-mm, fast feasibility test. No outputs/configs are ever overwritten.
assert(abs(spacing-baseSpacing)<1e-12 || abs(spacing-0.0005)<1e-12, ...
    "FreqBias:UnsupportedResolution", ...
    "Only the frozen 0.2-mm design and 0.5-mm feasibility pilot are supported.");
if abs(spacing-baseSpacing)<1e-12
    outputRoot=options.OutputRoot;
else
    outputRoot=fullfile(options.OutputRoot,"resolution_pilots","dx0p5mm");
end
dims=double(g.domain_size_m_xyz(:).');
fov=double(obs.fov_size_m_xz(:).');
assert(abs(baseSpacing-double(obs.dx_m))<1e-12 && ...
    abs(baseSpacing-double(obs.dz_m))<1e-12 && ...
    all(dims([1 3])>=fov+0.010), ...
    "FreqBias:Geometry","Requested observation/FOV or spacing inconsistent.");
N=max(32,round(dims/spacing)+1);
npoints=prod(N);
% Only an order-of-magnitude memory indicator: solver uses many arrays,
% k-Wave FFT temporaries, sensor time series, MATLAB overhead, etc.
lowBoundGiB=npoints*4*32/1024^3;
fprintf("\n3D computational grid: [%d %d %d], %.3f mm\n", ...
    N(1),N(2),N(3),spacing*1e3);
fprintf("Observation FOV: %.1f x %.1f mm; estimated %d x %d observation pixels\n", ...
    fov(1)*1e3,fov(2)*1e3,round(fov(1)/spacing)+1, ...
    round(fov(2)/spacing)+1);
fprintf("Grid points in 3D solver: %g. Output root: %s\n",npoints,outputRoot);
fprintf("Memory indicative: %.2f GiB for merely 32 single grid arrays; NOT full peak RAM.\n", ...
    lowBoundGiB);
fprintf("Warning: 3D time-domain at %.1f mm can require substantial RAM/time.\n",spacing*1e3);
ids=strings(0,1);
csValues=zeros(0,1);fValues=zeros(0,1);
configs=strings(0,1);runfiles=strings(0,1);
existed=false(0,1);
for cs=velocities
    for f=freqs
        id=sprintf("homo_cs%03d_f%03d",round(cs*100),round(f));
        configFile=fullfile(outputRoot,"configs",id+".json");
        runDir=fullfile(outputRoot,"runs",id);
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
        % Preserve ~1.6 mm physical spacing of sparse source nodes
        % rather than using 8 grid cells at 0.5 mm (=4 mm).
        caseCfg.source_node_spacing_points=max(1,round( ...
            double(plan.source.source_node_spacing_points)*baseSpacing/spacing));
        caseCfg.source_plane_inset_m=double(plan.source.source_plane_inset_m);
        assert(isequal(caseCfg.source_polarization_xyz(:).',[1 0 0]));
        rendered=string(jsonencode(caseCfg,PrettyPrint=true));
        if options.WriteConfigs
            configDir=string(fileparts(configFile));
            if ~isfolder(configDir),mkdir(configDir);end
            if isfile(configFile)
                old=jsondecode(fileread(configFile));
                % JSON objects have no field order; MATLAB structs do.
                % Compare canonical JSON rather than isequaln on structs,
                % which may fail after decoding an otherwise identical file.
                oldCanonical=canonicalJson(old);
                newCanonical=canonicalJson(caseCfg);
                assert(strcmp(oldCanonical,newCanonical), ...
                    "FreqBias:ConfigChanged", ...
                    "Existing JSON has different parameter values; preserving: %s", ...
                    configFile);
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

function encoded=canonicalJson(value)
% Canonicalize object field order recursively, preserving all parameter
% values and JSON array ordering. Do not ignore physically relevant fields.
if isstruct(value)
    value=orderfields(value);
    for idx=1:numel(value)
        names=fieldnames(value);
        for jj=1:numel(names)
            key=names{jj};
            value(idx).(key)=canonicalValue(value(idx).(key));
        end
    end
end
encoded=char(jsonencode(value));
end

function value=canonicalValue(value)
if isstruct(value)
    value=orderfields(value);
    for idx=1:numel(value)
        names=fieldnames(value);
        for jj=1:numel(names)
            key=names{jj};
            value(idx).(key)=canonicalValue(value(idx).(key));
        end
    end
elseif iscell(value)
    for idx=1:numel(value)
        value{idx}=canonicalValue(value{idx});
    end
elseif isstring(value)
    value=char(value);
end
end
