function summary=render_adaptive_req_final_sws_figures(R,Q,B,caseInfo,outputRoot,options)
%RENDER_ADAPTIVE_REQ_FINAL_SWS_FIGURES Paper-ready original/masked SWS maps.
% Stage-02 R and stage-03 Q are immutable inputs; figures only.
% Reuses SWSEval canonical SWS colormap and ROI paper theme.
%
% Outputs individual PNG/PDF/FIG files:
%   sws_original_plain
%   sws_original_bmode_rois (only when B-mode is physically aligned)
%   sws_masked_plain
%   sws_masked_bmode_rois (requires mask and aligned B-mode)
% and, when masked data exist, a shared-colorbar comparison:
%   sws_comparison_2x2 (with B-mode), or sws_comparison_1x2 (no B-mode).
arguments
    R (1,1) struct
    Q (1,1) struct
    B (1,1) struct
    caseInfo (1,1) struct
    outputRoot (1,1) string
    options.SwsLimits (1,2) double = [1.5 3.5]
    options.SwsTicks (1,:) double = 1.5:0.5:3.5
    options.TickDecimals (1,1) double = 1
    options.OverlayAlpha (1,1) double = 0.70
    options.FigureFormats (1,:) string = ["png","pdf","fig"]
    options.Visible (1,1) logical = false
    options.Overwrite (1,1) logical = false
    options.ShowROIs (1,1) logical = true
    options.SaveIndividual (1,1) logical = true
    options.SaveCombined (1,1) logical = true
end
formats=unique(lower(options.FigureFormats),"stable");
assert(~isempty(formats) && all(ismember(formats,["png","pdf","fig"])) && ...
    all(options.SwsLimits==[1.5 3.5]) && ...
    isequal(options.SwsTicks,1.5:0.5:3.5) && ...
    options.TickDecimals==1 && ...
    options.OverlayAlpha>=0 && options.OverlayAlpha<=1, ...
    "AdaptiveREQ:PlotFormatPolicy", ...
    "Final figures must use supported formats and the frozen SWS display scale.");
assert(isfield(R,"cs_map") && isfield(R,"valid_mask") && ...
    isfield(R,"x_mm") && isfield(R,"z_mm"), ...
    "AdaptiveREQ:PlotOriginalMap","Stage 02 lacks physical SWS map.");
