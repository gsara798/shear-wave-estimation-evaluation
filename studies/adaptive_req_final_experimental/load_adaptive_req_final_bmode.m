function B=load_adaptive_req_final_bmode(manifestFile,swsMap)
%LOAD_ADAPTIVE_REQ_FINAL_BMODE Read original Verasonics B-mode only.
% Uses EWP's recorded processing_manifest.source_file: no filename guessing.
% Physical overlay is allowed ONLY when B-mode shares the IQData1 grid.
% Reading IQData1 frames is prohibited; only metadata plus 2D B-mode load.
arguments
    manifestFile (1,1) string
    swsMap (1,1) struct
end
B=struct("available",false,"reason","", ...
    "source_file","","image_db",[], ...
    "x_mm",[],"z_mm",[]);
if ~isfile(manifestFile)
    B.reason="processing_manifest.json missing";return
end
J=jsondecode(fileread(manifestFile));
if ~isfield(J,"source_file") || strlength(string(J.source_file))==0
    B.reason="processing manifest has no raw source_file";return
end
source=string(J.source_file);
B.source_file=source;
if ~isfile(source)
    B.reason="original Verasonics raw MAT unavailable";return
end

% All M values for the same acquisition reuse this B-mode in a MATLAB run.
persistent previousSource previousInfo previousBmode
stamp=dir(source);
fingerprint=string(source)+"|"+string(stamp.bytes)+"|"+ ...
    string(stamp.datenum);
if isempty(previousSource) || previousSource~=fingerprint
    tmp=struct("available",false,"reason","", ...
        "source_file",source,"image_db",[], ...
        "x_mm",[],"z_mm",[]);
    % Mirrors ewp.viz.renderBmodeAcquisition source naming and grid policy.
    names=string(who("-file",char(source)));
    alternatives=["IQBmodeData","BmodeIQ"];
    var=alternatives(find(ismember(alternatives,names),1));
    if isempty(var)
        tmp.reason="B-mode IQ variable IQBmodeData/BmodeIQ is absent";
    else
        S=load(source,char(var),"dinf");
        zxi=S.(char(var));
        if ~isnumeric(zxi) || ~ismatrix(zxi) || isempty(zxi)
            tmp.reason="B-mode is not a numeric 2D IQ array";
        elseif ~isfield(S,"dinf") || ...
                ~isfield(S.dinf,"dx") || ~isfield(S.dinf,"dz") || ...
                ~isscalar(S.dinf.dx) || ~isscalar(S.dinf.dz) || ...
                ~isfinite(double(S.dinf.dx)) || ...
                ~isfinite(double(S.dinf.dz)) || ...
                double(S.dinf.dx)<=0 || double(S.dinf.dz)<=0
            tmp.reason="B-mode sampling metadata dinf.dx/dz is missing";
        else
            % Size comparison of metadata only; never load the IQ movie.
            iq=whos("-file",char(source),"IQData1");
            [nz,nx]=size(zxi);
            sameGrid=~isempty(iq) && numel(iq.size)>=2 && ...
                isequal(double(iq.size(1:2)),[nz nx]);
            if ~sameGrid
                tmp.reason="B-mode and displacement IQ grids differ";
            else
                amplitude=abs(double(zxi));
                amplitude(~isfinite(amplitude))=0;
                peak=max(amplitude(:));
                if peak<=0
                    tmp.reason="B-mode has no positive finite IQ amplitude";
                else
                    tmp.image_db=20*log10(max(amplitude/peak,1e-3));
                    tmp.x_mm=(0:nx-1)*double(S.dinf.dx)*1e3;
                    tmp.z_mm=(0:nz-1)*double(S.dinf.dz)*1e3;
                    tmp.available=true;
                end
            end
        end
    end
    previousSource=fingerprint;
    previousInfo=stamp; %#ok<NASGU>
    previousBmode=tmp;
end
B=previousBmode;

% Independently verify the SWS map lies in the original physical B-mode FOV.
if B.available
    assert(isfield(swsMap,"x_mm") && isfield(swsMap,"z_mm"), ...
        "AdaptiveREQ:PlotMapCoords","SWS map lacks physical coordinates.");
    xx=double(swsMap.x_mm(:));
    zz=double(swsMap.z_mm(:));
    ok=all(isfinite([xx;zz])) && ...
        all(xx>=min(B.x_mm)-1e-5 & xx<=max(B.x_mm)+1e-5) && ...
        all(zz>=min(B.z_mm)-1e-5 & zz<=max(B.z_mm)+1e-5);
    if ~ok
        B.available=false;
        B.reason="SWS coordinate extent falls outside physical B-mode grid";
    end
end
end
