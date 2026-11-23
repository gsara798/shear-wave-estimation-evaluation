function out=predict_experimental_saved_features(original,model,names,modelID,modelFile)
%PREDICT_EXPERIMENTAL_SAVED_FEATURES Predict REQ SWS from saved Full21 patches.
% Reuses EXACT SAME raw wavefield, feature extraction, patch centers and
% quantile-to-wavenumber lookup from the original Full21 experiment.
% No wavefield reprocessing, spectral FFT, spatial filtering or quality mask.
%
% original: stage-02 result struct with patch_examples.req_mapping.
% model: reqml.training.fit_regression_model compatible regression struct.
% names: ordered predictor names (21 for clean Full21, 10 for legacy).
arguments
    original (1,1) struct
    model (1,1) struct
    names (:,1) string
    modelID (1,1) string
    modelFile (1,1) string
end
assert(all(isfield(original,["cs_map","q_map","valid_mask", ...
    "x_mm","z_mm","patch_examples","metadata"])), ...
    "AdaptiveREQ:ComparisonOriginalSchema", ...
    "Original Full21 must include maps, extracted patches and metadata.");
E=original.patch_examples;
required=[names;"req_mapping";"map_ix";"map_iz"; ...
    "campaign_frequency_hz";"example_id"];
assert(istable(E) && all(ismember(required, ...
    string(E.Properties.VariableNames))) && ...
    numel(unique(names))==numel(names), ...
    "AdaptiveREQ:ComparisonMissingSavedFeatures", ...
    "Stage-02 Full21 patches must preserve the 21/10 predictors "+ ...
    "and per-patch req_mapping.");
assert(numel(names)==numel(model.mu), ...
    "AdaptiveREQ:ComparisonPredictorOrder", ...
    "Fitted model expects a different feature count.");

X=double(table2array(E(:,cellstr(names))));
assert(size(X,2)==numel(names) && size(X,1)==height(E), ...
    "AdaptiveREQ:ComparisonFeatureShape","Invalid predictor matrix.");
finite=all(isfinite(X),2);
q=nan(height(E),1);
if any(finite)
    q(finite)=reqml.models.predictRegressionModel( ...
        model,X(finite,:),ClipRange=[.001 .999]);
end
sws=reqml.quantile.convertQPredictionsToSws(E,q);

sz=size(original.cs_map);
ix=double(E.map_ix(:));iz=double(E.map_iz(:));
assert(all(isfinite(ix) & isfinite(iz)) && ...
    all(ix==fix(ix) & iz==fix(iz)) && ...
    all(ix>=1 & ix<=sz(2) & iz>=1 & iz<=sz(1)), ...
    "AdaptiveREQ:ComparisonIndexBounds", ...
    "Saved patch map indices are incompatible with original map.");
idx=sub2ind(sz,iz,ix);
assert(numel(unique(idx))==height(E), ...
    "AdaptiveREQ:ComparisonDuplicatePatches", ...
    "Repeated patch locations in original SWS result.");

cs=nan(sz);qmap=nan(sz);valid=false(sz);
cs(idx)=double(sws.cs_pred_m_s);
qmap(idx)=double(q);
valid(idx)=logical(sws.sws_valid);
assert(isequal(size(cs),size(original.cs_map)) && ...
    isequal(size(valid),size(original.valid_mask)), ...
    "AdaptiveREQ:ComparisonMapShape","Model maps are not aligned.");

meta=original.metadata;
% Remove stale Full21 release metadata when it no longer represents
% the source estimator; retain only the shared physical acquisition keys.
for field=["release_id","model_file","model_name", ...
        "model_provenance_id","model_resolution", ...
        "experimental_model_release","experimental_inference_identity"]
    if isfield(meta,field),meta=rmfield(meta,field);end
end
meta.model_name="REQ comparison: "+modelID;
meta.model_provenance_id=modelID;
meta.model_file=modelFile;
meta.model_resolution="saved_original_full21_req_features";
meta.estimator="adaptive_req_comparison";
meta.predictor_names=names;
meta.valid_patch_count=nnz(valid);
meta.patch_count=numel(valid);
meta.experimental_mask_applied=false;
meta.experimental_feature_source="original_full21_saved_patches";
meta.experimental_reextracted=false;

% The mapping is already preserved in the IMMUTABLE original Full21
% result, and duplicating it makes each new MAT unnecessarily large.
E.req_mapping=[];
out=struct("cs_map",cs,"q_map",qmap,"valid_mask",valid, ...
    "x_mm",original.x_mm,"z_mm",original.z_mm, ...
    "patch_examples",E,"patch_predictions",sws,"metadata",meta);
end
