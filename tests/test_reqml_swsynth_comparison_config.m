function tests=test_reqml_swsynth_comparison_config
% No synthesis, filtering, inference or file writes.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
repo=string(fileparts(fileparts(mfilename("fullpath"))));
testCase.TestData.study=fullfile(repo,"studies", ...
    "reqml_frequency_bias_swsynth");
addpath(testCase.TestData.study,"-begin");
addpath(fullfile(repo,"src"),"-begin");
end

function testFrozenCasesAndArms(testCase)
C=swsynth_comparison_config(ReqmlRoot="/nonexistent/readonly");
verifyEqual(testCase,height(C.Cases),20);
verifyEqual(testCase,numel(unique(C.Cases.series)),5);
verifyEqual(testCase,numel(C.Arms),7);
verifyEqual(testCase,C.FilterCsMin,0.8);
verifyEqual(testCase,C.FilterCsMax,8);
verifyEqual(testCase,C.FilterTaper,0.06,"AbsTol",1e-14);
verifyEqual(testCase,C.M,2);
verifyEqual(testCase,C.StepPixels,2);
verifyEqual(testCase,nnz(C.Inputs=="raw"),3);
verifyEqual(testCase,nnz(C.Inputs=="filtered"),4);
verifyTrue(testCase,startsWith(C.outputRoot,C.studyRoot));
end

function testReduced14OptInAndLegacyCompatibility(testCase)
% The exploratory model only adds an opt-in raw arm; frozen defaults stay.
legacy=swsynth_comparison_config(ReqmlRoot="/nonexistent/readonly");
verifyEqual(testCase,numel(legacy.Arms),7);
verifyEqual(testCase,legacy.analysisRoot, ...
    fullfile(legacy.outputRoot,"analysis","roi_homo30x30_v2"));
C=swsynth_comparison_config( ...
    ReqmlRoot="/nonexistent/readonly",Arms="reduced14",StepPixels=5);
verifyEqual(testCase,C.Arms,"reduced14");
verifyEqual(testCase,C.Inputs,"raw");
verifyEqual(testCase,C.ModelPaths, ...
    fullfile("/nonexistent/readonly","training","q0_v5_clean_campaign", ...
    "outputs","reduced14_transfer_bundle_v1","model_bundle.mat"));
verifyTrue(testCase,contains(C.analysisRoot,"alternatives"));
verifyEqual(testCase,numel(C.AllArms),17); % Existing nine + eight opt-in QMV2 arms
% New arm reuses the *same* frozen regressor on a filtered complex field.
filtered=swsynth_comparison_config( ...
    ReqmlRoot="/nonexistent/readonly",Arms="reduced14_filtered",StepPixels=5);
verifyEqual(testCase,filtered.Inputs,"filtered");
verifyEqual(testCase,filtered.ModelPaths,C.ModelPaths);
verifyEqual(testCase,C.Frequencies,[300 400 500 600]);
allArms=[legacy.Arms,"reduced14"];
combined=swsynth_comparison_config( ...
    ReqmlRoot="/nonexistent/readonly",Arms=allArms,StepPixels=5);
verifyEqual(testCase,combined.Inputs(end),"raw");
verifyEqual(testCase,numel(combined.Inputs),8);
verifyTrue(testCase,contains(combined.analysisRoot,"step5_"));
end

function testRoisAndReferenceTruth(testCase)
[r,t]=swsynth_comparison_rois("plane_homogeneous",1.8);
verifyEqual(testCase,numel(r),1);
verifyEqual(testCase,string(r.name),"center");
verifyEqual(testCase,double(r.center),[25 25]);
verifyEqual(testCase,double(r.size),[30 30]);
verifyEqual(testCase,double(r.center-r.size/2),[10 10]);
verifyEqual(testCase,double(r.center+r.size/2),[40 40]);
verifyEqual(testCase,t,1.8);
[r,t]=swsynth_comparison_rois("point_homogeneous",3);
verifyEqual(testCase,numel(r),1);
verifyEqual(testCase,double(r.size),[30 30]);
verifyEqual(testCase,t,3);
[r,t]=swsynth_comparison_rois("plane_bilayer",1.8);
verifyEqual(testCase,numel(r),2);
verifyEqual(testCase,string({r.name}),["soft","hard"]);
verifyEqual(testCase,t,[1.8 3]);
verifyEqual(testCase,double(r(1).center),[25 12.5]);
verifyEqual(testCase,double(r(2).center),[25 37.5]);
% Neither 5-mm-tall ROI intersects the boundary at z=25 mm.
verifyLessThan(testCase,r(1).center(2)+r(1).size(2)/2,25);
verifyGreaterThan(testCase,r(2).center(2)-r(2).size(2)/2,25);
end

function testReadOnlyPlan(testCase)
T=run_swsynth_comparison(Stage="plan", ...
    ReqmlRoot="/nonexistent/readonly", ...
    Arms=["A_raw_v1","C_filtered_v2","candidate10_filtered"]);
verifyEqual(testCase,height(T),20);
verifyTrue(testCase,all(ismember( ...
    ["simulation_done","filtered_done"], ...
    string(T.Properties.VariableNames))));
end

function testStepSpecificEstimatePaths(testCase)
% Switching from an old StepPixels=2 file to a new step must preserve it.
output=string(tempname);
mkdir(output);
cleanup=onCleanup(@()rmdir(output,"s")); %#ok<NASGU>
C=swsynth_comparison_config(OutputRoot=output, ...
    ReqmlRoot="/nonexistent/readonly");
row=C.Cases(1,:);
base=fullfile(output,"estimates",row.series(1), ...
    "REQ-ML","A_raw_v1",sprintf("%gHz",row.frequency_hz(1)),"M2");
legacy=fullfile(base,"reqml_result.mat");
newDefault=swsynth_comparison_estimate_file(C,row,"A_raw_v1");
verifyEqual(testCase,newDefault,fullfile(base,"step2","reqml_result.mat"));
if ~isfolder(base),mkdir(base);end
comparison_identity=string(jsonencode(struct( ...
    "step_pixels",2,"M",2))); %#ok<NASGU>
save(legacy,"comparison_identity");
verifyEqual(testCase, ...
    swsynth_comparison_estimate_file(C,row,"A_raw_v1"),legacy);
C.StepPixels=1;
verifyEqual(testCase, ...
    swsynth_comparison_estimate_file(C,row,"A_raw_v1"), ...
    fullfile(base,"step1","reqml_result.mat"));
C.StepPixels=4;
verifyEqual(testCase, ...
    swsynth_comparison_estimate_file(C,row,"A_raw_v1"), ...
    fullfile(base,"step4","reqml_result.mat"));
verifyTrue(testCase,isfile(legacy));
end
