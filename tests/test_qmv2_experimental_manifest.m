function tests=test_qmv2_experimental_manifest
% No local experimental datasets, IQ processing, or inference.
% Temporary manifest files are isolated and deleted after each test.
tests=functiontests(localfunctions);
end

function setupOnce(tc)
repo=string(fileparts(fileparts(mfilename("fullpath"))));
folder=fullfile(repo,"studies","reqml_experimental_qmv2");
addpath(folder,"-begin");
tc.TestData.manifest=fullfile(folder,"experiment_manifest.example.json");
end

function testSixCasesAcrossDatesAndModalities(tc)
C=read_qmv2_experiment_manifest(tc.TestData.manifest);
verifyEqual(tc,numel(C.cases),6);
verifyEqual(tc,numel(C.arms),10);
types=string({C.cases.type});
verifyEqual(tc,nnz(types=="inclusion"),2);
verifyEqual(tc,nnz(types=="bilayer"),2);
verifyEqual(tc,nnz(types=="homogeneous"),2);
verifyEqual(tc,sum(string({C.cases.modality})=="sp"),3);
verifyEqual(tc,sum(string({C.cases.modality})=="rswe"),3);
verifyEqual(tc,C.m,2);
verifyEqual(tc,C.step_pixels,5);
verifyEqual(tc,C.filter.cs_min_m_s,0.8);
verifyEqual(tc,C.filter.cs_max_m_s,8);
end

function testFixedROIFromPriorStudyAndInclusionIsUnsegmented(tc)
C=read_qmv2_experiment_manifest(tc.TestData.manifest);
s=C.cases(1);
verifyEqual(tc,string(s.type),"bilayer");
verifyEqual(tc,string({s.rois.name}),["soft","hard"]);
verifyEqual(tc,double(s.rois(1).center_mm),[19 13]);
verifyEqual(tc,double(s.rois(2).center_mm),[19 24.1]);
verifyEqual(tc,double(s.rois(1).size_mm),[14.2 3.2]);
verifyEqual(tc,double(s.rois(2).size_mm),[14.2 3.2]);
verifyEmpty(tc,C.cases(5).rois);
verifyEmpty(tc,C.cases(6).rois);
end

function testPurePlanAndModelArmPreflight(tc)
C=read_qmv2_experiment_manifest(tc.TestData.manifest);
[jobs,models]=qmv2_experimental_plan(C, ...
    "2026Feb19_inc_rswe", ...
    ["reduced14","qmv2_fixed_donut_expanded20_frequency"]);
verifyEqual(tc,height(models),2);
verifyEqual(tc,models.input_kind,["raw";"donut"]);
verifyTrue(tc,endsWith(models.bundle_file(2), ...
    fullfile("fixed_donut","transfer_bundles_v1", ...
        "expanded20_frequency","model_bundle.mat")));
verifyTrue(tc,all(jobs.case_id=="2026Feb19_inc_rswe"));
verifyTrue(tc,all(jobs.modality=="rswe"));
verifyTrue(tc,all(~jobs.rois_defined));
end

function testPlanCanScopeModelsAndCases(tc)
P=run_qmv2_experimental_study( ...
    ManifestFile=tc.TestData.manifest,Stage="plan", ...
    CaseIDs="2026Feb27_dl_sp", ...
    Arms="qmv2_unfiltered_reduced14");
verifyEqual(tc,height(P.models),1);
verifyEqual(tc,P.models.input_kind,"raw");
verifyTrue(tc,all(P.jobs.case_id=="2026Feb27_dl_sp"));
verifyTrue(tc,all(P.jobs.rois_defined));
end

function testNondefaultManifestOptionsAreHonored(tc)
% Guard against a parser silently overwriting JSON settings with defaults.
C=jsondecode(fileread(tc.TestData.manifest));
C.m=3;
C.step_pixels=4;
C.sws_limits=[0.5 5.5];
C.analysis_version="custom_validation_v3";
C.filter.cs_min_m_s=1.1;
C.filter.cs_max_m_s=6;
C.filter.taper_relative=0.08;
path=tempname+".json";
fid=fopen(path,"w");
assert(fid>=0,"ExpQMV2:TestTemp","Cannot create temporary manifest.");
cleanup=onCleanup(@()deleteIfPresent(path)); %#ok<NASGU>
fprintf(fid,"%s",jsonencode(C));
fclose(fid);
actual=read_qmv2_experiment_manifest(string(path));
verifyEqual(tc,actual.m,3);
verifyEqual(tc,actual.step_pixels,4);
verifyEqual(tc,actual.sws_limits,[0.5 5.5]);
verifyEqual(tc,actual.analysis_version,"custom_validation_v3");
verifyEqual(tc,actual.filter.cs_min_m_s,1.1);
verifyEqual(tc,actual.filter.cs_max_m_s,6);
verifyEqual(tc,actual.filter.taper_relative,0.08);
end

function testMalformedFilterIsRejected(tc)
C=jsondecode(fileread(tc.TestData.manifest));
C.filter=rmfield(C.filter,"cs_min_m_s");
path=tempname+".json";
fid=fopen(path,"w");
assert(fid>=0,"ExpQMV2:TestTemp","Cannot create temporary manifest.");
cleanup=onCleanup(@()deleteIfPresent(path)); %#ok<NASGU>
fprintf(fid,"%s",jsonencode(C));
fclose(fid);
verifyError(tc,@()read_qmv2_experiment_manifest(string(path)), ...
    "ExpQMV2:Filter");
end

function deleteIfPresent(path)
if isfile(path),delete(path);end
end
