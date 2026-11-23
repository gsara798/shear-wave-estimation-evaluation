function tests=test_compare_models_500hz()
%TEST_COMPARE_MODELS_500HZ Lightweight plan/path/ROI checks, no MAT reads.
tests=functiontests(localfunctions);
end

function testSixCasePathContract(tc)
here=string(fileparts(mfilename("fullpath")));
evalRoot=string(fileparts(fileparts(here)));
base=string(fileparts(evalRoot));
req=fullfile(base,"req-ml");
if ~isfolder(fullfile(req,"src"))
    % On CI, REQ-ML may not be checked out next to SWSEval.
    return
end
cfg=compare_models_500hz_config();
verifyEqual(tc,height(cfg.jobs),6);
verifyEqual(tc,cfg.frequency_hz,500);
verifyEqual(tc,cfg.M,2);
verifyEqual(tc,cfg.step_pixels,3);
verifyEqual(tc,cfg.arms, ...
    ["adaptive_req_full21_unfiltered_v1", ...
     "adaptive_req_full21_clean_v1","legacy_q0_v1"]);
verifyTrue(tc,all(contains(cfg.jobs.sample_file, ...
    fullfile("processed","adaptive_req_final_unfiltered_v1", ...
        "500Hz","wavefield_sample.mat"))));
verifyTrue(tc,all(endsWith(cfg.jobs.original_file, ...
    fullfile("M2","step3","reqml_result.mat"))));
verifyTrue(tc,all(contains(cfg.jobs.clean_file, ...
    fullfile("REQ-ML","adaptive_req_full21_clean_v1"))));
verifyTrue(tc,all(contains(cfg.jobs.legacy_file, ...
    fullfile("REQ-ML","legacy_q0_v1"))));
end

function testReadOnlyPlans(tc)
here=string(fileparts(mfilename("fullpath")));
evalRoot=string(fileparts(fileparts(here)));
req=fullfile(fileparts(evalRoot),"req-ml");
if ~isfolder(fullfile(req,"src")),return,end
P=run_compare_models_500hz(Mode="plan", ...
    SelectedCaseIDs="2026Feb27_homo_10perc_rswe");
verifyEqual(tc,P.status,"planned");
verifyEqual(tc,height(P.jobs),1);
verifyFalse(tc,P.quality_mask);
Q=plot_compare_models_500hz(Mode="plan", ...
    SelectedCaseIDs="2026Feb27_homo_10perc_rswe");
verifyEqual(tc,Q.status,"planned");
verifyEqual(tc,Q.selected,1);
end

function testOriginalPhysicalROIs(tc)
caseIDs=[
    "2026Feb27_homo_10perc_sp";
    "2026Feb27_homo_10perc_rswe";
    "2026Feb27_homo_5perc_sp";
    "2026Feb27_homo_5perc_rswe";
    "2026Feb27_dl_sp";
    "2026Feb27_dl_rswe"
];
for c=caseIDs.'
    spec=adaptive_req_final_case_rois(c);
    verifyGreaterThanOrEqual(tc,numel(spec.rois),1);
    verifyTrue(tc,all(ismember(string({spec.rois.name}), ...
        ["central","soft","hard"])));
end
end
