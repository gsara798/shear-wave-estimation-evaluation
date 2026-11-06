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

function testEightCasesAcrossDatesAndModalities(tc)
C=read_qmv2_experiment_manifest(tc.TestData.manifest);
verifyEqual(tc,numel(C.cases),8);
verifyEqual(tc,numel(C.arms),10);
types=string({C.cases.type});
verifyEqual(tc,nnz(types=="inclusion"),2);
verifyEqual(tc,nnz(types=="bilayer"),2);
verifyEqual(tc,nnz(types=="homogeneous"),4);
verifyEqual(tc,sum(string({C.cases.modality})=="sp"),4);
verifyEqual(tc,sum(string({C.cases.modality})=="rswe"),4);
verifyEqual(tc,C.m,2);
verifyEqual(tc,C.step_pixels,5);
verifyEqual(tc,C.filter.cs_min_m_s,0.8);
verifyEqual(tc,C.filter.cs_max_m_s,8);
end

function testFixedROIsAndConfiguredInclusionPairs(tc)
C=read_qmv2_experiment_manifest(tc.TestData.manifest);
s=C.cases(1);
verifyEqual(tc,string(s.type),"bilayer");
verifyEqual(tc,string({s.rois.name}),["soft","hard"]);
verifyEqual(tc,reshape(double(s.rois(1).center_mm),1,[]),[19 13]);
verifyEqual(tc,reshape(double(s.rois(2).center_mm),1,[]),[19 24.1]);
verifyEqual(tc,reshape(double(s.rois(1).size_mm),1,[]),[14.2 3.2]);
verifyEqual(tc,reshape(double(s.rois(2).size_mm),1,[]),[14.2 3.2]);
ids=string({C.cases.id});
for id=["2026Feb19_inc_sp","2026Feb19_inc_rswe"]
    inc=C.cases(ids==id);
    rois=inc.rois;
    verifyEqual(tc,string({rois.name}), ...
        ["inclusion_core","inclusion_large","background_ref"]);
    verifyEqual(tc,reshape(double(rois(1).center_mm),1,[]), ...
        [19.5 24.5]);
    verifyEqual(tc,reshape(double(rois(1).size_mm),1,[]),[8 8]);
    verifyEqual(tc,reshape(double(rois(2).center_mm),1,[]), ...
        [19.5 24.5]);
    verifyEqual(tc,reshape(double(rois(2).size_mm),1,[]),[12 12]);
    verifyEqual(tc,reshape(double(rois(3).center_mm),1,[]), ...
        [28 13.5]);
    verifyEqual(tc,reshape(double(rois(3).size_mm),1,[]),[6 6]);
    verifyEqual(tc,string({inc.contrasts.name}), ...
        ["core_vs_background","large_vs_background"]);
    verifyEqual(tc,string({inc.contrasts.reference_roi}), ...
        ["background_ref","background_ref"]);
end
end

function testFivePercentUsesSamePublishedHomogeneousROI(tc)
C=read_qmv2_experiment_manifest(tc.TestData.manifest);
ids=string({C.cases.id});
for modality=["sp","rswe"]
    id5="2026Feb27_homo_5perc_"+modality;
    id10="2026Feb27_homo_10perc_"+modality;
    five=C.cases(ids==id5);
    ten=C.cases(ids==id10);
    verifyEqual(tc,string(five.type),"homogeneous");
    verifyEqual(tc,string(five.modality),modality);
    verifyEqual(tc,string(five.relative_path), ...
        "2026-02-27/"+id5);
    verifyEqual(tc,string(five.raw_run),string(ten.raw_run));
    verifyEqual(tc,double(five.frequencies_hz(:)), ...
        double(ten.frequencies_hz(:)));
    verifyEqual(tc,reshape(double(five.rois.center_mm),1,[]), ...
        reshape(double(ten.rois.center_mm),1,[]));
    verifyEqual(tc,reshape(double(five.rois.size_mm),1,[]), ...
        [17 15]);
end
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
verifyTrue(tc,all(jobs.rois_defined));
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


function testPairedInclusionContrastArithmeticAndPartialFovFlag(tc)
% Pure metric test; no MATLAB installation-specific acquisition folders.
id=repmat("test_inclusion_sp",3,1);
mode=repmat("sp",3,1);
phantom=repmat("inclusion",3,1);
f=repmat(300,3,1);
model=repmat("qmv2_unfiltered_reduced14",3,1);
roi=["inclusion_core";"inclusion_large";"background_ref"];
means=[3.1;2.9;2.1];
medians=[3.0;2.9;2.0];
sds=[0.3;0.25;0.4];
n=[25;60;12];
roiFraction=[1;1;0.65];
T=table(id,mode,phantom,f,model,roi,means,medians, ...
    sds,n,roiFraction, ...
    'VariableNames',["case_id","modality","phantom_type", ...
    "frequency_hz","model","roi","mean_sws_m_s", ...
    "median_sws_m_s","spatial_sd_m_s", ...
    "common_valid_pixels","roi_extent_in_sample_fraction"]);
rules=struct("name",{"core_vs_background","large_vs_background"}, ...
    "target_roi",{"inclusion_core","inclusion_large"}, ...
    "reference_roi",{"background_ref","background_ref"});
X=qmv2_inclusion_contrasts(T,rules);
verifyEqual(tc,height(X),2);
verifyEqual(tc,X.contrast_name, ...
    ["core_vs_background";"large_vs_background"]);
verifyEqual(tc,X.median_sws_difference_m_s(1),1,"AbsTol",1e-12);
verifyEqual(tc,X.median_sws_ratio(1),1.5,"AbsTol",1e-12);
verifyEqual(tc,X.median_contrast_percent(1),50,"AbsTol",1e-12);
verifyEqual(tc,X.spatial_cnr(1),2,"AbsTol",1e-12);
verifyEqual(tc,X.median_contrast_percent(2),45,"AbsTol",1e-12);
verifyEqual(tc,X.reference_common_pixels(1),12);
verifyFalse(tc,any(X.roi_pair_within_fov));
end

function testManifestRejectsOverlappingContrastROIs(tc)
C=jsondecode(fileread(tc.TestData.manifest));
index=find(string({C.cases.id})=="2026Feb19_inc_sp");
C.cases(index).contrasts(1).reference_roi="inclusion_large";
path=tempname+".json";
fid=fopen(path,"w");
assert(fid>=0,"ExpQMV2:TestTemp","Cannot create temporary manifest.");
cleanup=onCleanup(@()deleteIfPresent(path)); %#ok<NASGU>
fprintf(fid,"%s",jsonencode(C));
fclose(fid);
verifyError(tc,@()read_qmv2_experiment_manifest(string(path)), ...
    "ExpQMV2:ContrastOverlap");
end

function deleteIfPresent(path)
if isfile(path),delete(path);end
end
