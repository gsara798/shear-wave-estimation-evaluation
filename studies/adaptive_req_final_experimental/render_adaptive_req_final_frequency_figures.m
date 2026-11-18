function report=render_adaptive_req_final_frequency_figures(T,reference,outputRoot,options)
%RENDER_ADAPTIVE_REQ_FINAL_FREQUENCY_FIGURES ROI SWS +/- spatial SD vs Hz.
% Separate figures for original / masked and for soft / hard / both ROIs.
% Homogeneous soft/hard series are collected across the 5% and 10%
% acquisitions of the same excitation modality. Bilayer and inclusion
% physical ROI geometry is never modified.
%
% Reference bands: independent mechanical stress-relaxation SLS samples,
% min-max among six samples per formulation AT EACH FREQUENCY (REQ paper).
% Approximate textual envelopes must never be called exact reference data.
% Error bars: +/- within-ROI spatial standard deviation, NOT SEM/CI.
arguments
    T table
    reference table
    outputRoot (1,1) string
    options.MValues (1,:) double = [1 2 3]
    options.FrequenciesHz (1,:) double = [300 400 500 600]
    options.Modalities (1,:) string = ["sp","rswe"]
    options.Phantoms (1,:) string = ["homogeneous","bilayer","inclusion"]
    options.Formats (1,:) string = ["png","pdf"]
    options.YLimits (1,2) double = [1 4]
    options.Visible (1,1) logical = false
    options.Overwrite (1,1) logical = false
end
cols=["case_id","modality","phantom_type","roi","material", ...
    "frequency_hz","M","mask_state","n_valid","mean_sws_m_s", ...
    "sd_sws_m_s","n_original_valid","roi_pixels","coverage"];
