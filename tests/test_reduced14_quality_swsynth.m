function tests=test_reduced14_quality_swsynth
%TEST_REDUCED14_QUALITY_SWSYNTH No simulations or trained models needed.
tests=functiontests(localfunctions);
end

function testPerfectRiskRanking(testCase)
A=fixture();
mask=true(2);
truth=2*ones(2);
[S,W]=swseval.qualitymask.evaluateTruth(A,mask,truth);
verifyEqual(testCase,height(S),3);
verifyEqual(testCase,S.valid_count,3*ones(3,1));
verifyEqual(testCase,S.invalid_count,ones(3,1));
verifyEqual(testCase,S.auc,ones(3,1),"AbsTol",1e-12);
verifyEqual(testCase,S.high_error_fraction_valid,ones(3,1)/3);
verifyEqual(testCase,S.retained_count,[2;2;2]);
verifyEqual(testCase,S.mape_retained_pct,2.5*ones(3,1), ...
    "AbsTol",1e-12);
verifyEqual(testCase,S.correct_rejection_fraction,zeros(3,1));
verifyEqual(testCase,S.high_error_rejection_fraction,ones(3,1));
verifyEqual(testCase,height(W),3);
verifyEqual(testCase,nnz(W.high_error),1);
end

function testFalseRejectionIsReported(testCase)
A=fixture();
A.risk_map(2,1)=0.8; % Low-error pixel falsely rejected.
[S,~]=swseval.qualitymask.evaluateTruth(A,true(2),2*ones(2));
verifyEqual(testCase,S.retained_count,[1;1;1]);
verifyEqual(testCase,S.correct_rejection_fraction,0.5*ones(3,1));
end

function testOneClassAucUndefined(testCase)
A=fixture();
A.original_sws_map(:)=2;
A.valid_mask(1,2)=false;
[S,~]=swseval.qualitymask.evaluateTruth(A,true(2),2*ones(2));
verifyTrue(testCase,all(isnan(S.auc)));
verifyTrue(testCase,all(isnan(S.high_error_rejection_fraction)));
end

function testUnscoredValidIsRejected(testCase)
A=fixture();
A.risk_map(1,1)=NaN;
[S,W]=swseval.qualitymask.evaluateTruth(A,true(2),2*ones(2));
verifyEqual(testCase,S.scored_count,2*ones(3,1));
verifyEqual(testCase,S.retained_count,ones(3,1));
verifyFalse(testCase,W.risk_scored(W.map_iz==1 & W.map_ix==1));
end

function testMismatchIsRejected(testCase)
A=fixture();
verifyError(testCase,@()swseval.qualitymask.evaluateTruth( ...
    A,true(3),2*ones(2)),"QualitySynth:ROIShape");
end

function A=fixture()
% Three valid predictions, one invalid (its risk=1 is a SENTINEL).
A=struct();
A.original_sws_map=[2 2.4;2.1 NaN];
A.risk_map=[0.05 0.9;0.2 1];
A.valid_mask=[true true;true false];
A.x_mm=[10 11];A.z_mm=[20;21];
A.max_risks=[0.2;0.3;0.5];
end