original=double(R.cs_map);
original(~logical(R.valid_mask))=NaN;
x=double(R.x_mm(:)');
z=double(R.z_mm(:));
assert(ismatrix(original) && ...
    isequal(size(original),[numel(z),numel(x)]) && ...
    all(diff(x)>0) && all(diff(z)>0), ...
    "AdaptiveREQ:PlotGrid","Original SWS map/axes are inconsistent.");
hasMask=isfield(Q,"masked_sws_map") && ~isempty(Q.masked_sws_map);
hasBmode=isfield(B,"available") && logical(B.available);
if hasMask
    mandatory=["masked_sws_map","original_sws_map","q_map", ...
        "retained_mask","x_mm","z_mm","cutoff"];
    assert(all(isfield(Q,cellstr(mandatory))) && ...
        isequaln(double(Q.original_sws_map),double(R.cs_map)) && ...
        isequaln(double(Q.q_map),double(R.q_map)) && ...
        isequal(double(Q.x_mm(:)),double(R.x_mm(:))) && ...
        isequal(double(Q.z_mm(:)),double(R.z_mm(:))) && ...
        isequal(size(Q.masked_sws_map),size(original)), ...
        "AdaptiveREQ:PlotMaskMismatch", ...
        "The masked map does not correspond to the original stage 02 map.");
    masked=double(Q.masked_sws_map);
    masked(~logical(Q.retained_mask))=NaN;
else
    masked=[];
end

theme=swseval.viz.figureTheme();
cmap=swseval.viz.mapColormap();
individualRoot=fullfile(outputRoot,"individual");
combinedRoot=fullfile(outputRoot,"combined");
files=strings(0,1);
nRendered=0;

if options.SaveIndividual
    panels=struct("name",{},"data",{},"overlay",{},"tag",{});
    panels(end+1)=struct("name","sws_original_plain", ...
        "data",original,"overlay",false,"tag","original");
    if hasBmode
        panels(end+1)=struct("name","sws_original_bmode_rois", ...
            "data",original,"overlay",true,"tag","original");
    end
    if hasMask
        panels(end+1)=struct("name","sws_masked_plain", ...
            "data",masked,"overlay",false,"tag","masked");
        if hasBmode
            panels(end+1)=struct("name","sws_masked_bmode_rois", ...
                "data",masked,"overlay",true,"tag","masked");
        end
    end
    for k=1:numel(panels)
        base=fullfile(individualRoot,panels(k).name);
        outputs=base+"."+formats;
        files=[files;outputs(:)]; %#ok<AGROW>
        if ~options.Overwrite && all(isfile(outputs)),continue;end
        fig=figure("Visible",visibleText(options.Visible), ...
            "Color","w","Position",[75 75 650 530]);
        guard=onCleanup(@()close(fig)); %#ok<NASGU>
        ax=axes("Parent",fig,"Position",[.12 .12 .73 .81]);
        drawSws(ax,panels(k).data,x,z,B, ...
            panels(k).overlay,caseInfo,theme,cmap, ...
            options.OverlayAlpha,options.ShowROIs, ...
            options.SwsLimits,options.TickDecimals);
        attachSwsColorbar(ax,options.SwsTicks,options.TickDecimals);
        exportFormats(fig,base,formats,options.Overwrite);
        clear guard
        nRendered=nRendered+1;
    end
end

if options.SaveCombined && hasMask
    if hasBmode
        base=fullfile(combinedRoot,"sws_comparison_2x2");
    else
        base=fullfile(combinedRoot,"sws_comparison_1x2_no_bmode");
    end
    outputs=base+"."+formats;
    files=[files;outputs(:)]; %#ok<AGROW>
    if options.Overwrite || ~all(isfile(outputs))
        if hasBmode
            fig=figure("Visible",visibleText(options.Visible), ...
                "Color","w","Position",[40 40 1100 880]);
            guard=onCleanup(@()close(fig)); %#ok<NASGU>
            layout=tiledlayout(fig,2,2, ...
                "TileSpacing","compact","Padding","compact");
            datasets={original,masked,original,masked};
            modes=[false false true true];
        else
            fig=figure("Visible",visibleText(options.Visible), ...
                "Color","w","Position",[40 40 1100 490]);
            guard=onCleanup(@()close(fig)); %#ok<NASGU>
            layout=tiledlayout(fig,1,2, ...
                "TileSpacing","compact","Padding","compact");
            datasets={original,masked};
            modes=[false false];
        end
        for k=1:numel(datasets)
            ax=nexttile(layout,k);
            drawSws(ax,datasets{k},x,z,B,modes(k),caseInfo,theme,cmap, ...
                options.OverlayAlpha,options.ShowROIs, ...
                options.SwsLimits,options.TickDecimals);
            % Small panel label rather than a title.
            text(ax,0.03,0.96,"("+char('a'+k-1)+")", ...
                "Units","normalized","FontName",char(theme.font), ...
                "FontSize",theme.font_size_pt+2,"FontWeight","bold", ...
                "Color","k","BackgroundColor","w", ...
                "VerticalAlignment","top","Margin",2);
        end
        cb=colorbar(ax);
        cb.Layout.Tile="east";
        cb.Ticks=options.SwsTicks;
        cb.Ruler.TickLabelFormat=sprintf("%%.%df",options.TickDecimals);
        cb.Label.String="SWS (m/s)";
        cb.FontName=char(theme.font);
        exportFormats(fig,base,formats,options.Overwrite);
        clear guard
        nRendered=nRendered+1;
    end
end

summary=struct("files",files, ...
    "files_present",isfile(files), ...
    "n_rendered",nRendered, ...
    "has_mask",hasMask, ...
    "has_aligned_bmode",hasBmode, ...
    "sws_limits",options.SwsLimits, ...
    "roi_names",string({caseInfo.rois.name}));
end

function drawSws(ax,S,x,z,B,overlay,caseInfo,theme,cmap,alpha,showRois,limits,decimals)
    hold(ax,"on");
    if overlay
        assert(isfield(B,"available") && logical(B.available), ...
            "AdaptiveREQ:PlotNoBmode","Cannot draw an unverified B-mode overlay.");
        bg=double(B.image_db);
        assert(isequal(size(bg),[numel(B.z_mm),numel(B.x_mm)]), ...
            "AdaptiveREQ:PlotBmodeGrid","B-mode image does not fit its axes.");
        bg=max(0,min(1,(bg+60)/60));
        rgb=repmat(bg,1,1,3);
        image(ax,double(B.x_mm),double(B.z_mm),rgb);
    end
    if overlay
        a=alpha*double(isfinite(S));
    else
        a=double(isfinite(S));
    end
    imagesc(ax,x,z,S,"AlphaData",a);
    colormap(ax,cmap);
    clim(ax,limits);
    axis(ax,"image");
    set(ax,"YDir","normal", ...
        "XLim",[min(x),max(x)],"YLim",[min(z),max(z)]);
    xlabel(ax,"x (mm)");
    ylabel(ax,"z (mm)");
    set(ax,"FontName",char(theme.font), ...
        "FontSize",theme.font_size_pt, ...
        "LineWidth",theme.line_width,"TickDir","out","Box","on");
    xtickformat(ax,sprintf("%%.%df",decimals));
    ytickformat(ax,sprintf("%%.%df",decimals));
    if showRois
        for i=1:numel(caseInfo.rois)
            roi=caseInfo.rois(i);
            center=double(roi.center_mm(:)');
            sz=double(roi.size_mm(:)');
            pos=[center(1)-sz(1)/2,center(2)-sz(2)/2,sz(1),sz(2)];
            rgb=theme.roi_colors(mod(i-1,size(theme.roi_colors,1))+1,:);
            rectangle(ax,"Position",pos,"EdgeColor",rgb, ...
                "LineWidth",1.5,"LineStyle","--");
            text(ax,pos(1)+0.3,pos(2)+0.3,string(roi.name), ...
                "Color",rgb,"BackgroundColor","w", ...
                "FontName",char(theme.font), ...
                "FontSize",theme.font_size_pt-1, ...
                "Interpreter","none","Clipping","on");
        end
    end
end

function cb=attachSwsColorbar(ax,ticks,decimals)
    cb=colorbar(ax);
    cb.Ticks=ticks;
    cb.Ruler.TickLabelFormat=sprintf("%%.%df",decimals);
    cb.Label.String="SWS (m/s)";
end

function exportFormats(fig,base,formats,overwrite)
    folder=string(fileparts(base));
    if ~isfolder(folder),mkdir(folder);end
    for format=formats
        target=base+"."+format;
        if isfile(target) && ~overwrite,continue;end
        switch format
            case "png"
                exportgraphics(fig,target,"Resolution",300, ...
                    "BackgroundColor","white");
            case "pdf"
                exportgraphics(fig,target,"ContentType","vector", ...
                    "BackgroundColor","white");
            case "fig"
                savefig(fig,target);
        end
    end
end

function value=visibleText(isVisible)
    value="off";
    if isVisible,value="on";end
end
