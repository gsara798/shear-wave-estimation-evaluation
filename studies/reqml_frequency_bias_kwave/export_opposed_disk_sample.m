function output=export_opposed_disk_sample(runFile,options)
%EXPORT_OPPOSED_DISK_SAMPLE Convert the CUSTOM 3D opposed-disks run.mat
% into one documented 2D wavefield_sample.mat (REQ-ML contract 1.0).
% Never silently substitute shear-only for physical axial total readout.
%
% export_opposed_disk_sample(runFile,Component="axial_total");
% export_opposed_disk_sample(runFile,Component="axial_shear", ...
%     ApplyFixedDonut=true);
arguments
    runFile (1,1) string
    options.Component (1,1) string {mustBeMember(options.Component, ...
        ["axial_total","axial_shear","axial_compression"])} = "axial_total"
    options.ApplyFixedDonut (1,1) logical = false
    options.ReqmlRoot (1,1) string = "/Users/sara/local/req-ml"
    options.OutputFile (1,1) string = ""
end
assert(isfile(runFile),"FreqBias:MissingRun", ...
    "Custom opposed-disks output not found: %s",runFile);
s=load(runFile,"result");
assert(isfield(s,"result") && isfield(s.result,"fields") && ...
    isfield(s.result,"axes") && isfield(s.result,"truth") && ...
    isfield(s.result,"config"),"FreqBias:RunSchema", ...
    "Expected the opposed_x_disks_3d run.mat layout.");
R=s.result;
assert(string(R.config.experiment)=="opposed_x_disks_3d", ...
    "FreqBias:WrongRunner","Not an opposed_x_disks_3d run.");
fieldName=options.Component+"_displacement_zx";
if options.Component=="axial_total"
    fieldName="axial_total_displacement_zx";
elseif options.Component=="axial_shear"
    fieldName="axial_shear_displacement_zx";
else
    fieldName="axial_compression_displacement_zx";
end
assert(isfield(R.fields,char(fieldName)), ...
    "FreqBias:MissingComponent","Field %s is absent.",fieldName);
U=double(R.fields.(fieldName));
assert(isnumeric(U) && ismatrix(U) && all(isfinite(U),"all"), ...
    "FreqBias:InvalidComponent","Component is not a finite complex 2D field.");
x=double(R.axes.x_m(:).');
z=double(R.axes.z_m(:));
dx=double(R.axes.dx_m);
dz=double(R.axes.dz_m);
f=double(R.config.frequency_hz);
cs=double(R.config.cs_m_s);
assert(isequal(size(U),[numel(z),numel(x)]) && ...
    isscalar(f) && f>0 && isscalar(cs) && cs>0, ...
    "FreqBias:FieldAxes","Invalid custom runner field or coordinates.");
powerShear=sum(abs(double(R.fields.axial_shear_displacement_zx)).^2,"all");
powerCompression=sum(abs(double(R.fields.axial_compression_displacement_zx)).^2,"all");
shear_fraction=powerShear/max(powerShear+powerCompression,eps);
fprintf("Shear-component axial squared amplitude fraction: %.5f\n",shear_fraction);
if shear_fraction<0.1
    warning("FreqBias:WeakAxialShear", ...
        "Only %.1f%% axial squared amplitude is shear; " + ...
        "verify source polarization/field before drawing SWS conclusions.", ...
        100*shear_fraction);
end
if options.ApplyFixedDonut
    assert(isfolder(options.ReqmlRoot),"FreqBias:MissingReqmlRoot", ...
        "REQ-ML root not found: %s",options.ReqmlRoot);
    addpath(fullfile(options.ReqmlRoot,"training","q0_v5_clean_campaign"));
    filt=q0v5.filter.applyFixedDonut(U,dx,dz,f, ...
        CsMinMS=0.8,CsMaxMS=8,TaperRelative=0.06);
    U=filt.field_zx;
    filterLabel="filtered_0p8_8";
else
    filterLabel="raw";
end
if options.OutputFile==""
    outputFile=fullfile(fileparts(runFile),"samples", ...
        options.Component+"_"+filterLabel,"wavefield_sample.mat");
else
    outputFile=options.OutputFile;
end
stamp=dir(runFile);
identity=struct("run_file",runFile,"run_bytes",double(stamp.bytes), ...
    "run_datenum",double(stamp.datenum), ...
    "component",options.Component,"filtered",options.ApplyFixedDonut, ...
    "cs_min_m_s",0.8,"cs_max_m_s",8,"taper_relative",0.06);
if isfile(outputFile)
    prev=load(outputFile,"export_identity");
    assert(isfield(prev,"export_identity") && ...
        isequaln(prev.export_identity,identity), ...
        "FreqBias:OutputExistsWithDifferentIdentity", ...
        "A prior sample does not match this run/component: %s",outputFile);
    output=struct("sample_file",outputFile,"status","already_exists", ...
        "axial_shear_fraction",shear_fraction);
    return
end
wavefield_sample=struct();
wavefield_sample.schema_name="wavefield_sample";
wavefield_sample.schema_version="1.0";
wavefield_sample.generator=struct("name","kwsim_opposed_disks_custom", ...
    "type","synthetic","dimension",3);
wavefield_sample.coordinates=struct("x_m",x,"z_m",z,"dx_m",dx, ...
    "dz_m",dz,"array_order","zx");
wavefield_sample.wavefield=struct("data_zx",U,"frequency_hz",f, ...
    "component","axial","quantity","displacement","units","m");
wavefield_sample.validation=struct("analysis_ready",true, ...
    "numerical_convergence_verified",false);
wavefield_sample.provenance=struct("source_run_file",runFile, ...
    "source_polarization_xyz",R.config.source_polarization_xyz, ...
    "axial_component",options.Component, ...
    "filter_policy",filterLabel, ...
    "axial_shear_squared_amplitude_fraction",shear_fraction);
wavefield_sample.truth=struct("cs_map_zx",cs*ones(size(U)), ...
    "k_map_zx",(2*pi*f/cs)*ones(size(U)), ...
    "material_id_zx",ones(size(U),"uint8"), ...
    "valid_mask_zx",true(size(U)));
export_identity=identity; %#ok<NASGU>
folder=string(fileparts(outputFile));
if ~isfolder(folder),mkdir(folder);end
partial=outputFile+".partial.mat";
assert(~isfile(partial),"FreqBias:PartialFile", ...
    "Inspect pre-existing partial file before export: %s",partial);
save(partial,"wavefield_sample","export_identity","-v7.3");
addpath(fullfile(options.ReqmlRoot,"src"));
if ~isempty(which("reqml.io.load_wavefield_sample"))
    reqml.io.load_wavefield_sample(partial);
end
assert(~isfile(outputFile),"FreqBias:OutputRace", ...
    "Another process already wrote %s",outputFile);
[ok,msg]=movefile(partial,outputFile);
assert(ok,"FreqBias:PublishFailed", ...
    "Could not publish wavefield sample: %s",msg);
output=struct("sample_file",outputFile,"status","created", ...
    "axial_shear_fraction",shear_fraction);
fprintf("REQ-ML wavefield sample ready: %s\n",outputFile);
end
