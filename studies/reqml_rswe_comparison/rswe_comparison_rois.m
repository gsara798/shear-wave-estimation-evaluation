function rois=rswe_comparison_rois(experiment)
%RSWE_COMPARISON_ROIS Fixed physical ROIs: one central homogeneous; two bilayer.
% Homogeneous: central 16x14 mm. Bilayer: 16.2x2 mm ROI per layer.
% Bilayer positions fit the common 300-600 Hz spatial support in SP;
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
            Center=[18 11.5],Size=[16.2 2],Units="mm"), ...
          swseval.roi.rectangle("ROI2", ...
            Center=[18 24.2],Size=[16.2 2],Units="mm")];
else
    error("RSWECompare:ROIExperiment", ...
        "No ROI policy for experiment %s",experiment);
end
end
