function report=plot_compare_models_500hz(options)
%PLOT_COMPARE_MODELS_500HZ Three-model, mask-free phantom SWS figures.
%
% Plotting/statistics ONLY: never calls reqml.predictSWS, EWP or a mask.
% Uses the ORIGINAL physical ROIs from adaptive_req_final_case_rois.m.
% For experimental phantoms no exact in-situ SWS truth is assumed:
% outputs are median, IQR, paired SWS differences and valid coverage,
% NOT MAPE or accuracy.
%
% Run:
%   P=plot_compare_models_500hz(Mode="plan");
%   R=plot_compare_models_500hz(Mode="run");
arguments
    options.Mode (1,1) string = "plan"
    options.DataRoot (1,1) string = ""
    options.ReqMLRoot (1,1) string = ""
    options.SelectedCaseIDs (1,:) string = strings(1,0)
    options.FrequencyHz (1,1) double {mustBePositive} = 500
    options.M (1,1) double {mustBePositive} = 2
    options.StepPixels (1,1) double {mustBeInteger,mustBePositive} = 3
    options.SwsLimits (1,2) double = [1 4]
    options.DifferenceLimit (1,1) double {mustBePositive} = 0.8
    options.FigureFormats (1,:) string = ["png","pdf"]
    options.ResolutionDPI (1,1) double {mustBePositive} = 300
    options.Visible (1,1) logical = false
end
assert(ismember(options.Mode,["plan","run"]) && ...
    all(ismember(options.FigureFormats,["png","pdf","fig"])) && ...
    options.SwsLimits(1)<options.SwsLimits(2), ...
    "AdaptiveREQ:ComparePlotSettings","Invalid figure settings.");
cfg=compare_models_500hz_config( ...
    DataRoot=options.DataRoot,ReqMLRoot=options.ReqMLRoot, ...
    SelectedCaseIDs=options.SelectedCaseIDs, ...
    FrequencyHz=options.FrequencyHz,M=options.M, ...
    StepPixels=options.StepPixels);
jobs=cfg.jobs;
ready=jobs.original_ready & jobs.clean_ready & jobs.legacy_ready;
fprintf("\n[Three-model experimental SWS figures | %g Hz M=%g step=%d]\n", ...
    cfg.frequency_hz,cfg.M,cfg.step_pixels);
disp(table(jobs.case_id,ready, ...
    'VariableNames',["case_id","three_estimates_ready"]));
report=struct("status","planned","ready",nnz(ready), ...
    "selected",height(jobs),"output_directory",cfg.output_directory);
if options.Mode=="plan",return,end
assert(all(ready), ...
    "Run run_compare_models_500hz first (all three saved maps required).");
