function rois=sp_comparison_rois(experiment)
%SP_COMPARISON_ROIS Fixed physical ROIs: one central homogeneous; two bilayer.
% The central 16 x 14 mm rectangle spans x=[10,26], z=[11,25] mm.
% These physical coordinates are deliberately independent of the model arm.
arguments
    experiment (1,1) string
end
assert(endsWith(experiment,"_sp"),"SPCompare:ROIExperiment", ...
    "Expected an SP experiment: %s",experiment);
if contains(experiment,"_homo_")
    rois=swseval.roi.rectangle("central", ...
        Center=[18 18],Size=[16 14],Units="mm");
elseif contains(experiment,"_dl_")
    rois=[swseval.roi.rectangle("ROI1", ...
            Center=[18 10],Size=[10 5],Units="mm"), ...
          swseval.roi.rectangle("ROI2", ...
            Center=[18 25],Size=[10 5],Units="mm")];
else
    error("SPCompare:ROIExperiment", ...
        "No ROI policy for experiment %s",experiment);
end
end
