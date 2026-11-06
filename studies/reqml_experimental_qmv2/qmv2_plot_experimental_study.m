function files=qmv2_plot_experimental_study(C,jobs,models)
%QMV2_PLOT_EXPERIMENTAL_STUDY Plot experimental ROIs and frozen-model maps.
% No ground truth is assumed for phantom measurements. Only ROI statistics
% precomputed by Stage=analyze are consumed for frequency curves.
arms=string(models.arm(:))';
nArms=numel(arms);
labels=shortLabels(arms);
[colors,styles]=modelStyles(arms);
files=strings(0,1);
caseIDs=unique(string(jobs.case_id),"stable");
for id=caseIDs'
    caseRows=jobs(jobs.case_id==id,:);
    root=string(caseRows.dataset_root(1));
    directory=fullfile(root,"analysis",C.study_id, ...
        "M"+string(C.m)+"_step"+string(C.step_pixels), ...
        C.analysis_version);
    file=fullfile(directory,"qmv2_experimental_roi_summary.csv");
    assert(isfile(file),"ExpQMV2:PlotNeedsAnalysis", ...
        "Run Stage=analyze before plot: %s",file);
    S=readtable(file,TextType="string",VariableNamingRule="preserve");
    assert(isequal(sort(unique(string(S.model))),sort(arms(:))), ...
        "ExpQMV2:PlotArms","Saved ROI summary has a different model set.");
    plotDir=fullfile(directory,"comparison_figures");
    if ~isfolder(plotDir),mkdir(plotDir);end
    roiNames=unique(string(S.roi),"stable");
    for roi=roiNames'
        F=S(string(S.roi)==roi,:);
        fig=figure("Visible","off","Color","w", ...
            "Position",[50 50 1400 650]);
        tl=tiledlayout(fig,1,2,"TileSpacing","compact", ...
            "Padding","compact");
        ax=nexttile(tl);hold(ax,"on");
        cvAx=nexttile(tl);hold(cvAx,"on");
        handles=gobjects(1,nArms);
        for ai=1:nArms
            Q=sortrows(F(string(F.model)==arms(ai),:),"frequency_hz");
            x=double(Q.frequency_hz);
            handles(ai)=errorbar(ax,x,double(Q.mean_sws_m_s), ...
                double(Q.spatial_sd_m_s),"o", ...
                "LineStyle",styles(ai),"Color",colors(ai,:), ...
                "LineWidth",1.4,"CapSize",4,"MarkerSize",5);
            plot(cvAx,x,double(Q.cv_percent),"o", ...
                "LineStyle",styles(ai),"Color",colors(ai,:), ...
                "LineWidth",1.4,"MarkerSize",5);
        end
        ylabel(ax,"Mean SWS ± spatial SD (m/s)");
        ylabel(cvAx,"Spatial CV (%)");
        xlabel(ax,"Frequency (Hz)");
        xlabel(cvAx,"Frequency (Hz)");
        title(ax,"Speed by frequency");
        title(cvAx,"Spatial variation");
        if all(isfinite(S.reference_sws_m_s)) && ...
                numel(unique(double(S.reference_sws_m_s)))==1
            yline(ax,double(S.reference_sws_m_s(1)), ...
                "k--","Reference","HandleVisibility","off");
        end
        for a=[ax cvAx]
            xticks(a,unique(double(F.frequency_hz))');
            grid(a,"on");box(a,"on");
        end
        legendHandle=legend(ax,handles,cellstr(labels), ...
            "Interpreter","none","Box","off", ...
            "NumColumns",min(5,nArms));
        legendHandle.Layout.Tile="south";
        note="";
        if any(~logical(F.roi_configured))
            note=" | unsegmented full FOV (exploratory)";
        end
        title(tl,id+" | "+roi+" | M="+string(C.m)+note, ...
            "Interpreter","none");
        figName=fullfile(plotDir,"frequency_"+roi+"_M"+string(C.m)+".png");
        exportgraphics(fig,figName,Resolution=160);
        files(end+1,1)=figName; %#ok<AGROW>
        close(fig);
    end
    caseSpec=C.cases(string({C.cases.id})==id);
    if isfield(caseSpec,"contrasts") && ~isempty(caseSpec.contrasts)
        contrastFile=fullfile(directory,"qmv2_inclusion_contrasts.csv");
        assert(isfile(contrastFile),"ExpQMV2:PlotContrastMissing", ...
            "Run Stage=analyze to generate contrast data: %s",contrastFile);
        CT=readtable(contrastFile,TextType="string", ...
            VariableNamingRule="preserve");
        for c=unique(string(CT.contrast_name),"stable")'
            subset=CT(string(CT.contrast_name)==c,:);
            fig=figure("Visible","off","Color","w", ...
                "Position",[50 50 1400 650]);
            tl=tiledlayout(fig,1,2, ...
                "TileSpacing","compact","Padding","compact");
            ax=nexttile(tl);hold(ax,"on");
            cx=nexttile(tl);hold(cx,"on");
            handles=gobjects(1,nArms);
            for ai=1:nArms
                Y=sortrows(subset(string(subset.model)==arms(ai),:), ...
                    "frequency_hz");
                assert(~isempty(Y),"ExpQMV2:PlotContrastArms", ...
                    "Missing %s for model %s.",c,arms(ai));
                handles(ai)=plot(ax,double(Y.frequency_hz), ...
                    double(Y.median_contrast_percent),"o", ...
                    "LineStyle",styles(ai),"Color",colors(ai,:), ...
                    "LineWidth",1.4,"MarkerSize",5);
                plot(cx,double(Y.frequency_hz), ...
                    double(Y.spatial_cnr),"o", ...
                    "LineStyle",styles(ai),"Color",colors(ai,:), ...
                    "LineWidth",1.4,"MarkerSize",5);
            end
            yline(ax,0,"k:","HandleVisibility","off");
            yline(cx,0,"k:","HandleVisibility","off");
            xlabel(ax,"Frequency (Hz)");
            xlabel(cx,"Frequency (Hz)");
            ylabel(ax,"Median contrast (%)");
            ylabel(cx,"Spatial CNR (dimensionless)");
            title(ax,"Inclusion / background median contrast");
            title(cx,"Mean difference / pooled spatial SD");
            for a=[ax cx]
                xticks(a,unique(double(subset.frequency_hz))');
                grid(a,"on");box(a,"on");
            end
            lg=legend(ax,handles,cellstr(labels), ...
                "Interpreter","none","Box","off", ...
                "NumColumns",min(5,nArms));
            lg.Layout.Tile="south";
            suffix="";
            if any(~logical(subset.roi_pair_within_fov))
                suffix=" | WARNING: partial ROI coverage";
            end
            title(tl,id+" | "+c+" | M="+string(C.m)+suffix, ...
                "Interpreter","none");
            figName=fullfile(plotDir,"contrast_"+c+ ...
                "_M"+string(C.m)+".png");
            exportgraphics(fig,figName,Resolution=160);
            files(end+1,1)=figName; %#ok<AGROW>
            close(fig);
        end
    end

    cols=min(5,nArms);
    nr=ceil(nArms/cols);
    for ji=1:height(caseRows)
        job=caseRows(ji,:);
        fig=figure("Visible","off","Color","w", ...
            "Position",[30 30 320*cols+110 370*nr+110]);
        tl=tiledlayout(fig,nr,cols, ...
            "TileSpacing","compact","Padding","compact");
        axlist=gobjects(1,nArms);
        for ai=1:nArms
            resultFile=fullfile(job.dataset_root,"estimates",C.study_id, ...
                "REQ-ML",arms(ai),sprintf("%gHz",job.frequency_hz), ...
                "M"+string(C.m),"step"+string(C.step_pixels), ...
                "reqml_result.mat");
            map=swseval.io.loadReqmlResult(resultFile);
            ax=nexttile(tl);
            axlist(ai)=ax;
            pixels=double(map.cs_map);
            pixels(~map.valid_mask)=NaN;
            imagesc(ax,double(map.x_mm),double(map.z_mm),pixels);
            axis(ax,"image");
            set(ax,"YDir","normal");
            clim(ax,C.sws_limits);
            colormap(ax,"turbo");
            title(ax,labels(ai),"Interpreter","none","FontSize",10);
            gridRow=ceil(ai/cols);
            gridCol=mod(ai-1,cols)+1;
            if gridRow==nr
                xlabel(ax,"x (mm)");
            else
                set(ax,"XTickLabel",[]);
            end
            if gridCol==1
                ylabel(ax,"z (mm)");
            else
                set(ax,"YTickLabel",[]);
            end
            if isfield(caseSpec,"rois") && ~isempty(caseSpec.rois)
                hold(ax,"on");
                for ri=1:numel(caseSpec.rois)
                    roi=caseSpec.rois(ri);
                    center=double(roi.center_mm(:)');
                    sz=double(roi.size_mm(:)');
                    pos=[center(1)-sz(1)/2, ...
                        center(2)-sz(2)/2,sz(1),sz(2)];
                    rectangle(ax,"Position",pos, ...
                        "LineStyle","--","LineWidth",1.3, ...
                        "EdgeColor","white");
                    if ai==1
                        text(ax,pos(1)+0.3,pos(2)+0.3,string(roi.name), ...
                            "Color","white","FontSize",8, ...
                            "FontWeight","bold");
                    end
                end
            end
        end
        bar=colorbar(axlist(end));
        bar.Layout.Tile="east";
        ylabel(bar,"SWS (m/s)");
        title(tl,id+" | "+string(job.frequency_hz)+" Hz | M="+ ...
            string(C.m)+" | shared SWS scale", ...
            "Interpreter","none");
        figName=fullfile(plotDir,"maps_"+ ...
            string(job.frequency_hz)+"Hz_M"+string(C.m)+".png");
        exportgraphics(fig,figName,Resolution=160);
        files(end+1,1)=figName; %#ok<AGROW>
        close(fig);
    end
    fprintf("QMV2 experimental maps and plots for %s -> %s\n",id,plotDir);
end
end

function labels=shortLabels(arms)
labels=arms;
for k=1:numel(arms)
    a=arms(k);
    if a=="reduced14",labels(k)="R14 raw";continue,end
    if a=="reduced14_filtered",labels(k)="R14 donut";continue,end
    if startsWith(a,"qmv2_unfiltered_")
        subset=extractAfter(a,"qmv2_unfiltered_");
        suffix=" raw";
    elseif startsWith(a,"qmv2_fixed_donut_")
        subset=extractAfter(a,"qmv2_fixed_donut_");
        suffix=" donut";
    else
        continue
    end
    switch subset
        case "reduced14"
            labels(k)="Q14"+suffix;
        case "reduced14_frequency"
            labels(k)="Q14+f"+suffix;
        case "expanded20"
            labels(k)="Q20"+suffix;
        case "expanded20_frequency"
            labels(k)="Q20+f"+suffix;
    end
end
end

function [colors,styles]=modelStyles(arms)
families=strings(size(arms));
styles=strings(size(arms));
for k=1:numel(arms)
    a=arms(k);
    if a=="reduced14" || a=="reduced14_filtered"
        families(k)="frozen14";
    else
        families(k)=erase(erase(a,"qmv2_unfiltered_"),"qmv2_fixed_donut_");
    end
    styles(k)="-";
    if contains(a,["fixed_donut","_filtered"]),styles(k)="--";end
end
keys=unique(families,"stable");
palette=lines(numel(keys));
colors=zeros(numel(arms),3);
for k=1:numel(arms)
    colors(k,:)=palette(find(keys==families(k),1),:);
end
end
