function T=prepare_swsynth_frequency_study(options)
%PREPARE_SWSYNTH_FREQUENCY_STUDY Plan or write 20 paired swsynth V2 JSONs.
% Three groups: plane homogeneous, plane bilayer, point homogeneous.
% No solver is invoked. OutputRoot defaults inside this study's outputs/.
arguments
    options.OutputRoot (1,1) string = ""
    options.WriteConfigs (1,1) logical = false
end
here=string(fileparts(mfilename("fullpath")));
if options.OutputRoot==""
    options.OutputRoot=fullfile(here,"outputs");
end
P=jsondecode(fileread(fullfile(here,"study_config.json")));
assert(string(P.geometry)=="projected3d" && ...
    abs(double(P.domain.dx_m)-0.0002)<1e-12 && ...
    abs(double(P.domain.dz_m)-0.0002)<1e-12 && ...
    abs(double(P.domain.Lx_m)-0.05)<1e-12 && ...
    abs(double(P.domain.Lz_m)-0.05)<1e-12, ...
    "ReqmlSynth:StudyGeometry","Expected 50x50 mm at 0.2 mm sampling.");
freqs=double(P.frequencies_hz(:).');
speeds=double(P.homogeneous_cs_m_s(:).');
assert(isequal(freqs,[300 400 500 600]) && ...
    isequal(speeds,[1.8 3]), ...
    "ReqmlSynth:StudyFrozen","Study frequency/speed grid differs from protocol.");
positions=buildDiskNodes(P);
groups=strings(0,1);ids=strings(0,1);
csVals=zeros(0,1);freqVals=zeros(0,1);
files=strings(0,1);statusFiles=strings(0,1);
for group=["plane_homogeneous","plane_bilayer","point_homogeneous"]
    if group=="plane_bilayer"
        activeSpeeds=double(P.bilayer.negative_z_cs_m_s);
    else
        activeSpeeds=speeds;
    end
    for cs=activeSpeeds
        for f=freqs
            if group=="plane_bilayer"
                id=sprintf("plane_bilayer_soft%03d_hard%03d_f%03d", ...
                    round(cs*100),round(double(P.bilayer.positive_z_cs_m_s)*100),round(f));
            elseif group=="plane_homogeneous"
                id=sprintf("plane_homo_cs%03d_f%03d",round(cs*100),round(f));
            else
                id=sprintf("point_homo_cs%03d_f%03d",round(cs*100),round(f));
            end
            file=fullfile(options.OutputRoot,"configs",group,id+".json");
            marker=fullfile(options.OutputRoot,"status",id+".json");
            cfg=makeConfig(P,group,cs,f,id,positions);
            if options.WriteConfigs
                folder=string(fileparts(file));
                if ~isfolder(folder),mkdir(folder);end
                if isfile(file)
                    old=jsondecode(fileread(file));
                    assert(strcmp(canonicalJson(old), ...
                        canonicalJson(jsondecode(jsonencode(cfg)))), ...
                        "ReqmlSynth:ConfigChanged", ...
                        "Existing config differs; preserving %s",file);
                else
                    fid=fopen(file,"w");
                    assert(fid>0,"ReqmlSynth:ConfigWrite","Could not write %s",file);
                    cleanup=onCleanup(@()fclose(fid));
                    fprintf(fid,"%s\n",jsonencode(cfg,PrettyPrint=true));
                    clear cleanup
                end
            end
            groups(end+1,1)=group; %#ok<AGROW>
            ids(end+1,1)=string(id); %#ok<AGROW>
            csVals(end+1,1)=cs; %#ok<AGROW>
            freqVals(end+1,1)=f; %#ok<AGROW>
            files(end+1,1)=file; %#ok<AGROW>
            statusFiles(end+1,1)=marker; %#ok<AGROW>
        end
    end
end
assert(numel(ids)==20 && nnz(groups=="plane_homogeneous")==8 && ...
    nnz(groups=="plane_bilayer")==4 && ...
    nnz(groups=="point_homogeneous")==8, ...
    "ReqmlSynth:StudyCount","Expected exactly 20 paired cases.");
T=table(ids,groups,csVals,freqVals,files,statusFiles, ...
    VariableNames=["case_id","group","reference_cs_m_s","frequency_hz", ...
    "config_file","status_file"]);
fprintf("Groups: plane homogeneous=%d, plane bilayer=%d, point homogeneous=%d\n", ...
    nnz(groups=="plane_homogeneous"),nnz(groups=="plane_bilayer"), ...
    nnz(groups=="point_homogeneous"));
if options.WriteConfigs
    fprintf("Created/verified %d configs under %s\n",height(T),options.OutputRoot);
else
    fprintf("Read-only plan for %d configs. WriteConfigs=true writes JSONs.\n",height(T));
end
end

function cfg=makeConfig(P,group,cs,f,id,positions)
cfg=struct();
cfg.schema_version="2.0";
cfg.scenario=char(id);
cfg.seed=53053;
cfg.geometry="projected3d";
cfg.domain=P.domain;
cfg.harmonic=struct("frequency_hz",f,"quantity","relative_motion");
cfg.measurement=struct("axis_xyz",double(P.measurement.axis_xyz(:).'));
if group=="plane_bilayer"
    B=P.bilayer;
    obj=struct("type","bilayer","normal_angle_rad",double(B.normal_angle_rad), ...
        "offset_m",double(B.interface_z_m),"cs_m_s",double(B.positive_z_cs_m_s));
    cfg.medium=struct("background_cs_m_s",double(B.negative_z_cs_m_s));
    cfg.medium.objects={obj};
elseif group=="plane_homogeneous" || group=="point_homogeneous"
    cfg.medium=struct("cs_m_s",cs,"objects",[]);
else
    error("ReqmlSynth:UnknownGroup","Unknown source group %s",group);
end
if group=="plane_homogeneous" || group=="plane_bilayer"
    W=P.plane;
    cfg.propagation=struct("model","plane_wave", ...
        "phase_method","eikonal","normalization",char(W.normalization));
    cfg.incidence=struct("direction_xyz",double(W.directions_xyz), ...
        "relative_amplitude",double(W.relative_amplitude(:).'), ...
        "phase_rad",double(W.phase_rad(:).'), ...
        "polarization",struct("policy",char(W.polarization_policy)));
else
    D=P.point_disks;
    n=size(positions,1);
    cfg.propagation=struct("model","spherical_wave", ...
        "phase_method","analytical", ...
        "geometric_decay_exponent",double(D.geometric_decay_exponent), ...
        "normalization",char(D.normalization));
    cfg.sources=struct("count",n, ...
        "positions",struct("method","explicit","position_xyz_m",positions), ...
        "excitation",struct("force_policy","fixed", ...
            "force_direction_xyz",double(D.force_direction_xyz(:).'), ...
            "amplitude_policy","fixed", ...
            "relative_amplitude",double(D.relative_amplitude_per_node)*ones(1,n), ...
            "phase_policy","fixed", ...
            "phase_rad",double(D.phase_rad_per_node)*ones(1,n)));
end
end

function positions=buildDiskNodes(P)
D=P.point_disks;
Lx=double(P.domain.Lx_m);
Lz=double(P.domain.Lz_m);
physicalX=double(D.kwave_domain_x_m);
inset=double(D.source_plane_inset_m);
radius=double(D.disk_radius_m);
pitch=double(D.node_spacing_m);
xCenters=[-physicalX/2+inset,physicalX/2-inset]+Lx/2;
zCenter=Lz/2;
positions=zeros(0,3);
nDisk=0;
for k=1:2
    n=0;
    for iy=-ceil(radius/pitch):ceil(radius/pitch)
        for iz=-ceil(radius/pitch):ceil(radius/pitch)
            y=iy*pitch;
            zOffset=iz*pitch;
            if y^2+zOffset^2<=radius^2+10*eps(radius^2)
                positions(end+1,:)=[xCenters(k),y,zCenter+zOffset]; %#ok<AGROW>
                n=n+1;
            end
        end
    end
    assert(n==double(D.expected_nodes_per_disk), ...
        "ReqmlSynth:DiskNodeCount","Actuator node count must match k-Wave.");
    nDisk=nDisk+n;
end
assert(nDisk==26 && abs(xCenters(1)+0.008)<1e-12 && ...
    abs(xCenters(2)-0.058)<1e-12, ...
    "ReqmlSynth:DiskPosition","Unexpected opposed-disk center positions.");
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
