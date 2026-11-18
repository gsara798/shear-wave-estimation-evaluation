function tests=test_step_04_paper_figures
%TEST_STEP_04_PAPER_FIGURES Synthetic structural checks (no experimental MAT).
tests=functiontests(localfunctions);
end

function testPhysicalCaseRois(testCase)
hom=adaptive_req_final_case_rois("2026Feb27_homo_10perc_sp");
bil=adaptive_req_final_case_rois("2026Feb27_dl_sp");
inc=adaptive_req_final_case_rois("2026Feb19_inc_rswe");
verifyEqual(testCase,string({hom.rois.name}),"central");
verifyEqual(testCase,string({bil.rois.name}),["soft","hard"]);
verifyEqual(testCase,string({inc.rois.name}), ...
    ["inclusion_core","background_ref"]);
verifyEqual(testCase,double(hom.rois(1).center_mm(:)'),[19 19.25]);
end

function testBmodeSameGridAndMismatch(testCase)
tmp=string(tempname);
mkdir(tmp);
guard=onCleanup(@()rmdir(tmp,"s")); %#ok<NASGU>
IQData1=complex(ones(7,9,3));
BmodeIQ=complex(ones(7,9));
dinf=struct("dx",0.001,"dz",0.001);
rawFile=fullfile(tmp,"raw.mat");
save(rawFile,"IQData1","BmodeIQ","dinf");
manifestFile=fullfile(tmp,"processing_manifest.json");
fid=fopen(manifestFile,"w");
assert(fid>0);
fprintf(fid,"%s",jsonencode(struct("source_file",rawFile)));
fclose(fid);
R=struct("x_mm",[1 2],"z_mm",[1;2]);
B=load_adaptive_req_final_bmode(manifestFile,R);
verifyTrue(testCase,B.available);
verifyEqual(testCase,size(B.image_db),[7 9]);
verifyEqual(testCase,B.x_mm,0:8);
R.x_mm=[1 99];
X=load_adaptive_req_final_bmode(manifestFile,R);
verifyFalse(testCase,X.available);
verifyTrue(testCase,contains(X.reason,"outside physical B-mode"));
end

function testOriginalAndMaskedPNGWithoutBmode(testCase)
root=string(tempname);
mkdir(root);
guard=onCleanup(@()rmdir(root,"s")); %#ok<NASGU>
R=struct("cs_map",[2.1 2.2;2.4 2.6], ...
    "valid_mask",true(2), ...
    "q_map",[.55 .60;.61 .65], ...
    "x_mm",[18 19],"z_mm",[18;19]);
Q=struct("masked_sws_map",[2.1 NaN;2.4 2.6], ...
    "original_sws_map",R.cs_map,"q_map",R.q_map, ...
    "retained_mask",logical([1 0;1 1]), ...
    "x_mm",R.x_mm,"z_mm",R.z_mm,"cutoff",.147);
B=struct("available",false,"reason","synthetic test");
spec=adaptive_req_final_case_rois("2026Feb27_homo_10perc_sp");
S=render_adaptive_req_final_sws_figures(R,Q,B,spec,root, ...
    FigureFormats="png",ShowROIs=true);
verifyFalse(testCase,S.has_aligned_bmode);
verifyTrue(testCase,S.has_mask);
verifyEqual(testCase,numel(S.files),3);
verifyTrue(testCase,all(S.files_present));
S2=render_adaptive_req_final_sws_figures(R,Q,B,spec,root, ...
    FigureFormats="png",ShowROIs=true);
verifyEqual(testCase,S2.n_rendered,0);
end
