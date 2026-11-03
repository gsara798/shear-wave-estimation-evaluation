function files=plot_swsynth_comparison(C,options)
%PLOT_SWSYNTH_COMPARISON Paired frequency plots and per-case SWS montages.
% Spatial standard deviation is not uncertainty of the mean.
arguments
    C (1,1) struct
    options.MakeMontages (1,1) logical = true
    options.SavePDF (1,1) logical = false
end
summaryFile=fullfile(C.analysisRoot,"all_cases_roi_statistics.csv");
assert(isfile(summaryFile),"SynthCompare:PlotsNeedAnalysis", ...
    "Run Stage=analyze before plotting.");
T=readtable(summaryFile,TextType="string", ...
    VariableNamingRule="preserve");
assert(all(ismember(["series","model","name","frequency_hz", ...
    "mean_sws_common","mape_percent_common", ...
    "cv_percent_common","median_q_common"], ...
    string(T.Properties.VariableNames))), ...
    "SynthCompare:PlotsSchema","ROI CSV is missing expected columns.");
assert(isequal(unique(string(T.model),"stable"),C.Arms') || ...
    isequal(sort(unique(string(T.model))),sort(C.Arms(:))), ...
    "SynthCompare:ArmsDiffer", ...
    "Analysis model arms differ; rerun Stage=analyze for this selection.");
colors=lines(numel(C.Arms));
root=fullfile(C.analysisRoot,"comparison_figures");
if ~isfolder(root),mkdir(root);end
files=strings(0,1);
series=unique(string(T.series),"stable");
for s=series'
    S=T(string(T.series)==s,:);
    roiNames=unique(string(S.name),"stable");
    for rn=roiNames'
        fig=figure("Visible","off","Color","w", ...
            "Position",[40 40 1330 860]);
        tiles=tiledlayout(fig,2,2,"Padding","compact", ...
            "TileSpacing","compact");
        a1=nexttile(tiles);hold(a1,"on");
        a2=nexttile(tiles);hold(a2,"on");
        a3=nexttile(tiles);hold(a3,"on");
        a4=nexttile(tiles);hold(a4,"on");
        truth=NaN;
        for ai=1:numel(C.Arms)
            A=S(string(S.model)==C.Arms(ai) & ...
                string(S.name)==rn,:);
            A=sortrows(A,"frequency_hz");
            assert(height(A)==4 && ...
                isequal(double(A.frequency_hz),C.Frequencies'), ...
                "SynthCompare:PlotCoverage", ...
                "Missing frequency in %s/%s/%s",s,rn,C.Arms(ai));
            f=double(A.frequency_hz);
            mu=double(A.mean_sws_common);
            sd=double(A.std_sws_common);
            truth=double(A.reference_cs_m_s(1));
            errorbar(a1,f,mu,sd,sd,"-o", ...
                "Color",colors(ai,:),"LineWidth",1.5, ...
                "CapSize",5,"DisplayName",C.Arms(ai));
            plot(a2,f,double(A.mape_percent_common),"-o", ...
                "Color",colors(ai,:),"LineWidth",1.5, ...
                "DisplayName",C.Arms(ai));
            plot(a3,f,double(A.cv_percent_common),"-o", ...
                "Color",colors(ai,:),"LineWidth",1.5);
            plot(a4,f,double(A.median_q_common),"-o", ...
                "Color",colors(ai,:),"LineWidth",1.5);
        end
        yline(a1,truth,"k--","True SWS", ...
            "LineWidth",1.4,LabelHorizontalAlignment="left");
        ylabel(a1,"ROI SWS mean ± spatial SD (m/s)");
        ylabel(a2,"ROI MAPE (%)");
        ylabel(a3,"Within-ROI CV (%)");
        ylabel(a4,"Median predicted q");
        for ax=[a1 a2 a3 a4]
            xticks(ax,C.Frequencies);
            xlim(ax,[300 600]);
            xlabel(ax,"Frequency (Hz)");
            grid(ax,"on");
        end
        legend(a1,"Location","best","Interpreter","none");
        title(tiles,s+" | "+rn+" | frozen models, M="+string(C.M), ...
            "Interpreter","none");
        base=fullfile(root,"frequency_"+s+"_"+rn+"_M"+string(C.M));
        files=[files;publishFigure(fig,base,options.SavePDF)]; %#ok<AGROW>
        close(fig);
    end
end
if ~options.MakeMontages,return,end
for i=1:height(C.Cases)
    row=C.Cases(i,:);
    [rois,~]=swsynth_comparison_rois(row.group(1), ...
        row.reference_cs_m_s(1));
    fig=figure("Visible","off","Color","w", ...
        "Position",[35 40 max(1300,300*numel(C.Arms)) 540]);
    tiles=tiledlayout(fig,1,numel(C.Arms), ...
        "TileSpacing","compact","Padding","compact");
    for ai=1:numel(C.Arms)
        path=swsynth_comparison_estimate_file(C,row,C.Arms(ai));
        map=swseval.io.loadReqmlResult(path);
        ax=nexttile(tiles);
        data=double(map.cs_map);
        data(~map.valid_mask)=NaN;
        imagesc(ax,double(map.x_mm),double(map.z_mm),data);
        axis(ax,"image");
        set(ax,"YDir","normal");
        colormap(ax,"turbo");
        clim(ax,C.SWSColorLimits);
        xlabel(ax,"x (mm)");
        if ai==1,ylabel(ax,"z (mm)");end
        title(ax,C.Arms(ai),"Interpreter","none");
        hold(ax,"on");
        for ri=1:numel(rois)
            r=rois(ri);
            pos=[r.center(1)-r.size(1)/2, ...
                r.center(2)-r.size(2)/2,r.size(1),r.size(2)];
            rectangle(ax,"Position",pos, ...
                "EdgeColor","white","LineWidth",1.4, ...
                "LineStyle","--");
            if ai==1
                text(ax,pos(1),pos(2),string(r.name), ...
                    "Color","white","FontWeight","bold", ...
                    "VerticalAlignment","bottom");
            end
        end
        if ai==numel(C.Arms)
            colorbar(ax);
        end
    end
    title(tiles,row.case_id(1)+" | M="+string(C.M), ...
        "Interpreter","none");
    base=fullfile(root,"maps_"+row.case_id(1)+"_M"+string(C.M));
    files=[files;publishFigure(fig,base,options.SavePDF)]; %#ok<AGROW>
    close(fig);
end
fprintf("Comparison figures: %s (%d files)\n",root,numel(files));
end

function paths=publishFigure(fig,base,makePdf)
exportgraphics(fig,base+".png",Resolution=175);
paths=base+".png";
if makePdf
    exportgraphics(fig,base+".pdf",ContentType="vector");
    paths=[paths;base+".pdf"];
end
end
