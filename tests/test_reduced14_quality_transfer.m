function tests=test_reduced14_quality_transfer
tests=functiontests(localfunctions);
end

function testAlignedRiskMaps(testCase)
[r,bundle,clean]=fixture(); %#ok<ASGLU>
cleanup=onCleanup(clean); %#ok<NASGU>
A=swseval.qualitymask.analyzeResult(r,bundle, ...
    MaximumRisks=[0.2 0.3],Arm="reduced14", ...
    RiskPredictor=@mockRisk);
verifyEqual(testCase,A.risk_map,[0.05 0.25;0.5 1],"AbsTol",1e-12);
verifyEqual(testCase,A.summary.valid_count,[3;3]);
verifyEqual(testCase,A.summary.retained_count,[1;2]);
verifyEqual(testCase,A.summary.fraction_retained_valid,[1/3;2/3], ...
    "AbsTol",1e-12);
verifyTrue(testCase,isnan(A.masked_sws_maps(1,2,1)));
verifyEqual(testCase,A.masked_sws_maps(1,2,2),2);
verifyTrue(testCase,isnan(A.original_sws_map(2,2)));
verifyFalse(testCase,A.spatial_filter_transfer);
end

function testRejectWrongRegressor(testCase)
[r,bundle,clean]=fixture();
cleanup=onCleanup(clean); %#ok<NASGU>
r.metadata.model_provenance_id="different_model";
verifyError(testCase,@()swseval.qualitymask.analyzeResult( ...
    r,bundle,RiskPredictor=@mockRisk),"QualityTransfer:ModelIdentity");
end

function testRejectMapMisalignment(testCase)
[r,bundle,clean]=fixture();
cleanup=onCleanup(clean); %#ok<NASGU>
r.q_map(1,1)=0.4;
verifyError(testCase,@()swseval.qualitymask.analyzeResult( ...
    r,bundle,RiskPredictor=@mockRisk),"QualityTransfer:Alignment");
end

function testRejectAbsentPredictor(testCase)
[r,bundle,clean]=fixture();
cleanup=onCleanup(clean); %#ok<NASGU>
r.patch_examples=removevars(r.patch_examples,"f05");
verifyError(testCase,@()swseval.qualitymask.analyzeResult( ...
    r,bundle,RiskPredictor=@mockRisk),"QualityTransfer:MissingFeatures");
end

function testPlanDoesNotCreateOutputs(testCase)
root=string(tempname);mkdir(root);
cleanup=onCleanup(@()rmdir(root,"s")); %#ok<NASGU>
before=dir(root);
p=run_quality_mask_transfer(Mode="plan",DataRoot=root, ...
    ReqmlRoot=root,EvalRoot=root, ...
    Experiments="toy_sp",Arms="reduced14",Frequencies=300, ...
    MakePlots=false);
verifyEqual(testCase,numel(p.cases),1);
verifyEqual(testCase,numel(p.missing_inputs),2);
verifyEqual(testCase,numel(dir(root)),numel(before));
end

function risk=mockRisk(~,rows)
risk=double(rows.f01);
end

function [r,bundle,cleanup]=fixture()
root=string(tempname);mkdir(root);
cleanup=@()rmdir(root,"s");
names="f"+compose("%02d",(1:20)');
metadata=struct("version","reduced14_quality_mask_v1", ...
    "predictors",[names;"quality_q_pred"]); %#ok<NASGU>
bundle=fullfile(root,"bundle.mat");
save(bundle,"metadata");
e=table([1;1;2;2],[1;2;1;2], ...
    "VariableNames",["map_iz","map_ix"]);
for k=1:20
    values=ones(4,1);
    if k==1,values=[0.05;0.25;0.5;0.2];end
    e.(char(names(k)))=values;
end
p=table([0.7;0.8;0.9;NaN],[1.8;2;2.1;NaN], ...
    logical([1;1;1;0]), ...
    "VariableNames",["q_pred","cs_pred_m_s","sws_valid"]);
r=struct("patch_examples",e,"patch_predictions",p, ...
    "cs_map",[1.8 2;2.1 NaN],"q_map",[0.7 0.8;0.9 NaN], ...
    "valid_mask",logical([1 1;1 0]),"x_mm",[0 1], ...
    "z_mm",[0;1],"metadata",struct( ...
        "model_provenance_id", ...
        "reqml_q0_v5_localonly_reduced14_transfer_v1"));
end
