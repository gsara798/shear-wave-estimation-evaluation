function tests=test_qmv2_swsynth_transfer_config
% Pure configuration tests; no model fitting, wave synthesis, or disk writes.
tests=functiontests(localfunctions);
end

function setupOnce(tc)
repo=string(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(repo,"studies","reqml_frequency_bias_swsynth"),"-begin");
addpath(fullfile(repo,"src"),"-begin");
tc.TestData.root=repo;
end

function testNewEightArmsUseCorrectFiltersAndBundles(tc)
sets=["reduced14","reduced14_frequency", ...
    "expanded20","expanded20_frequency"];
arms=["qmv2_unfiltered_"+sets, ...
    "qmv2_fixed_donut_"+sets];
C=swsynth_comparison_config(Arms=arms, ...
    ReqmlRoot="/nonexistent/qmv2_readonly",M=2,StepPixels=5);
verifyEqual(tc,C.Arms,arms);
verifyEqual(tc,C.Inputs,[repmat("raw",1,4),repmat("filtered",1,4)]);
verifyEqual(tc,numel(C.Cases.case_id),20);
verifyEqual(tc,C.Frequencies,[300 400 500 600]);
verifyEqual(tc,C.FilterCsMin,0.8);
verifyEqual(tc,C.FilterCsMax,8);
verifyEqual(tc,C.FilterTaper,0.06,"AbsTol",1e-14);
verifyEqual(tc,C.StepPixels,5);
for i=1:8
    arm="unfiltered";
    if i>4,arm="fixed_donut";end
    set=sets(mod(i-1,4)+1);
    expected=fullfile("/nonexistent/qmv2_readonly", ...
        "training","quality_mask_v2_campaign","outputs", ...
        "full_clean_plane_v2","postprocess_v1", ...
        "quantile_oof_M1to3_v1",arm,"transfer_bundles_v1", ...
        set,"model_bundle.mat");
    verifyEqual(tc,C.ModelPaths(i),expected);
end
verifyTrue(tc,contains(C.analysisRoot,"armIDs_"));
verifyTrue(tc,endsWith(C.analysisRoot,"roi_homo30x30_v2"));
verifyEqual(tc,C.ROIPolicy,"homo_center_30x30_mm_v2");
verifyLessThan(tc,strlength(string(C.analysisRoot)),260);
end

function testNewVsFrozenComparisonDoesNotChangeDefaults(tc)
classic=swsynth_comparison_config( ...
    ReqmlRoot="/nonexistent/qmv2_readonly");
verifyEqual(tc,numel(classic.Arms),7);
verifyEqual(tc,classic.analysisRoot, ...
    fullfile(classic.outputRoot,"analysis","roi_homo30x30_v2"));
arms=["reduced14","reduced14_filtered", ...
    "qmv2_unfiltered_reduced14", ...
    "qmv2_unfiltered_reduced14_frequency", ...
    "qmv2_unfiltered_expanded20", ...
    "qmv2_unfiltered_expanded20_frequency", ...
    "qmv2_fixed_donut_reduced14", ...
    "qmv2_fixed_donut_reduced14_frequency", ...
    "qmv2_fixed_donut_expanded20", ...
    "qmv2_fixed_donut_expanded20_frequency"];
C=swsynth_comparison_config(Arms=arms,M=2,StepPixels=5, ...
    ReqmlRoot="/nonexistent/qmv2_readonly");
verifyEqual(tc,C.Inputs, ...
    ["raw","filtered",repmat("raw",1,4),repmat("filtered",1,4)]);
verifyNotEqual(tc,C.analysisRoot,classic.analysisRoot);
verifyEqual(tc,numel(unique(C.ModelPaths)),9);
% Frozen Reduced14 uses one model on two input arms; QMV2 uses 8 distinct.
verifyEqual(tc,C.ModelPaths(1),C.ModelPaths(2));
verifyEqual(tc,numel(unique(C.Arms)),10);
end

function testPlanPreservesFrozenCases(tc)
arms=["reduced14","qmv2_unfiltered_expanded20_frequency"];
P=run_swsynth_comparison(Stage="plan", ...
    Arms=arms,M=2,StepPixels=5, ...
    ReqmlRoot="/nonexistent/qmv2_readonly");
verifyEqual(tc,height(P),20);
verifyEqual(tc,numel(unique(P.series)),5);
verifyEqual(tc,unique(P.frequency_hz)',[300 400 500 600]);
end

function testCompactPlotLabelsAndNewHomogeneousROI(tc)
arms=["reduced14","reduced14_filtered", ...
    "qmv2_unfiltered_reduced14", ...
    "qmv2_unfiltered_reduced14_frequency", ...
    "qmv2_unfiltered_expanded20", ...
    "qmv2_unfiltered_expanded20_frequency", ...
    "qmv2_fixed_donut_reduced14", ...
    "qmv2_fixed_donut_reduced14_frequency", ...
    "qmv2_fixed_donut_expanded20", ...
    "qmv2_fixed_donut_expanded20_frequency"];
labels=swsynth_short_model_names(arms);
verifyEqual(tc,numel(labels),10);
verifyEqual(tc,numel(unique(labels)),10);
verifyEqual(tc,labels(1:2),["R14 raw","R14 donut"]);
verifyEqual(tc,labels(end-1:end),["Q20 donut","Q20+f donut"]);
verifyTrue(tc,all(strlength(labels)<18));
[r,truth]=swsynth_comparison_rois("point_homogeneous",3);
verifyEqual(tc,numel(r),1);
verifyEqual(tc,double(r.center),[25 25]);
verifyEqual(tc,double(r.size),[30 30]);
verifyEqual(tc,truth,3);
[r,truth]=swsynth_comparison_rois("plane_bilayer",1.8);
verifyEqual(tc,numel(r),2);
verifyEqual(tc,double(r(1).size),[10 5]);
verifyEqual(tc,double(r(2).size),[10 5]);
verifyEqual(tc,truth,[1.8 3]);
end
