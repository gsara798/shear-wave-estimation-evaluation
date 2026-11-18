function spec=adaptive_req_final_case_rois(caseID)
%ADAPTIVE_REQ_FINAL_CASE_ROIS Return frozen physical ROIs from QMV2 manifest.
% Reuses the empirically selected 2026 phantom ROI geometry. For inclusion,
% keep only inclusion_core and background_ref (omit exploratory large ROI).
arguments
    caseID (1,1) string
end
studyDir=string(fileparts(mfilename("fullpath")));
manifest=fullfile(studyDir,"..","reqml_experimental_qmv2", ...
    "experiment_manifest.example.json");
assert(isfile(manifest),"AdaptiveREQ:PlotMissingROIManifest", ...
    "Cannot locate earlier physical ROI manifest: %s",manifest);
J=jsondecode(fileread(manifest));
idx=find(string({J.cases.id})==caseID);
assert(isscalar(idx),"AdaptiveREQ:PlotUnknownCase", ...
    "Expected exactly one ROI definition for %s.",caseID);
C=J.cases(idx);
assert(isfield(C,"rois") && ~isempty(C.rois), ...
    "AdaptiveREQ:PlotNoROIs","No previously defined ROIs for %s.",caseID);
names=string({C.rois.name});
switch string(C.type)
    case "homogeneous"
        selected="central";
    case "bilayer"
        selected=["soft","hard"];
    case "inclusion"
        selected=["inclusion_core","background_ref"];
    otherwise
        error("AdaptiveREQ:PlotPhantomType", ...
            "Unknown physical phantom type: %s",string(C.type));
end
assert(numel(unique(names))==numel(names) && ...
    all(ismember(selected,names)), ...
    "AdaptiveREQ:PlotROIContract", ...
    "The saved ROI manifest lacks required %s ROIs.",string(C.type));
rois=C.rois(ismember(names,selected));
[~,ord]=ismember(selected,string({rois.name}));
rois=rois(ord);
for k=1:numel(rois)
    center=double(rois(k).center_mm(:)');
    sz=double(rois(k).size_mm(:)');
    assert(numel(center)==2 && numel(sz)==2 && ...
        all(isfinite([center sz])) && all(sz>0), ...
        "AdaptiveREQ:PlotROIShape","ROI %s has invalid physical geometry.", ...
        string(rois(k).name));
end
spec=struct("case_id",caseID,"phantom_type",string(C.type), ...
    "rois",rois,"roi_manifest",manifest, ...
    "roi_names",selected);
end
