function tests=test_reqml_experimental_roi_and_rswe_config
%TEST_REQML_EXPERIMENTAL_ROI_AND_RSWE_CONFIG Configuration-only tests.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
repo=string(fileparts(fileparts(mfilename("fullpath"))));
testCase.TestData.repo=repo;
addpath(fullfile(repo,"src"),"-begin");
addpath(fullfile(repo,"studies","reqml_sp_comparison"),"-begin");
addpath(fullfile(repo,"studies","reqml_rswe_comparison"),"-begin");
end

function testHomogeneousCentralROI(testCase)
sp=sp_comparison_rois("2026Feb27_homo_10perc_sp");
rswe=rswe_comparison_rois("2026Feb27_homo_5perc_rswe");
for rois={sp,rswe}
    r=rois{1};
    verifyEqual(testCase,numel(r),1);
    verifyEqual(testCase,string(r.name),"central");
    verifyEqual(testCase,r.center,[19 19.25]);
    verifyEqual(testCase,r.size,[17 15]);
    verifyEqual(testCase,string(r.units),"mm");
end
end

function testBilayerROIsCenteredAndEqualSized(testCase)
for rois={sp_comparison_rois("2026Feb27_dl_sp"), ...
          rswe_comparison_rois("2026Feb27_dl_rswe")}
    r=rois{1};
    verifyEqual(testCase,numel(r),2);
    verifyEqual(testCase,string({r.name}),["ROI1","ROI2"]);
    verifyEqual(testCase,r(1).center,[19 13]);
    verifyEqual(testCase,r(2).center,[19 24.1]);
    verifyEqual(testCase,r(1).size,[14.2 3.2]);
    verifyEqual(testCase,r(2).size,[14.2 3.2]);
end
end

function testSPNewAnalysisOnlyNoChangedEstimates(testCase)
repo=testCase.TestData.repo;
c=sp_comparison_config(ReqmlRoot=repo,EwpRoot=repo,EvalRoot=repo, ...
    Arms=["A_raw_v1","reduced14","B_filtered_v1", ...
        "reduced14_filtered","candidate10_filtered"]);
verifyEqual(testCase,c.comparisonName,"reqml_sp_compare_m2_0p8_8_v1");
verifyTrue(testCase,endsWith(c.analysisName, ...
    "_reduced14_5arms_v1_interior_bilayer_v6_homo_centered_large_v2"));
verifyEqual(testCase,c.M,2);
verifyEqual(testCase,c.StepPixels,2);
end

function testRSWEDefaultFiveArmsAndIsolation(testCase)
repo=testCase.TestData.repo;
c=rswe_comparison_config(ReqmlRoot=repo,EwpRoot=repo,EvalRoot=repo);
verifyEqual(testCase,c.Experiments,["2026Feb27_dl_rswe", ...
    "2026Feb27_homo_5perc_rswe","2026Feb27_homo_10perc_rswe"]);
verifyEqual(testCase,c.arms,c.fiveArms);
verifyEqual(testCase,c.arms,["A_raw_v1","reduced14", ...
    "B_filtered_v1","reduced14_filtered","candidate10_filtered"]);
verifyEqual(testCase,c.inputKinds, ...
    ["raw","raw","filtered","filtered","filtered"]);
verifyEqual(testCase,c.modelPaths, ...
    [c.v1;c.reduced14Bundle;c.v1;c.reduced14Bundle;c.candidate10]);
verifyEqual(testCase,c.FilePattern,"test1_{frequency}Hz.mat");
verifyEqual(testCase,c.M,2);
verifyEqual(testCase,c.StepPixels,2);
verifyEqual(testCase,c.Frequencies,[300 400 500 600]);
verifyEqual(testCase,c.comparisonName,"reqml_rswe_compare_m2_0p8_8_v1");
verifyTrue(testCase,endsWith(c.analysisName, ...
    "_reduced14_5arms_v1_interior_bilayer_v5_homo_centered_large_v2"));
verifyNotEqual(testCase,c.comparisonName, ...
    "reqml_sp_compare_m2_0p8_8_v1");
end

function testRSWECustomExperimentAndInvalidType(testCase)
repo=testCase.TestData.repo;
c=rswe_comparison_config(ReqmlRoot=repo,EwpRoot=repo,EvalRoot=repo, ...
    Experiments=["2026Feb27_dl_rswe","2026Feb27_homo_5perc_rswe"]);
verifyEqual(testCase,numel(c.Experiments),2);
verifyError(testCase,@() rswe_comparison_config( ...
    ReqmlRoot=repo,EwpRoot=repo,EvalRoot=repo, ...
    Experiments="2026Feb27_dl_sp"),"RSWECompare:Experiments");
end


function testBilayerPixelCountsMatched(testCase)
name=["ROI1";"ROI1";"ROI2";"ROI2"];
model=repmat("reduced14",4,1);
frequency_hz=[300;600;300;600];
selected_pixels=[280;280;280;280];
valid_pixels=selected_pixels;
T=table(name,model,frequency_hz,selected_pixels,valid_pixels);
n=swseval.metrics.assertEqualBilayerPixelCounts( ...
    T,["ROI1","ROI2"],"reduced14",[300 600]);
verifyEqual(testCase,n,280);

T.selected_pixels(2)=275;
verifyError(testCase,@() swseval.metrics.assertEqualBilayerPixelCounts( ...
    T,["ROI1","ROI2"],"reduced14",[300 600]), ...
    "swseval:InconsistentROIPixels");
end


function testHardROISelectedRowsOnObservedSPGridPhases(testCase)
% Regression from historical 300 and 600 Hz SP map-grid offsets.
% This numerical check supplements, not replaces, the real-data assertion.
r=sp_comparison_rois("2026Feb27_dl_sp");
hard=r(2);
dz=0.405263157894737;
phaseStarts=[22.5934210526317 22.796052631579];
for k=1:numel(phaseStarts)
    z=phaseStarts(k)+(-10:20)*dz;
    zmin=hard.center(2)-hard.size(2)/2;
    zmax=hard.center(2)+hard.size(2)/2;
    verifyEqual(testCase,nnz(z>=zmin & z<=zmax),8);
end
end
