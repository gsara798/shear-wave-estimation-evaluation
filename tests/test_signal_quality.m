function tests=test_signal_quality
tests=functiontests(localfunctions);
end

function testAlignAndAssociations(testCase)
[root,estimateFile,temporalFile,iqFile]=syntheticInputs();
cleanup=onCleanup(@()rmdir(root,"s")); %#ok<NASGU>
D=swseval.signalquality.loadAndAlign(estimateFile,temporalFile,iqFile);
verifyEqual(testCase,D.frequency_hz,500);
verifyEqual(testCase,D.window_width_mm,3,"AbsTol",1e-8);
verifyEqual(testCase,size(D.quality.r_squared),[4 4]);
verifyEqual(testCase,D.quality.r_squared(1,1),0.99,"AbsTol",1e-12);
verifyEqual(testCase,D.quality.r_squared(4,4),0.90,"AbsTol",1e-12);
roi=swseval.roi.rectangle("central",Center=[1.5 1.5], ...
    Size=[3 3],Units="mm");
A=swseval.signalquality.analyze(D,roi);
verifyEqual(testCase,A.summary.valid_count,16);
verifyEqual(testCase,A.summary.high_count,4);
verifyEqual(testCase,A.summary.high_threshold_m_s,4);
verifyTrue(testCase,ismember("r_squared_window",A.metrics.metric));
verifyTrue(testCase,ismember("correlation_mean",A.metrics.metric));
verifyEqual(testCase,height(A.gates),3);
end

function testFrequencyMismatch(testCase)
[root,estimateFile,temporalFile,iqFile]=syntheticInputs();
cleanup=onCleanup(@()rmdir(root,"s")); %#ok<NASGU>
s=load(iqFile,"q");q=s.q;q.frequency_hz=600; %#ok<NASGU>
save(iqFile,"q");
verifyError(testCase, ...
    @()swseval.signalquality.loadAndAlign(estimateFile,temporalFile,iqFile), ...
    "swseval:SignalQualityFrequencyMismatch");
end

function testOutsideQualityFOVIsMissingNotExtrapolated(testCase)
[root,estimateFile,temporalFile,iqFile]=syntheticInputs();
cleanup=onCleanup(@()rmdir(root,"s")); %#ok<NASGU>
s=load(estimateFile,"result");result=s.result;
result.x_mm=[0 1 2 10]; %#ok<NASGU>
save(estimateFile,"result");
D=swseval.signalquality.loadAndAlign(estimateFile,temporalFile,iqFile);
verifyTrue(testCase,all(isnan(D.quality.correlation_mean(:,4))));
end

function [folder,estimateFile,temporalFile,iqFile]=syntheticInputs()
folder=string(tempname);mkdir(folder);
estimateFile=fullfile(folder,"reqml_result.mat");
temporalFile=fullfile(folder,"temporal_consistency.mat");
iqFile=fullfile(folder,"iq_quality.mat");
result=struct();
result.cs_map=2*ones(4);result.cs_map(3:4,3:4)=4;
result.q_map=0.8*ones(4);result.q_map(3:4,3:4)=0.6;
result.x_mm=0:3;result.z_mm=(0:3)';
result.valid_mask=true(4);
result.metadata=struct("frequency_hz",500, ...
    "patch_width_pixels",3,"step_pixels",1); %#ok<NASGU>
save(estimateFile,"result");
x=(0:4)*1e-3;z=x';
r=struct("x_m",x,"z_m",z,"frequency_hz",500, ...
    "source_file","test1_500Hz.mat");
r.r_squared=0.99*ones(5);r.r_squared(4:5,4:5)=0.90;
r.amplitude_f0_m=1e-6*ones(5);
r.residual_rms_m=1e-8*ones(5);
r.amplitude_to_residual_ratio=20*ones(5);
r.amplitude_to_residual_ratio(4:5,4:5)=5; %#ok<NASGU>
save(temporalFile,"r");
q=struct("x_m",x,"z_m",z,"frequency_hz",500, ...
    "source_file","test1_500Hz.mat");
q.correlation_mean=0.998*ones(5);q.iq_rms=1e6*ones(5); %#ok<NASGU>
save(iqFile,"q");
end
