function rois=sp_comparison_rois(experiment)
%SP_COMPARISON_ROIS Fixed physical ROIs: one central homogeneous; two bilayer.
% Homogeneous: central 17x15 mm at [19,19.25] mm. Bilayer: 14.2x3.2 mm ROIs, interior of layers.
% Bilayer z-ranges [11.4,14.6] and [22.4,25.6] mm avoid the interface;
% actual pixel counts must be checked for each acquisition.
% These physical coordinates are deliberately independent of the model arm.
arguments
    experiment (1,1) string
end
assert(endsWith(experiment,"_sp"),"SPCompare:ROIExperiment", ...
    "Expected an SP experiment: %s",experiment);
if contains(experiment,"_homo_")
    rois=swseval.roi.rectangle("central", ...
        Center=[19 19.25],Size=[17 15],Units="mm");
elseif contains(experiment,"_dl_")
    rois=[swseval.roi.rectangle("ROI1", ...
            Center=[19 13],Size=[14.2 3.2],Units="mm"), ...
          swseval.roi.rectangle("ROI2", ...
            Center=[19 24],Size=[14.2 3.2],Units="mm")];
else
    error("SPCompare:ROIExperiment", ...
        "No ROI policy for experiment %s",experiment);
end
end
