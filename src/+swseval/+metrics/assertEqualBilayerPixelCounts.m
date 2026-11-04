function n=assertEqualBilayerPixelCounts(T,roiNames,models,frequencies)
%ASSERTEQUALBILAYERPIXELCOUNTS Verify bilayer ROI sampling is frequency balanced.
% Matching integer counts is necessary, but grid centers can still differ
% slightly in physical location when frequency changes (e.g. half-pixel shift).
% This checks selected geometrical pixels. Masked-invalid pixels are reported.
arguments
    T table
    roiNames (1,:) string
    models (1,:) string
    frequencies (1,:) double
end
required=["name","model","frequency_hz","selected_pixels","valid_pixels"];
assert(all(ismember(required,string(T.Properties.VariableNames))), ...
    "swseval:ROIPixelSchema","Expected ROI pixel-count columns.");
assert(~isempty(roiNames) && ~isempty(models) && ~isempty(frequencies), ...
    "swseval:ROIPixelConfig","ROI names, models and frequencies are required.");
assert(height(T)==numel(roiNames)*numel(models)*numel(frequencies), ...
    "swseval:ROIPixelRows","Unexpected ROI/model/frequency rows.");
n=NaN;
for roi=roiNames
    for model=models
        R=T(string(T.name)==roi & string(T.model)==model,:);
        R=sortrows(R,"frequency_hz");
        assert(height(R)==numel(frequencies) && ...
            isequal(double(R.frequency_hz(:)),sort(frequencies(:))), ...
            "swseval:ROIPixelCoverage", ...
            "Missing or duplicated ROI sampling for %s / %s.",roi,model);
        counts=double(R.selected_pixels(:));
        assert(all(isfinite(counts)) && all(counts>0), ...
            "swseval:EmptyROIPixels", ...
            "ROI %s / %s has no selected pixels.",roi,model);
        if isnan(n),n=counts(1);end
        assert(all(counts==n), ...
            "swseval:InconsistentROIPixels", ...
            "ROI %s / %s has selected pixels %s (expected %g at every frequency).", ...
            roi,model,mat2str(counts'),n);
        actual=double(R.valid_pixels(:));
        if any(actual~=n)
            warning("swseval:UnequalValidROIPixels", ...
                "ROI %s / %s selected %g pixels at every frequency, " + ...
                "but usable pixels are %s due to valid masks.", ...
                roi,model,n,mat2str(actual'));
        end
    end
end
fprintf("Bilayer: %g selected pixels per ROI at every frequency/arm.\n",n);
end
