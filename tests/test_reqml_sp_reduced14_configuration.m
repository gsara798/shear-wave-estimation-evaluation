function tests=test_reqml_sp_reduced14_configuration
% Configuration tests only: no EWP, model loading, or experimental files.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
repo=string(fileparts(fileparts(mfilename("fullpath"))));
testCase.TestData.repo=repo;
addpath(fullfile(repo,"studies","reqml_sp_comparison"),"-begin");
end

function testLegacySevenArmDefaultsUnchanged(testCase)
repo=testCase.TestData.repo;
c=sp_comparison_config(ReqmlRoot=repo,EvalRoot=repo,EwpRoot=repo);
verifyEqual(testCase,numel(c.arms),7);
verifyEqual(testCase,c.arms,c.legacyArms);
verifyEqual(testCase,c.inputKinds, ...
    ["raw","filtered","filtered","raw","raw","filtered","filtered"]);
verifyEqual(testCase,c.analysisName,c.comparisonName);
verifyEqual(testCase,c.StepPixels,2);
verifyEqual(testCase,c.M,2);
verifyEqual(testCase,c.modelPaths(1),c.v1);
verifyEqual(testCase,c.modelPaths(3),c.v2Bundle);
verifyEqual(testCase,c.modelPaths(4),c.candidate10);
verifyEqual(testCase,c.modelPaths(5),c.candidate);
end

function testReduced14ArmsReuseSameFittedBundle(testCase)
repo=testCase.TestData.repo;
c=sp_comparison_config(ReqmlRoot=repo,EvalRoot=repo,EwpRoot=repo, ...
    Arms=["reduced14","reduced14_filtered"]);
verifyEqual(testCase,c.arms,["reduced14","reduced14_filtered"]);
verifyEqual(testCase,c.inputKinds,["raw","filtered"]);
verifyEqual(testCase,c.modelPaths, ...
    [c.reduced14Bundle;c.reduced14Bundle]);
verifyEqual(testCase,c.reduced14Bundle, ...
    fullfile(repo,"training","q0_v5_clean_campaign","outputs", ...
        "reduced14_transfer_bundle_v1","model_bundle.mat"));
verifyNotEqual(testCase,c.analysisName,c.comparisonName);
verifyEqual(testCase,c.csMin,0.8);
verifyEqual(testCase,c.csMax,8);
verifyEqual(testCase,c.taper,0.06,"AbsTol",1e-14);
end

function testNineArmAnalysisIsIsolated(testCase)
repo=testCase.TestData.repo;
legacy=sp_comparison_config(ReqmlRoot=repo,EvalRoot=repo,EwpRoot=repo);
full=sp_comparison_config(ReqmlRoot=repo,EvalRoot=repo,EwpRoot=repo, ...
    Arms=[legacy.arms,"reduced14","reduced14_filtered"]);
verifyEqual(testCase,numel(full.arms),9);
verifyEqual(testCase,full.arms,full.allArms);
verifyEqual(testCase,full.comparisonName,legacy.comparisonName);
verifyNotEqual(testCase,full.analysisName,legacy.analysisName);
verifyTrue(testCase,endsWith(full.analysisName,"reduced14_9arms_v1"));
verifyEqual(testCase,full.modelPaths(1:7),legacy.modelPaths);
verifyEqual(testCase,full.inputKinds(1:7),legacy.inputKinds);
end

function testFourArmFeatureFilterComparisonIsIsolated(testCase)
repo=testCase.TestData.repo;
c=sp_comparison_config(ReqmlRoot=repo,EvalRoot=repo,EwpRoot=repo, ...
    Arms=["A_raw_v1","reduced14","B_filtered_v1","reduced14_filtered"]);
verifyEqual(testCase,c.arms,c.fourArms);
verifyEqual(testCase,numel(c.arms),4);
verifyEqual(testCase,c.inputKinds,["raw","raw","filtered","filtered"]);
verifyEqual(testCase,c.modelPaths, ...
    [c.v1;c.reduced14Bundle;c.v1;c.reduced14Bundle]);
verifyTrue(testCase,endsWith(c.analysisName,"reduced14_4arms_v1"));
verifyNotEqual(testCase,c.analysisName,c.comparisonName);
verifyEqual(testCase,c.M,2);
verifyEqual(testCase,c.StepPixels,2);
verifyEqual(testCase,c.Frequencies,[300 400 500 600]);
end

function testInvalidArmSelectionsRejected(testCase)
repo=testCase.TestData.repo;
verifyError(testCase,@() sp_comparison_config( ...
    ReqmlRoot=repo,EvalRoot=repo,EwpRoot=repo, ...
    Arms=["reduced14","reduced14"]),"SPCompare:Arms");
verifyError(testCase,@() sp_comparison_config( ...
    ReqmlRoot=repo,EvalRoot=repo,EwpRoot=repo, ...
    Arms="unknown_new_model"),"SPCompare:Arms");
end