refcols=["frequency_hz","material","lower_m_s","upper_m_s","reference_status"];
assert(all(ismember(cols,string(T.Properties.VariableNames))) && ...
    all(ismember(refcols,string(reference.Properties.VariableNames))) && ...
    all(ismember(["soft","hard"],unique(string(reference.material))) && ...
    all(reference.lower_m_s<reference.upper_m_s) && ...
    all(isfinite(reference.lower_m_s)&isfinite(reference.upper_m_s)) && ...
    all(isfinite(options.YLimits)) && ...
    options.YLimits(1)<options.YLimits(2), ...
    "AdaptiveREQ:FrequencySchema","Invalid frequency statistics/reference tables.");
assert(all(ismember(unique(string(T.mask_state)),["original","masked"])) && ...
    all(ismember(unique(string(T.material)),["soft","hard"])) && ...
    all(T.n_valid>=0) && ...
    all(T.roi_pixels>=T.n_original_valid) && ...
    all(T.n_original_valid>=T.n_valid | T.mask_state=="original"), ...
    "AdaptiveREQ:FrequencyStatistics","Invalid ROI coverage or material.");
formats=unique(lower(options.Formats),"stable");
assert(~isempty(formats) && all(ismember(formats,["png","pdf","fig"])), ...
    "AdaptiveREQ:FrequencyFormats","Formats: png, pdf, fig.");
theme=swseval.viz.figureTheme();
colors=struct("soft",double(theme.rgb.red.main(:)'), ...
              "hard",double(theme.rgb.blue.main(:)'));
if ~isfolder(outputRoot),mkdir(outputRoot);end
files=strings(0,1);
figureLog=table('Size',[0 8], ...
    'VariableTypes',["string","string","double","string","string", ...
        "double","string","string"], ...
    'VariableNames',["modality","phantom_type","M","mask_state", ...
        "roi_view","plotted_points","figure_path","reference_status"]);
for modality=options.Modalities(:)'
    for phantom=options.Phantoms(:)'
        for m=options.MValues
            for maskState=["original","masked"]
                G=T(T.modality==modality & T.phantom_type==phantom & ...
                    T.M==m & T.mask_state==maskState,:);
                if isempty(G),continue;end
                for view=["soft","hard","both"]
                    S=G;
                    if view~="both",S=S(S.material==view,:);end
                    if isempty(S),continue;end
                    fig=figure("Visible",visibility(options.Visible), ...
                        "Color","w","Units","inches","Position",[1 1 5.9 4.1]);
                    closeGuard=onCleanup(@()close(fig)); %#ok<NASGU>
                    ax=axes("Parent",fig,"Position",[.17 .19 .78 .76]);
                    hold(ax,"on");
                    refStatus=strjoin(unique(string(reference.reference_status)),",");
                    plotted=0;
                    handles=gobjects(0,1);
                    for material=["soft","hard"]
                        D=S(S.material==material,:);
                        if isempty(D),continue;end
                        F=reference(reference.material==material & ...
                            ismember(reference.frequency_hz,options.FrequenciesHz),:);
                        F=sortrows(F,"frequency_hz");
                        assert(height(F)==numel(options.FrequenciesHz) && ...
                            isequal(double(F.frequency_hz(:)'), ...
                                sort(options.FrequenciesHz)), ...
                            "AdaptiveREQ:ReferenceFrequency", ...
                            "Missing/duplicate SLS reference frequencies for %s.",material);
                        color=colors.(char(material));
                        band(ax,F,color);
                        D=sortrows(D,"frequency_hz");
                        assert(numel(unique(D.frequency_hz))==height(D) && ...
                            all(ismember(double(D.frequency_hz),options.FrequenciesHz)), ...
                            "AdaptiveREQ:FrequencyDuplicate", ...
                            "Duplicate or unrequested SWS frequency for %s/%s/M%g/%s/%s.", ...
                            modality,phantom,m,maskState,material);
                        good=isfinite(D.mean_sws_m_s) & ...
                            isfinite(D.sd_sws_m_s) & D.n_valid>0;
                        if ~any(good),continue;end
                        X=double(D.frequency_hz(good));
                        Y=double(D.mean_sws_m_s(good));
                        E=double(D.sd_sws_m_s(good));
                        h=errorbar(ax,X,Y,E,E,"-o", ...
                            "Color",color,"LineWidth",theme.line_width, ...
                            "MarkerSize",6,"MarkerFaceColor","w","CapSize",7, ...
                            "DisplayName",material+" ("+ ...
                            conditional(material=="soft","5%","10%")+")");
                        handles(end+1,1)=h; %#ok<AGROW>
                        plotted=plotted+nnz(good);
                    end
                    if plotted==0
                        text(ax,.5,.50,"No retained ROI estimates", ...
                            "Units","normalized","HorizontalAlignment","center", ...
                            "FontName",char(theme.font), ...
                            "Color",[.3 .3 .3]);
                    elseif ~isempty(handles)
                        legend(ax,handles,"Location","best","Box","off", ...
                            "Interpreter","none");
                    end
                    xlabel(ax,"Frequency (Hz)");
                    ylabel(ax,"SWS (m/s)");
                    xlim(ax,[min(options.FrequenciesHz)-15, ...
                        max(options.FrequenciesHz)+15]);
                    xticks(ax,sort(options.FrequenciesHz));
                    ylim(ax,options.YLimits);
                    set(ax,"FontName",char(theme.font), ...
                        "FontSize",theme.font_size_pt+1, ...
                        "LineWidth",theme.line_width, ...
                        "TickDir","out","Box","on");
                    xtickformat(ax,"%.0f");
                    ytickformat(ax,"%.1f");
                    grid(ax,"off");
                    % No visual title (paper style). Names and conditions
                    % remain in file path + manifest rather than plot title.
                    sub=fullfile(outputRoot,phantom,modality, ...
                        "M"+string(m),maskState);
                    if ~isfolder(sub),mkdir(sub);end
                    basename=fullfile(sub,"sws_vs_frequency_"+view);
                    for format=formats
                        target=basename+"."+format;
                        if isfile(target) && ~options.Overwrite
                            error("AdaptiveREQ:FrequencyImmutable", ...
                                "Refusing to overwrite existing plot: %s",target);
                        end
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
                        files(end+1,1)=target; %#ok<AGROW>
                    end
                    figureLog(end+1,:)={modality,phantom,m,maskState,view, ...
                        plotted,basename,refStatus}; %#ok<AGROW>
                    clear closeGuard
                end
            end
        end
    end
end
assert(all(isfile(files)), ...
    "AdaptiveREQ:FrequencyExport","Some frequency figures were not saved.");
writetable(figureLog,fullfile(outputRoot,"figure_manifest.csv"));
report=struct("n_figures",height(figureLog),"n_files",numel(files), ...
    "output_directory",outputRoot, ...
    "manifest",fullfile(outputRoot,"figure_manifest.csv"), ...
    "files",files);
end

function band(ax,F,color)
    x=double(F.frequency_hz(:));
    lo=double(F.lower_m_s(:));
    hi=double(F.upper_m_s(:));
    patch(ax,[x;flipud(x)],[lo;flipud(hi)],color, ...
        "FaceAlpha",.12,"EdgeColor","none","HandleVisibility","off");
    plot(ax,x,lo,"--","Color",color,"LineWidth",.75, ...
        "HandleVisibility","off");
    plot(ax,x,hi,"--","Color",color,"LineWidth",.75, ...
        "HandleVisibility","off");
end

function s=visibility(b)
s="off";if b,s="on";end
end
function textOut=conditional(test,yes,no)
textOut=no;if test,textOut=yes;end
end
