function tests=test_qmv2_experimental_mask_roi_plots
% Smoke-test pure CSV-to-ROI-figure code with an isolated temp fixture.
tests=functiontests(localfunctions);
end

function setupOnce(tc)
repo=string(fileparts(fileparts(mfilename("fullpath"))));
study=fullfile(repo,"studies","reqml_experimental_qmv2");
addpath(study,"-begin");
end

function testPlotsFromSavedROIOnly(tc)
root=string(tempname);
mkdir(root);
cleanup=onCleanup(@()rmdir(char(root),"s")); %#ok<NASGU>
C=struct("data_root",root,"study_id","test_mask_roi", ...
    "m",2,"step_pixels",5, ...
    "cases",struct("id","example_homo_sp", ...
        "relative_path","example_homo_sp"));
caseRoot=fullfile(root,"example_homo_sp");
mkdir(caseRoot);
freq=[300;400;500;600];
arms=["qmv2_unfiltered_reduced14"; ...
      "qmv2_unfiltered_expanded20"; ...
      "qmv2_fixed_donut_reduced14"; ...
      "qmv2_fixed_donut_expanded20"];
cases=repmat("example_homo_sp",numel(freq),1);
roots=repmat(caseRoot,numel(freq),1);
jobs=table(cases,freq,roots, ...
    'VariableNames',["case_id","frequency_hz","dataset_root"]);
models=table(arms,'VariableNames',"arm");
id=strings(16,1);f=zeros(16,1);arm=strings(16,1);
roi=repmat("central",16,1);
cov=zeros(16,1);mb=zeros(16,1);ma=zeros(16,1);
cb=zeros(16,1);ca=zeros(16,1);
k=0;
for a=1:4
    for ff=1:4
        k=k+1;
        id(k)="example_homo_sp";
        f(k)=freq(ff);
        arm(k)=arms(a);
        cov(k)=0.8+0.01*a-0.05*(ff==4);
        mb(k)=1.8+0.02*ff;
        ma(k)=mb(k)-0.01;
        cb(k)=10+ff;
        ca(k)=4+ff;
    end
end
T=table(id,f,arm,roi,cov,mb,ma,cb,ca, ...
    'VariableNames',["case_id","frequency_hz","arm","roi", ...
    "retained_fraction","median_sws_before","median_sws_after", ...
    "cv_percent_before","cv_percent_after"]);
out=fullfile(root,"analysis","test_mask_roi", ...
    "M2_step5","roi_plot_fixture");
mkdir(out);
writetable(T,fullfile(out,"quality_mask_experimental_roi_summary.csv"));
files=qmv2_plot_experimental_mask_rois( ...
    C,jobs,models,"roi_plot_fixture");
verifyEqual(tc,numel(files),1);
verifyTrue(tc,isfile(files(1)));
verifyTrue(tc,contains(files(1),"roi_figures"));
end

function testRejectsMissingROIStats(tc)
root=string(tempname);
mkdir(root);
cleanup=onCleanup(@()rmdir(char(root),"s")); %#ok<NASGU>
C=struct("data_root",root,"study_id","test_missing", ...
    "m",2,"step_pixels",5);
jobs=table("case",300,root, ...
    'VariableNames',["case_id","frequency_hz","dataset_root"]);
models=table("qmv2_unfiltered_reduced14", ...
    'VariableNames',"arm");
verifyError(tc,@()qmv2_plot_experimental_mask_rois( ...
    C,jobs,models,"not_analyzed"), ...
    "ExpQMV2:MaskROIPlotsNeedAnalyze");
end
