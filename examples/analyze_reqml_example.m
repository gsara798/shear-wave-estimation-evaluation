% Edit the file path to an existing M2 or M3 REQ-ML estimate.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src'));
file="/path/to/estimates/run/REQ-ML/candidate10/400Hz/M2/reqml_result.mat";
map=swseval.io.loadReqmlResult(file);
rois=[swseval.roi.rectangle("ROI1",Center=[18 24],Size=[7 7],Units="mm"), ...
 swseval.roi.rectangle("ROI2",Center=[30 24],Size=[7 7],Units="mm")];
T=swseval.analyzeROIs(map,rois,OutputDir=fullfile(root,'results','example'), ...
 SWSColorLimits=[1 4]);
disp(T);
