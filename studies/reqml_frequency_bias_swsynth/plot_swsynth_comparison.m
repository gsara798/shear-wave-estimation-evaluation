function files=plot_swsynth_comparison(C,options)
%PLOT_SWSYNTH_COMPARISON Publication-oriented ROI frequency curves and maps.
% Independent model/ROI metrics are NOT changed by this plotting routine.
% Error bars are spatial SD (not standard error or confidence intervals).
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
assert(isequal(sort(unique(string(T.model))),sort(C.Arms(:))), ...
    "SynthCompare:ArmsDiffer", ...
    "Analysis model arms differ; rerun Stage=analyze for this selection.");
modelLabels=swsynth_short_model_names(C.Arms);
assert(numel(unique(modelLabels))==numel(modelLabels), ...
    "SynthCompare:PlotLabels","Non-unique short model labels.");
[colors,styles]=styleForArms(C.Arms);
root=fullfile(C.analysisRoot,"comparison_figures");
if ~isfolder(root),mkdir(root);end
files=strings(0,1);
series=unique(string(T.series),"stable");

% One four-panel figure per physical series/ROI, with short labels and
% a single layout-level legend below the panels.
for s=series'
    S=T(string(T.series)==s,:);
    roiNames=unique(string(S.name),"stable");
    for rn=roiNames'
        fig=figure("Visible","off","Color","w", ...
            "Position",[40 40 1480 880]);
        tiles=tiledlayout(fig,2,2,"Padding","compact", ...
            "TileSpacing","compact");
        a1=nexttile(tiles);hold(a1,"on");
        a2=nexttile(tiles);hold(a2,"on");
        a3=nexttile(tiles);hold(a3,"on");
        a4=nexttile(tiles);hold(a4,"on");
        handles=gobjects(1,numel(C.Arms));
        truth=NaN;
        for ai=1:numel(C.Arms)
            A=S(string(S.model)==C.Arms(ai) & ...
                string(S.name)==rn,:);
            A=sortrows(A,"frequency_hz");
            assert(height(A)==4 && ...
                isequal(double(A.frequency_hz),C.Frequencies'), ...
                "SynthCompare:PlotCoverage", ...
                "Missing frequency in %s/%s/%s.",s,rn,C.Arms(ai));
            f=double(A.frequency_hz);
            mu=double(A.mean_sws_common);
            sd=double(A.std_sws_common);
            truth=double(A.reference_cs_m_s(1));
            handles(ai)=errorbar(a1,f,mu,sd,"o", ...
                "LineStyle",styles(ai),"Color",colors(ai,:), ...
                "LineWidth",1.35,"MarkerSize",5,"CapSize",4);
            plot(a2,f,double(A.mape_percent_common),"o", ...
                "LineStyle",styles(ai),"Color",colors(ai,:), ...
                "LineWidth",1.35,"MarkerSize",5);
            plot(a3,f,double(A.cv_percent_common),"o", ...
                "LineStyle",styles(ai),"Color",colors(ai,:), ...
                "LineWidth",1.35,"MarkerSize",5);
            plot(a4,f,double(A.median_q_common),"o", ...
                "LineStyle",styles(ai),"Color",colors(ai,:), ...
                "LineWidth",1.35,"MarkerSize",5);
        end
        yline(a1,truth,"k--","Reference", ...
            "LineWidth",1.1,"HandleVisibility","off");
        ylabel(a1,"Mean SWS ± spatial SD (m/s)");
        ylabel(a2,"MAPE (%)");
        ylabel(a3,"Spatial CV (%)");
        ylabel(a4,"Median q");
        title(a1,"Speed");
        title(a2,"Absolute relative error");
        title(a3,"Spatial variability");
        title(a4,"Estimated quantile");
        for ax=[a1 a2 a3 a4]
            xticks(ax,C.Frequencies);
            xlim(ax,[C.Frequencies(1) C.Frequencies(end)]);
            grid(ax,"on");
            box(ax,"on");
        end
        set([a1 a2],"XTickLabel",[]);
        xlabel(a3,"Frequency (Hz)");
        xlabel(a4,"Frequency (Hz)");
        lg=legend(a1,handles,cellstr(modelLabels), ...
            "Interpreter","none", ...
            "NumColumns",min(5,numel(C.Arms)), ...
            "Box","off");
        lg.Layout.Tile="south";
        title(tiles,s+" | "+rn+" | M="+string(C.M)+ ...
            " | spatial SD, shared valid ROI", ...
            "Interpreter","none");
        base=fullfile(root,"frequency_"+s+"_"+rn+"_M"+string(C.M));
        files=[files;publishFigure(fig,base,options.SavePDF)]; %#ok<AGROW>
        close(fig);
    end
end

% A direct soft-versus-hard comparison makes the inter-layer trend readable
% without copying model IDs into two separate legends.
if any(string(T.group)=="plane_bilayer")
    fig=figure("Visible","off","Color","w", ...
        "Position",[40 40 1580 700]);
    tiles=tiledlayout(fig,1,2,"Padding","compact", ...
        "TileSpacing","compact");
    bilayer=T(string(T.group)=="plane_bilayer",:);
    layers=["soft","hard"];
    handles=gobjects(1,numel(C.Arms));
    for li=1:2
        ax=nexttile(tiles);hold(ax,"on");
        truth=NaN;
        for ai=1:numel(C.Arms)
            A=bilayer(string(bilayer.model)==C.Arms(ai) & ...
                string(bilayer.name)==layers(li),:);
            A=sortrows(A,"frequency_hz");
            assert(height(A)==4 && ...
                isequal(double(A.frequency_hz),C.Frequencies'), ...
                "SynthCompare:BilayerPlotCoverage", ...
                "Bilayer %s missing frequency for %s.", ...
                layers(li),C.Arms(ai));
            truth=double(A.reference_cs_m_s(1));
            lineHandle=plot(ax,double(A.frequency_hz), ...
                double(A.mean_sws_common),"o", ...
                "LineStyle",styles(ai),"Color",colors(ai,:), ...
                "LineWidth",1.5,"MarkerSize",5);
            if li==1,handles(ai)=lineHandle;end
        end
        yline(ax,truth,"k--","Reference", ...
            "LineWidth",1.1,"HandleVisibility","off");
        title(ax,"Bilayer — "+layers(li));
        ylabel(ax,"Mean SWS (m/s)");
        xlabel(ax,"Frequency (Hz)");
        xticks(ax,C.Frequencies);
        xlim(ax,[C.Frequencies(1) C.Frequencies(end)]);
        grid(ax,"on");box(ax,"on");
    end
    lg=legend(handles,cellstr(modelLabels), ...
        "Interpreter","none","NumColumns",min(5,numel(C.Arms)), ...
        "Box","off");
    lg.Layout.Tile="south";
    title(tiles,"Bilayer | soft vs hard | M="+string(C.M), ...
        "Interpreter","none");
    base=fullfile(root,"bilayer_soft_hard_comparison_M"+string(C.M));
    files=[files;publishFigure(fig,base,options.SavePDF)]; %#ok<AGROW>
    close(fig);
end

if ~options.MakeMontages
    fprintf("Comparison figures: %s (%d files)\n",root,numel(files));
    return
end

% Maps use at most FIVE columns, a common color scale and ONE colorbar.
% Only the outermost axes display numeric x/z ticks and axis labels.
for i=1:height(C.Cases)
    row=C.Cases(i,:);
    [rois,~]=swsynth_comparison_rois(row.group(1), ...
        row.reference_cs_m_s(1));
    n=numel(C.Arms);
    cols=min(5,n);
    rows=ceil(n/cols);
    fig=figure("Visible","off","Color","w", ...
        "Position",[35 40 max(700,320*cols) max(500,380*rows+110)]);
    tiles=tiledlayout(fig,rows,cols, ...
        "TileSpacing","compact","Padding","compact");
    axesList=gobjects(1,n);
    for ai=1:n
        file=swsynth_comparison_estimate_file(C,row,C.Arms(ai));
        map=swseval.io.loadReqmlResult(file);
        ax=nexttile(tiles);
        axesList(ai)=ax;
        data=double(map.cs_map);
        data(~map.valid_mask)=NaN;
        imagesc(ax,double(map.x_mm),double(map.z_mm),data);
        axis(ax,"image");
        set(ax,"YDir","normal");
        colormap(ax,"turbo");
        clim(ax,C.SWSColorLimits);
        title(ax,modelLabels(ai),"Interpreter","none","FontSize",10);
        rowNumber=ceil(ai/cols);
        colNumber=mod(ai-1,cols)+1;
        if rowNumber==rows
            xlabel(ax,"x (mm)");
        else
            set(ax,"XTickLabel",[]);
        end
        if colNumber==1
            ylabel(ax,"z (mm)");
        else
            set(ax,"YTickLabel",[]);
        end
        hold(ax,"on");
        for ri=1:numel(rois)
            roi=rois(ri);
            pos=[roi.center(1)-roi.size(1)/2, ...
                roi.center(2)-roi.size(2)/2, ...
                roi.size(1),roi.size(2)];
            rectangle(ax,"Position",pos, ...
                "EdgeColor","white","LineWidth",1.4, ...
                "LineStyle","--");
            if ai==1
                text(ax,pos(1)+0.3,pos(2)+0.3,string(roi.name), ...
                    "Color","white","FontWeight","bold", ...
                    "FontSize",9,"VerticalAlignment","bottom");
            end
        end
    end
    cb=colorbar(axesList(end));
    cb.Layout.Tile="east";
    ylabel(cb,"SWS (m/s)");
    title(tiles,row.case_id(1)+" | M="+string(C.M)+ ...
        " | same scale and ROI in every panel", ...
        "Interpreter","none");
    base=fullfile(root,"maps_"+row.case_id(1)+"_M"+string(C.M));
    files=[files;publishFigure(fig,base,options.SavePDF)]; %#ok<AGROW>
    close(fig);
end
fprintf("Comparison figures: %s (%d files)\n",root,numel(files));
end

function [colors,styles]=styleForArms(arms)
% Raw and donut variants of the same model family share a color.
families=strings(size(arms));
styles=strings(size(arms));
for i=1:numel(arms)
    arm=arms(i);
    if startsWith(arm,"qmv2_unfiltered_")
        families(i)="QMV2_"+extractAfter(arm,"qmv2_unfiltered_");
        styles(i)="-";
    elseif startsWith(arm,"qmv2_fixed_donut_")
        families(i)="QMV2_"+extractAfter(arm,"qmv2_fixed_donut_");
        styles(i)="--";
    elseif arm=="reduced14" || arm=="reduced14_filtered"
        families(i)="Frozen_reduced14";
        if arm=="reduced14_filtered",styles(i)="--";
        else,styles(i)="-";end
    else
        families(i)=arm;
        styles(i)="-";
    end
end
uniqueFamilies=unique(families,"stable");
palette=lines(numel(uniqueFamilies));
colors=zeros(numel(arms),3);
for i=1:numel(arms)
    colors(i,:)=palette(find(uniqueFamilies==families(i),1),:);
end
end

function paths=publishFigure(fig,base,makePdf)
exportgraphics(fig,base+".png",Resolution=175);
paths=base+".png";
if makePdf
    exportgraphics(fig,base+".pdf",ContentType="vector");
    paths=[paths;base+".pdf"];
end
end
