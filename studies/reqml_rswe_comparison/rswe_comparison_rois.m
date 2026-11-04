function rois=rswe_comparison_rois(experiment)
%RSWE_COMPARISON_ROIS Fixed physical ROIs: one central homogeneous; two bilayer.
% Homogeneous: central 16x14 mm. Bilayer: 14.2x2.4 mm ROIs, interior of layers.
% Bilayer positions are centralized within each 300 Hz layer plateau;
% actual pixel counts must be checked for each acquisition.
% These physical coordinates are deliberately independent of the model arm.
arguments
    experiment (1,1) string
end
assert(endsWith(experiment,"_rswe"),"RSWECompare:ROIExperiment", ...
    "Expected an RSWE experiment: %s",experiment);
if contains(experiment,"_homo_")
    rois=swseval.roi.rectangle("central", ...
        Center=[18 18],Size=[16 14],Units="mm");
elseif contains(experiment,"_dl_")
    rois=[swseval.roi.rectangle("ROI1", ...
            Center=[19 15],Size=[14.2 2.4],Units="mm"), ...
          swseval.roi.rectangle("ROI2", ...
            Center=[19 22.5],Size=[14.2 2.4],Units="mm")];
else
    error("RSWECompare:ROIExperiment", ...
        "No ROI policy for experiment %s",experiment);
end
end
