function tests=test_step_05_filter_cutoff_pilot
%TEST_STEP_05_FILTER_CUTOFF_PILOT Pure synthetic output/validation tests.
% No model files, raw IQ, inference, or experimental MAT files required.
tests=functiontests(localfunctions);
end

function testCutoffSweepPreservesFrozenThreshold(testCase)
[R,Q,info]=fixtures();
root=string(tempname);
mkdir(root);
guard=onCleanup(@()rmdir(root,"s")); %#ok<NASGU>
report=analyze_full21_filter_cutoff_pair(R,Q,info,root, ...
    ExploratoryCutoffs=[.20 .24 .30],SaveFigures=false);
verifyEqual(testCase,report.frozen_cutoff,.14764,AbsTol=1e-12);
verifyTrue(testCase,isfile(report.retention_csv));
verifyTrue(testCase,isfile(report.paired_csv));
verifyTrue(testCase,isfile(report.feature_csv));
T=readtable(report.retention_csv,TextType="string");
verifyEqual(testCase,height(T),2*2*4);
verifyEqual(testCase,unique(string(T.arm)),["fixed_donut";"raw"]);
v=T(string(T.roi)=="whole_fov" & T.cutoff==.14764,:);
verifyEqual(testCase,height(v),2);
verifyTrue(testCase,all(v.cutoff_type=="frozen_VALIDATION"));
% Retention at higher cutoff cannot be smaller on same saved score map.
for arm=["raw","fixed_donut"]
    rows=T(T.roi=="whole_fov" & T.arm==arm,:);
    rows=sortrows(rows,"cutoff");
    verifyGreaterThanOrEqual(testCase,diff(rows.retention_pct),-1e-12);
end
end

function testPairedCoordinateMismatchRejected(testCase)
[R,Q,info]=fixtures();
Q{2}.x_mm=[10,11.1];
verifyError(testCase, ...
    @()analyze_full21_filter_cutoff_pair(R,Q,info,string(tempname), ...
    SaveFigures=false), ...
    "AdaptiveREQ:FilterPilotGrid");
end

function testPilotUsesFilteredManifestNotGuessedRawFile(testCase)
p=fullfile(fileparts(mfilename("fullpath")), ...
    "run_05_filter_cutoff_pilot.m");
s=fileread(p);
verifyTrue(testCase,contains(s,'B.identity.source'));
verifyTrue(testCase,contains(s,'filter_manifest.mat'));
verifyTrue(testCase,contains(s,'Mode="plan"'));
verifyTrue(testCase,contains(s,'mask_identity=string(jsonencode(struct('));
verifyTrue(testCase,contains(s, ...
    'save(partial,"quality_result","mask_identity","-v7.3")'));
end

function [R,Q,info]=fixtures()
x=[10,11];
z=[20;21];
P=table([1;2;1;2],[1;1;2;2], ...
    [.1;.2;.3;.4], ...
    VariableNames=["map_ix","map_iz","feature_a"]);
raw=struct("cs_map",[2.0 2.2;2.3 2.4], ...
    "q_map",[.5 .5;.6 .7], ...
    "patch_examples",P);
F=P;
F.feature_a=F.feature_a+1;
donut=struct("cs_map",[2.0 2.1;2.5 2.6], ...
    "q_map",[.51 .51;.61 .72], ...
    "patch_examples",F);
R={raw,donut};
Q=cell(1,2);
Q{1}=makeMask(raw,[.1 .2;.3 .4],x,z);
Q{2}=makeMask(donut,[.05 .25;.35 .45],x,z);
info=struct("rois",struct( ...
    "name","central","center_mm",[10.5 20.5], ...
    "size_mm",[2 2]));
end

function Q=makeMask(R,score,x,z)
valid=true(2);
frozen=.14764;
Q=struct("original_sws_map",R.cs_map, ...
    "q_map",R.q_map, ...
    "risk_score_map",score, ...
    "original_valid_mask",valid, ...
    "retained_mask",valid&score<=frozen, ...
    "cutoff",frozen, ...
    "x_mm",x,"z_mm",z);
end
