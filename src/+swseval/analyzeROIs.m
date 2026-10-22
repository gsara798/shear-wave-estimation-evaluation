function T=analyzeROIs(map,rois,options)
%ANALYZEROIS ROI statistics and matching ROI-overlay figure.
arguments
 map (1,1) struct
 rois (1,:) struct
 options.OutputDir (1,1) string = ""
 options.SWSColorLimits (1,:) double = []
end
map=swseval.io.validateMap(map);
T=swseval.metrics.roiStatistics(map,rois);
if options.OutputDir~=""
 if ~isfolder(options.OutputDir),mkdir(options.OutputDir);end
 writetable(T,fullfile(options.OutputDir,'roi_statistics.csv'));
 save(fullfile(options.OutputDir,'roi_analysis.mat'),'T','rois','-v7.3');
 swseval.viz.renderROIs(map,rois,fullfile(options.OutputDir,'sws_with_rois'), ...
  SWSColorLimits=options.SWSColorLimits);
end
end
