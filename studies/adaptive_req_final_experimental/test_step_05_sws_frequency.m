function tests=test_step_05_sws_frequency
%TEST_STEP_05_SWS_FREQUENCY No models, real MAT, IQ, license or training.
tests=functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.originalPath=path;
here=string(fileparts(mfilename("fullpath")));
root=string(fileparts(fileparts(here)));
addpath(here,"-begin");
addpath(fullfile(root,"src"),"-begin");
end
function teardownOnce(t)
path(t.TestData.originalPath);
end

function testAllROIViewsBothMasksAndPhysicalReference(t)
root=string(tempname);
mkdir(root);
guard=onCleanup(@()rmdir(root,"s")); %#ok<NASGU>
[T,ref]=fixtures();
R=render_adaptive_req_final_frequency_figures( ...
    T,ref,fullfile(root,"figures"), ...
    Modalities="sp",Phantoms=["homogeneous","bilayer","inclusion"], ...
    MValues=2,FrequenciesHz=[300 500],Formats="png", ...
    Visible=false,Overwrite=false);
% 3 phantom types x 2 mask states x 3 ROI views.
verifyEqual(t,R.n_figures,18);
verifyEqual(t,R.n_files,18);
verifyTrue(t,all(isfile(R.files)));
L=readtable(R.manifest,TextType="string");
verifyEqual(t,height(L),18);
verifyEqual(t,sort(unique(L.mask_state)),["masked";"original"]);
verifyEqual(t,sort(unique(L.roi_view)),["both";"hard";"soft"]);
verifyEqual(t,unique(L.M),2);
verifyEqual(t,sort(unique(L.phantom_type)), ...
    ["bilayer";"homogeneous";"inclusion"]);
verifyEqual(t,L.reference_status, ...
    repmat("approximate_main_text_envelope",18,1));
% Lower coverage must not crash; its missing frequency is not fabricated.
verifyTrue(t,any(T.n_valid==0 & isnan(T.mean_sws_m_s)));
verifyTrue(t,isfile(fullfile(root,"figures","inclusion","sp", ...
    "M2","masked","sws_vs_frequency_both.png")));
verifyTrue(t,isfile(fullfile(root,"figures","homogeneous","sp", ...
    "M2","original","sws_vs_frequency_both.png")));
verifyError(t,@()render_adaptive_req_final_frequency_figures( ...
    T,ref,fullfile(root,"figures"), ...
    Modalities="sp",Phantoms="bilayer",MValues=2, ...
    FrequenciesHz=[300 500],Formats="png"), ...
    "AdaptiveREQ:FrequencyImmutable");
end

function testRejectMissingReferenceFrequency(t)
root=string(tempname);
mkdir(root);
guard=onCleanup(@()rmdir(root,"s")); %#ok<NASGU>
[T,ref]=fixtures();
ref=ref(~(ref.material=="hard" & ref.frequency_hz==500),:);
verifyError(t,@()render_adaptive_req_final_frequency_figures( ...
    T,ref,fullfile(root,"figures"), ...
    Modalities="sp",Phantoms="bilayer",MValues=2, ...
    FrequenciesHz=[300 500],Formats="png"), ...
    "AdaptiveREQ:ReferenceFrequency");
end

function testStage05UsesFrozenExperimentProvenanceAndSD(t)
p=fullfile(fileparts(mfilename("fullpath")), ...
    "run_05_plot_sws_vs_frequency.m");
s=fileread(p);
verifyTrue(t,contains(s,'MaskVersion="quality_mask_full21_val85_posthoc_v2"'));
verifyTrue(t,contains(s,'StepPixels=3;'));
verifyTrue(t,contains(s,'sd=std(y,0)'));
verifyTrue(t,contains(s,'original_sws_map'));
verifyTrue(t,contains(s,'1.8*ones(numel(freqs),1)'));
verifyTrue(t,contains(s,'3.2*ones(numel(freqs),1)'));
verifyFalse(t,contains(s,'REF.soft.mean = 1.82'));
verifyTrue(t,contains(s,'ReferenceCSV=""'));
end

function [T,R]=fixtures()
materials=["soft","hard"];
phantoms=["homogeneous","bilayer","inclusion"];
tableRows=cell(0,1);
for ph=phantoms
    for mat=materials
        for status=["original","masked"]
            for hz=[300 500]
                n=30;
                if status=="masked",n=20;end
                % One zero-retention case must be shown as missing data,
                % not a zero SWS value or interpolated plot point.
                if ph=="inclusion" && mat=="hard" && ...
                        status=="masked" && hz==500,n=0;end
                mu=NaN;sd=NaN;
                if n>0
                    mu=1.8;sd=.12;
                    if mat=="hard",mu=3.0;sd=.15;end
                end
                id="synthetic_"+ph+"_"+mat+"_sp";
                row=table(id,"sp",ph,"roi_"+mat,mat,hz,2,status, ...
                    n,mu,sd,35,40,n/35, ...
                    'VariableNames',["case_id","modality", ...
                    "phantom_type","roi","material", ...
                    "frequency_hz","M","mask_state","n_valid", ...
                    "mean_sws_m_s","sd_sws_m_s","n_original_valid", ...
                    "roi_pixels","coverage"]);
                tableRows{end+1,1}=row; %#ok<AGROW>
            end
        end
    end
end
T=vertcat(tableRows{:});
frequency_hz=[300;500;300;500];
material=["soft";"soft";"hard";"hard"];
lower_m_s=[1.8;1.8;2.8;2.8];
upper_m_s=[2;2;3.2;3.2];
reference_status=repmat("approximate_main_text_envelope",4,1);
R=table(frequency_hz,material,lower_m_s,upper_m_s,reference_status);
end
