function tests=test_step_05_cutoff_only
%TEST_STEP_05_CUTOFF_ONLY Synthetic tests; no trained models or wavefields.
tests=functiontests(localfunctions);
end

function testFrozenThresholdIsPreservedAndCoverageMonotone(testCase)
base=string(tempname);
mkdir(base);
guard=onCleanup(@()rmdir(base,"s")); %#ok<NASGU>
id="2026Feb27_homo_5perc_rswe";
root=fullfile(base,"2026-02-27",id,"analysis", ...
    "adaptive_req_final_experimental_v1", ...
    "M2_step3","quality_mask_full21_locked_v1", ...
    "masks","adaptive_req_full21_unfiltered_v1","500Hz");
mkdir(root);
maskFile=fullfile(root,"risk_mask_result.mat");
cs=[2.0,2.1;2.2,2.3];
risk=[.10,.19;.28,.37];
valid=true(2);
frozen=.14764;
quality_result=struct( ...
    "original_sws_map",cs, ...
    "risk_score_map",risk, ...
    "original_valid_mask",valid, ...
    "retained_mask",valid&risk<=frozen, ...
    "rejected_mask",valid&risk>frozen, ...
    "unscored_mask",false(2), ...
    "cutoff",frozen, ...
    "x_mm",[17 19],"z_mm",[18;20], ...
    "release_id","adaptive_req_full21_v1"); %#ok<NASGU>
mask_identity=string(jsonencode(struct( ...
    "case_id",id,"frequency_hz",500,"M",2,"step_pixels",3, ...
    "mask_version","quality_mask_full21_locked_v1", ...
    "model_label","adaptive_req_full21_unfiltered_v1", ...
    "mask_cutoff",frozen))); %#ok<NASGU>
save(maskFile,"quality_result","mask_identity");

plan=run_full21_cutoff_only(Mode="plan",DataRoot=base);
verifyEqual(testCase,plan.status,"planned");
R=run_full21_cutoff_only(Mode="run",DataRoot=base, ...
    ExploratoryCutoffs=[.20 .24 .30 .40],SaveFigures=false);
verifyEqual(testCase,R.frozen_cutoff,frozen,AbsTol=1e-12);
verifyTrue(testCase,isfile(R.summary_file));
T=readtable(R.summary_file,TextType="string");
F=T(T.roi=="full_fov",:);
verifyEqual(testCase,height(F),5);
verifyEqual(testCase,nnz(F.cutoff_type=="frozen_VALIDATION"),1);
F=sortrows(F,"cutoff");
verifyGreaterThanOrEqual(testCase,diff(F.retention_percent),zeros(4,1));
verifyEqual(testCase,F.retention_percent.',[25 50 50 75 100],AbsTol=1e-12);
after=load(maskFile,"quality_result","mask_identity");
verifyEqual(testCase,after.quality_result.cutoff,frozen);
verifyEqual(testCase,after.quality_result.retained_mask,valid&risk<=frozen);
verifyEqual(testCase,string(after.mask_identity),string(mask_identity));
end

function testRejectUnknownStage03Case(testCase)
d=string(tempname);
verifyError(testCase,@()run_full21_cutoff_only( ...
    Mode="run",DataRoot=d,SaveFigures=false), ...
    "AdaptiveREQ:CutoffOnlyMissingMask");
end

function testLegacyRunnerDefaultsToCutoffOnly(testCase)
path=fullfile(fileparts(mfilename("fullpath")), ...
    "run_05_filter_cutoff_pilot.m");
source=fileread(path);
verifyTrue(testCase,contains(source,"CompareFilter=false;"));
verifyTrue(testCase,contains(source, ...
    "cutoffReport=run_full21_cutoff_only("));
end
