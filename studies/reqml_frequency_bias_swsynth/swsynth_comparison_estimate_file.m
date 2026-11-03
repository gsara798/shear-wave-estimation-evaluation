function dest=swsynth_comparison_estimate_file(C,row,arm)
%SWSYNTH_COMPARISON_ESTIMATE_FILE Isolate StepPixels without losing old runs.
% Historical M<M>/reqml_result.mat files are reused only when their saved
% identity records the SAME StepPixels. Other steps use M<M>/step<N>/.
arguments
    C (1,1) struct
    row (1,:) table
    arm (1,1) string
end
base=fullfile(C.outputRoot,"estimates",row.series(1), ...
    "REQ-ML",arm,sprintf("%gHz",row.frequency_hz(1)), ...
    "M"+string(C.M));
legacy=fullfile(base,"reqml_result.mat");
if isfile(legacy)
    saved=load(legacy,"comparison_identity");
    if isfield(saved,"comparison_identity")
        try
            identity=jsondecode(char(string(saved.comparison_identity)));
            if isstruct(identity) && isfield(identity,"step_pixels") && ...
                    isnumeric(identity.step_pixels) && ...
                    isscalar(identity.step_pixels) && ...
                    double(identity.step_pixels)==C.StepPixels
                dest=legacy;
                return
            end
        catch
            % An unreadable legacy identity must never be overwritten.
        end
    end
end
dest=fullfile(base,"step"+string(C.StepPixels),"reqml_result.mat");
end