addpath(fullfile(cfg.evaluation_root,"src"),"-begin");
addpath(cfg.study_dir,"-begin");
theme=swseval.viz.figureTheme();
cmap=swseval.viz.mapColormap(256);
labels=["Full21 original","Full21 clean","Legacy Q0"];
rows=cell(0,1);
caseData=cell(height(jobs),1);
for j=1:height(jobs)
    J=jobs(j,:);
    paths=[J.original_file,J.clean_file,J.legacy_file];
    maps=cell(1,3);
    for k=1:3
        maps{k}=swseval.io.loadReqmlResult(paths(k));
        meta=maps{k}.metadata;
        assert(string(meta.experimental_case_id)==J.case_id && ...
            string(meta.experimental_arm)==cfg.arms(k) && ...
            double(meta.frequency_hz)==J.frequency_hz && ...
            double(meta.M)==J.M && ...
            double(meta.step_pixels)==J.step_pixels && ...
            string(meta.sample_file)==J.sample_file && ...
            ~logical(meta.experimental_mask_applied), ...
            "AdaptiveREQ:ComparePlotIdentity", ...
            "Map metadata do not match requested unmasked case/model.");
    end
    Z=double(maps{1}.z_mm(:));
    X=double(maps{1}.x_mm(:)).';
    assert(isequal(size(maps{1}.cs_map),[numel(Z),numel(X)]), ...
        "AdaptiveREQ:ComparePlotShape","Invalid physical grid.");
    for k=2:3
        assert(isequaln(maps{k}.x_mm,maps{1}.x_mm) && ...
            isequaln(maps{k}.z_mm,maps{1}.z_mm) && ...
            isequal(size(maps{k}.cs_map),size(maps{1}.cs_map)) && ...
            isequal(string(maps{k}.patch_examples.example_id(:)), ...
                string(maps{1}.patch_examples.example_id(:))), ...
            "AdaptiveREQ:ComparePlotDifferentGrid", ...
            "Three models do not share identical patch centers.");
    end
    spec=adaptive_req_final_case_rois(J.case_id);
    common=true(size(maps{1}.cs_map));
    S=cell(1,3);
    for k=1:3
        S{k}=double(maps{k}.cs_map);
        valid=logical(maps{k}.valid_mask) & ...
            isfinite(S{k}) & S{k}>0;
        S{k}(~valid)=NaN;
        common=common & valid;
    end

    % ROI geometry and common-pixel estimators share one physical mask.
    for ri=1:numel(spec.rois)
        roi=spec.rois(ri);
        c=double(roi.center_mm(:).');
        wh=double(roi.size_mm(:).');
        in=(Z>=c(2)-wh(2)/2 & Z<=c(2)+wh(2)/2) & ...
           (X>=c(1)-wh(1)/2 & X<=c(1)+wh(1)/2);
        nRegion=nnz(in); nCommon=nnz(in&common);
        assert(nRegion>0,"ROI has no matching physical centers.");
        % Each model's descriptive distribution is restricted to common
        % valid ROI centers; that prevents sample-selection confounding.
        zVals=cell(1,3);
        med=nan(1,3); iq=nan(1,3);
        for k=1:3
            zVals{k}=S{k}(in & common);
            if ~isempty(zVals{k})
                med(k)=median(zVals{k});
                iq(k)=iqr(zVals{k});
            end
        end
        da=nan;db=nan;dc=nan;
        if nCommon>0
            da=median(zVals{2}-zVals{1});
            db=median(zVals{3}-zVals{1});
            dc=median(zVals{3}-zVals{2});
        end
        row=table(J.case_id,string(spec.phantom_type), ...
            string(roi.name),J.frequency_hz,J.M,J.step_pixels, ...
            nRegion,nCommon,100*nCommon/nRegion, ...
            med(1),med(2),med(3),iq(1),iq(2),iq(3), ...
            da,db,dc, ...
            'VariableNames',["case_id","phantom","roi","frequency_hz", ...
            "M","step_pixels","roi_pixels","common_valid", ...
            "common_coverage_pct","median_full21_original_m_s", ...
            "median_full21_clean_m_s","median_legacy_q0_m_s", ...
            "iqr_full21_original_m_s","iqr_full21_clean_m_s", ...
            "iqr_legacy_q0_m_s","median_clean_minus_original_m_s", ...
            "median_legacy_minus_original_m_s", ...
            "median_legacy_minus_clean_m_s"]);
        rows{end+1,1}=row; %#ok<AGROW>
    end
    caseData{j}=struct("case_id",J.case_id,"x",X,"z",Z, ...
        "maps",{S},"rois",spec.rois,"common",common);
    fprintf("  [%d/%d] %s | %d common-valid pixels\n", ...
        j,height(jobs),J.case_id,nnz(common));
end
T=vertcat(rows{:});
base=fullfile(cfg.output_directory,"figures");
if ~isfolder(base),mkdir(base);end
writetable(T,fullfile(cfg.output_directory,"roi_descriptive_statistics.csv"));
save(fullfile(cfg.output_directory,"roi_descriptive_statistics.mat"), ...
    "T","-v7.3");

% One three-model montage per acquisition with identical SWS color limits.
for j=1:height(jobs)
    D=caseData{j};
    f=figure("Visible",visibility(options.Visible), ...
        "Color","w","Units","inches","Position",[1 1 10.8 3.65]);
    guard=onCleanup(@()close(f));
    tiled=tiledlayout(f,1,3,"TileSpacing","compact","Padding","compact");
    for k=1:3
        ax=nexttile(tiled);
        draw_map(ax,D.x,D.z,D.maps{k},D.rois, ...
            options.SwsLimits,cmap,theme);
        title(ax,labels(k),"FontWeight","normal");
        if k~=1,ylabel(ax,"");end
        if k==3
            cb=colorbar(ax);cb.Label.String="SWS (m/s)";
        end
    end
    name=fullfile(base,D.case_id+"_three_model_sws");
    export_fig(f,name,options.FigureFormats,options.ResolutionDPI);
    clear guard

    % Unmasked pixelwise SWS differences, not percentage error to truth.
    f=figure("Visible",visibility(options.Visible), ...
        "Color","w","Units","inches","Position",[1 1 10.8 3.65]);
    guard=onCleanup(@()close(f));
    tiled=tiledlayout(f,1,3,"TileSpacing","compact","Padding","compact");
    diffs={D.maps{2}-D.maps{1},D.maps{3}-D.maps{1}, ...
        D.maps{3}-D.maps{2}};
    names=["Clean - original","Legacy - original","Legacy - clean"];
    diverging=blue_white_red(256);
    for k=1:3
        ax=nexttile(tiled);
        draw_map(ax,D.x,D.z,diffs{k},D.rois, ...
            [-options.DifferenceLimit options.DifferenceLimit], ...
            diverging,theme);
        title(ax,names(k),"FontWeight","normal");
        if k~=1,ylabel(ax,"");end
        if k==3
            cb=colorbar(ax);cb.Label.String="Difference in SWS (m/s)";
        end
    end
    export_fig(f,fullfile(base,D.case_id+"_three_model_differences"), ...
        options.FigureFormats,options.ResolutionDPI);
    clear guard
end

% Across acquisitions: physical ROI medians, not independent-pixel CI.
f=figure("Visible",visibility(options.Visible), ...
    "Color","w","Units","inches","Position",[1 1 10 4.1]);
guard=onCleanup(@()close(f));
ax=axes(f);hold(ax,"on");
Y=[T.median_full21_original_m_s, ...
    T.median_full21_clean_m_s,T.median_legacy_q0_m_s];
barHandle=bar(ax,1:height(T),Y,"grouped");
palette=[theme.roi_colors(2,:);theme.roi_colors(3,:); ...
    theme.roi_colors(1,:)];
for k=1:3,barHandle(k).FaceColor=palette(k,:);end
xticks(ax,1:height(T));
xticklabels(ax,T.case_id+" / "+T.roi);
xtickangle(ax,50);
ylabel(ax,"Median SWS on common ROI pixels (m/s)");
legend(ax,labels,"Location","best","Box","off");
set(ax,"FontName",char(theme.font),"FontSize",theme.font_size_pt, ...
    "TickDir","out","Box","off");
export_fig(f,fullfile(base,"all_cases_roi_medians"), ...
    options.FigureFormats,options.ResolutionDPI);
clear guard

report.status="completed";
report.roi_statistics=T;
report.figure_directory=base;
fprintf("[DONE] Six acquisitions, mask-free maps and ROI descriptions: %s\n",base);
fprintf("No experimental SWS MAPE claimed (no exact independent truth).\n");
end

function draw_map(ax,x,z,A,rois,lims,cmap,theme)
h=imagesc(ax,x,z,A);
h.AlphaData=double(isfinite(A));
set(ax,"YDir","normal","FontName",char(theme.font), ...
    "FontSize",theme.font_size_pt,"TickDir","out","Box","on");
axis(ax,"image");clim(ax,lims);colormap(ax,cmap);
xlabel(ax,"x (mm)");ylabel(ax,"z (mm)");
hold(ax,"on");
for r=1:numel(rois)
    roi=rois(r);
    c=double(roi.center_mm(:).');
    wh=double(roi.size_mm(:).');
    pos=[c(1)-wh(1)/2,c(2)-wh(2)/2,wh];
    rectangle(ax,"Position",pos,"LineWidth",1.2, ...
        "LineStyle","--","EdgeColor", ...
        theme.roi_colors(mod(r-1,size(theme.roi_colors,1))+1,:));
end
hold(ax,"off");
end

function cmap=blue_white_red(n)
anchors=[0.18 0.31 0.7;1 1 1;0.78 0.20 0.17];
cmap=interp1([0 .5 1],anchors,linspace(0,1,n),"linear");
end

function s=visibility(tf)
s="off";if tf,s="on";end
end

function export_fig(fig,path,formats,dpi)
for format=formats
    target=path+"."+format;
    switch format
        case "png"
            exportgraphics(fig,target,Resolution=dpi,BackgroundColor="white");
        case "pdf"
            exportgraphics(fig,target,ContentType="vector", ...
                BackgroundColor="white");
        case "fig"
            savefig(fig,target);
    end
end
end
