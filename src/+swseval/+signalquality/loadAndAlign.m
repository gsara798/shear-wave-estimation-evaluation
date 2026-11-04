function D=loadAndAlign(estimateFile,temporalFile,iqFile,options)
%LOADANDALIGN Align experimental signal-quality maps to SWS patch centers.
% Quality is measured on raw IQ/Loupas data, not necessarily on the
% spatially filtered wavefield used for REQ-ML estimation.
arguments
    estimateFile (1,1) string
    temporalFile (1,1) string
    iqFile (1,1) string
    options.WindowWidthMM (1,1) double {mustBeNonnegative} = 0
end

map=swseval.io.loadReqmlResult(estimateFile);
assert(isfile(temporalFile),"swseval:MissingQualityFile", ...
    "Missing temporal-consistency MAT: %s",temporalFile);
assert(isfile(iqFile),"swseval:MissingQualityFile", ...
    "Missing IQ-quality MAT: %s",iqFile);
rs=load(temporalFile,"r");qs=load(iqFile,"q");
assert(isfield(rs,"r") && isstruct(rs.r) && ...
    isfield(qs,"q") && isstruct(qs.q), ...
    "swseval:InvalidQualityFile","Expected variables r and q.");
r=rs.r;q=qs.q;
assert(isfield(r,"frequency_hz") && isfield(q,"frequency_hz"), ...
    "swseval:MissingFrequency","Both diagnostic MAT files need frequency_hz.");
assert(isequal(double(r.frequency_hz),double(q.frequency_hz)), ...
    "swseval:SignalQualityFrequencyMismatch", ...
    "Temporal and IQ diagnostics have different frequencies.");
if isfield(map.metadata,"frequency_hz")
    assert(abs(double(map.metadata.frequency_hz)-double(r.frequency_hz))<1e-6, ...
        "swseval:SignalQualityFrequencyMismatch", ...
        "Estimate frequency differs from quality-diagnostic frequency.");
end
assert(isfield(r,"x_m") && isfield(r,"z_m") && ...
    isfield(q,"x_m") && isfield(q,"z_m"), ...
    "swseval:MissingAxes","Quality diagnostics need x_m and z_m.");
rx=double(r.x_m(:))'*1e3;rz=double(r.z_m(:))*1e3;
qx=double(q.x_m(:))'*1e3;qz=double(q.z_m(:))*1e3;
assert(all(isfinite(rx)) && all(diff(rx)>0) && ...
    all(isfinite(rz)) && all(diff(rz)>0), ...
    "swseval:InvalidQualityAxes","Quality axes must increase in mm.");
assert(isequal(size(rx),size(qx)) && isequal(size(rz),size(qz)) && ...
    all(abs(rx-qx)<1e-6) && all(abs(rz-qz)<1e-6), ...
    "swseval:QualityGridMismatch", ...
    "IQ and temporal-consistency quality grids are not aligned.");
if isfield(r,"source_file") && isfield(q,"source_file")
    [~,rname,rext]=fileparts(string(r.source_file));
    [~,qname,qext]=fileparts(string(q.source_file));
    assert(rname+rext==qname+qext, ...
        "swseval:QualitySourceMismatch", ...
        "IQ and temporal diagnostics originate from different acquisitions.");
end

width=options.WindowWidthMM;
if width==0 && isfield(map.metadata,"patch_width_pixels") && ...
        isfield(map.metadata,"step_pixels")
    n=double(map.metadata.patch_width_pixels);
    step=double(map.metadata.step_pixels);
    if isscalar(n) && isscalar(step) && n>0 && step>0 && ...
            numel(map.x_mm)>1 && numel(map.z_mm)>1
        dx=median(diff(map.x_mm))/step;
        dz=median(diff(map.z_mm))/step;
        assert(abs(dx-dz)<=0.03*max(dx,dz), ...
            "swseval:AnisotropicPatch", ...
            "Cannot infer square patch width from anisotropic estimator axes.");
        width=n*(dx+dz)/2;
    end
end
if width==0
    warning("swseval:NoWindowWidth", ...
        "Patch width unavailable; spatially averaged metrics equal center metrics.");
end

[X,Z]=meshgrid(double(map.x_mm),double(map.z_mm));
raw=struct();
raw.r_squared=requiredMap(r,"r_squared",rz,rx);
raw.amplitude_f0_m=requiredMap(r,"amplitude_f0_m",rz,rx);
raw.residual_rms_m=requiredMap(r,"residual_rms_m",rz,rx);
raw.amplitude_to_residual_ratio=requiredMap(r,"amplitude_to_residual_ratio",rz,rx);
raw.correlation_mean=requiredMap(q,"correlation_mean",rz,rx);
raw.iq_rms=requiredMap(q,"iq_rms",rz,rx);

names=string(fieldnames(raw));aligned=struct();
for name=names'
    aligned.(name)=interp2(rx,rz,raw.(name),X,Z,"linear",NaN);
end
for name=["r_squared","amplitude_to_residual_ratio"]
    A=raw.(name);
    if width>0
        % A window-average describes the quality over the spectral patch.
        % No padding values contribute near acquisition boundaries.
        nz=max(1,round(width/median(diff(rz))));
        nx=max(1,round(width/median(diff(rx))));
        A=movmean(A,nz,1,"omitnan","Endpoints","shrink");
        A=movmean(A,nx,2,"omitnan","Endpoints","shrink");
    end
    aligned.(name+"_window")=interp2(rx,rz,A,X,Z,"linear",NaN);
end

D=struct("map",map,"quality",aligned, ...
    "frequency_hz",double(r.frequency_hz), ...
    "window_width_mm",width, ...
    "estimate_file",estimateFile, ...
    "temporal_file",temporalFile,"iq_file",iqFile);
end

function A=requiredMap(s,key,z,x)
assert(isfield(s,key),"swseval:MissingQualityField", ...
    "Missing signal-quality field: %s",key);
A=double(s.(key));
assert(isequal(size(A),[numel(z) numel(x)]), ...
    "swseval:InvalidQualityShape", ...
    "Quality field %s must have size [numel(z_m),numel(x_m)].",key);
end
