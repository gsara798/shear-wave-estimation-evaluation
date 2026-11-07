function [rois,truth]=swsynth_comparison_rois(caseGroup,homogeneousCs)
%SWSYNTH_COMPARISON_ROIS One central ROI for homogeneous, two layer ROIs.
% Coordinates in mm relative to the 0-50 mm simulation observation FOV.
% Homogeneous v2: predetermined 30 x 30 mm central ROI (x,z = 10..40 mm)
% samples the full central low-amplitude/interference band and surrounding
% areas consistently across models, without selecting by prediction error.
% Bilayer ROIs are deliberately unchanged and avoid the interface.
arguments
    caseGroup (1,1) string
    homogeneousCs (1,1) double
end
if caseGroup=="plane_bilayer"
    rois=[swseval.roi.rectangle("soft",Center=[25 12.5], ...
        Size=[10 5],Units="mm"), ...
        swseval.roi.rectangle("hard",Center=[25 37.5], ...
        Size=[10 5],Units="mm")];
    truth=[1.8 3];
elseif caseGroup=="plane_homogeneous" || caseGroup=="point_homogeneous"
    rois=swseval.roi.rectangle("center",Center=[25 25], ...
        Size=[30 30],Units="mm");
    truth=homogeneousCs;
else
    error("SynthCompare:UnknownGroup","Unexpected group %s.",caseGroup);
end
end
