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

function testRoisAndReferenceTruth(testCase)
[r,t]=swsynth_comparison_rois("plane_homogeneous",1.8);
verifyEqual(testCase,numel(r),1);
verifyEqual(testCase,string(r.name),"center");
verifyEqual(testCase,double(r.center),[25 25]);
verifyEqual(testCase,double(r.size),[10 10]);
verifyEqual(testCase,t,1.8);
[r,t]=swsynth_comparison_rois("point_homogeneous",3);
verifyEqual(testCase,numel(r),1);
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
