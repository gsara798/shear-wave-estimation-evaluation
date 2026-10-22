function T=analyzeROIs(map,rois,options)
%ANALYZEROIS ROI statistics and matching ROI-overlay figure.
arguments
 map (1,1) struct
 rois (1,:) struct
 options.OutputDir (1,1) string = ""
 options.SWSColorLimits (1,:) double = []
 options.FigureBaseName (1,1) string = "sws_with_rois"
 options.ColorbarDecimals (1,1) double {mustBeInteger,mustBeNonnegative} = 1
 options.ShowTitles (1,1) logical = false
end
map=swseval.io.validateMap(map);
T=swseval.metrics.roiStatistics(map,rois);
if options.OutputDir~=""
 if ~isfolder(options.OutputDir),mkdir(options.OutputDir);end
 writetable(T,fullfile(options.OutputDir,'roi_statistics.csv'));
 save(fullfile(options.OutputDir,'roi_analysis.mat'),'T','rois','-v7.3');
 swseval.viz.renderROIs(map,rois,fullfile(options.OutputDir,options.FigureBaseName), ...
  SWSColorLimits=options.SWSColorLimits, ...
  ColorbarDecimals=options.ColorbarDecimals,ShowTitles=options.ShowTitles);
end
end
