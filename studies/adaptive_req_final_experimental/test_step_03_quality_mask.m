function tests=test_step_03_quality_mask
%TEST_STEP_03_QUALITY_MASK Fast synthetic structural tests; no real MAT data.
tests=functiontests(localfunctions);
end

function testMaskPartitionsOriginalValid(testCase)
[R,L]=fixtures();
Q=score_adaptive_req_full21_quality_mask(R,L);
verifyEqual(testCase,size(Q.risk_score_map),[2 2]);
verifyEqual(testCase,Q.original_valid_count,3);
verifyEqual(testCase,Q.invalid_count,1);
verifyEqual(testCase,Q.scored_count,2);
verifyEqual(testCase,Q.unscored_count,1);
verifyEqual(testCase,Q.retained_count+Q.rejected_count,2);
verifyTrue(testCase,all(isnan(Q.masked_sws_map(~Q.retained_mask)),"all"));
verifyTrue(testCase,all(isfinite(Q.risk_score_map( ...
    Q.retained_mask | Q.rejected_mask)),"all"));
verifyTrue(testCase,isnan(Q.risk_score_map(2,2)));
verifyEqual(testCase,Q.q_map,R.q_map);
end

function testLocalBaselineQuantileIsNotFull21(testCase)
[R,L]=fixtures();
% The feature extractor stores the local non-ML REQ baseline in E.q_pred.
% It need not match Full21 q_map and must never be used by the risk mask.
verifyNotEqual(testCase,double(R.patch_examples.q_pred(1)), ...
    double(R.patch_predictions.q_pred(1)));
Q=score_adaptive_req_full21_quality_mask(R,L);
verifyEqual(testCase,Q.q_map,R.q_map);
end

function testTamperedFull21QuantileRejected(testCase)
[R,L]=fixtures();
R.patch_predictions.q_pred(1)=.99;
verifyError(testCase,@()score_adaptive_req_full21_quality_mask(R,L), ...
    "AdaptiveREQ:MaskQMismatch");
end

function testWrongQModelRejected(testCase)
[R,L]=fixtures();
R.metadata.model_provenance_id="not_the_frozen_model";
verifyError(testCase,@()score_adaptive_req_full21_quality_mask(R,L), ...
    "AdaptiveREQ:MaskWrongRegressor");
end

function testMissingFrozenFeatureRejected(testCase)
[R,L]=fixtures();
R.patch_examples.feature_01=ones(4,2);
verifyError(testCase,@()score_adaptive_req_full21_quality_mask(R,L), ...
    "AdaptiveREQ:MaskFeatureShape");
end

function testDuplicateIndicesRejected(testCase)
[R,L]=fixtures();
R.patch_examples.map_ix(2)=1;
R.patch_examples.map_iz(2)=1;
verifyError(testCase,@()score_adaptive_req_full21_quality_mask(R,L), ...
    "AdaptiveREQ:MaskGridCoverage");
end

function [R,L]=fixtures()
old=rng;
cleanup=onCleanup(@()rng(old)); %#ok<NASGU>
rng(405174,"twister");
X=rand(32,22);
y=double(X(:,1)+0.1*X(:,22)>0.6);
classifier=fitctree(X,y,ClassNames=[0;1]);
names="feature_"+compose("%02d",1:21);
names=names(:);
E=table([1;2;1;2],[1;1;2;2], ...
    VariableNames=["map_ix","map_iz"]);
for k=1:21
    E.(char(names(k)))=0.25*ones(4,1);
end
% A legacy q_pred in the feature table means local REQ baseline q,
% NOT the fitted Full21 quantile; these values are intentionally different.
E.q_pred=0.5*ones(4,1);
% Window (2,2) has a finite base SWS but a nonfinite feature -> unscored.
E.feature_01(4)=NaN;
% These entries map in E row order to the q_map (MATLAB column major).
P=table([.4;.6;NaN;.7],VariableNames="q_pred");
R=struct( ...
    "cs_map",[2.0 2.4;NaN 3.0], ...
    "q_map",[0.4 0.6;NaN 0.7], ...
    "valid_mask",logical([1 1;0 1]), ...
    "x_mm",[10 15], ...
    "z_mm",[5;10], ...
    "patch_examples",E, ...
    "patch_predictions",P, ...
    "metadata",struct( ...
        "model_provenance_id","frozen_full21_fixture", ...
        "experimental_mask_applied",false));
L=struct( ...
    "classifier",classifier, ...
    "predictor_names",names, ...
    "mask_predictor_names",[names;"reqml_q_pred"], ...
    "cutoff",0.5, ...
    "regression_model_id","frozen_full21_fixture", ...
    "release_id","adaptive_req_full21_v1");
end
