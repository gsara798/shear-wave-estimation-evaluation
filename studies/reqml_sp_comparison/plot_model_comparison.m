function output = plot_model_comparison(options)
%PLOT_MODEL_COMPARISON Comparative experimental SWS plots for 5 Q0 arms.
%
%   output=plot_model_comparison();
%
% Reads the ROI CSV made by run_reqml_sp_comparison(Stage="analyze")
% and the saved per-frequency reqml_result.mat files. No reprocessing,
% model fitting, or new REQ predictions occur in this function.
%
% Figures per SP experiment:
%   - One frequency-dependence figure for each ROI: mean SWS +/- spatial
%     SD and spatial CV, with ALL FIVE arms on shared axes.
%   - One five-map SWS montage per frequency (fixed [1,4] m/s color range).
%   - One ROI-average SWS-difference figure (B-A, C-B, C-A) per experiment.
%
% CAUTION: Within-ROI SD is spatial heterogeneity, NOT uncertainty of the
% mean and NOT a 95% confidence interval. No external ground truth is used.
arguments
    options.DataRoot (1,1) string = ...
        "/Users/sara/local/experimental-data-reorganized/2026-02-27"
    options.Experiments (1,:) string = ["2026Feb27_dl_sp", ...
        "2026Feb27_homo_5perc_sp","2026Feb27_homo_10perc_sp"]
    options.Frequencies (1,:) double = [300 400 500 600]
    options.M (1,1) double {mustBePositive} = 2
    options.ComparisonName (1,1) string = "reqml_sp_compare_m2_0p8_8_v1"
    options.SWSColorLimits (1,2) double = [1 4]
    options.FrequencyYLimits (1,2) double = [1 4]
    options.SavePDF (1,1) logical = true
end
arms=["A_raw_v1","B_filtered_v1","C_filtered_v2", ...
    "candidate10","candidate"];
labels=["A | reduced16 raw", "B | reduced16 filtered", ...
    "C | reduced16 filtered-v2", "candidate10 raw", "candidate raw"];
C=lines(numel(arms));
file=fullfile(options.DataRoot,options.ComparisonName, ...
    "all_experiments_roi_statistics.csv");
assert(isfile(file),"SPCompare:PlotsInput", ...
    "ROI summary not found; run Stage=analyze first: %s",file);
T=readtable(file,Delimiter=",",ReadVariableNames=true, ...
    TextType="string",VariableNamingRule="preserve");
required=["experiment","model","frequency_hz","M","name", ...
    "mean_sws","std_sws","cv_percent","valid_fraction"];
assert(all(ismember(required,string(T.Properties.VariableNames))), ...
    "SPCompare:PlotsSchema","Missing ROI statistics columns.");
roiNames=unique(string(T.name),"stable");
assert(numel(roiNames)==2,"SPCompare:ROIs", ...
    "Expected the two predefined ROIs (ROI1 and ROI2).");
rois=[struct("name","ROI1","center",[18 10],"size",[10 5]), ...
      struct("name","ROI2","center",[18 25],"size",[10 5])];
output=strings(0,1);
for experiment=options.Experiments
    S=T(string(T.experiment)==experiment & double(T.M)==options.M,:);
    assert(~isempty(S),"SPCompare:PlotsEmpty", ...
        "No ROI results for %s",experiment);
    figDir=fullfile(options.DataRoot,experiment, ...
        "analysis",options.ComparisonName,"comparison_figures");
    if ~isfolder(figDir),mkdir(figDir);end

    % One 2-panel frequency plot per ROI: compare five models at same ROI.
    for rn=roiNames'
        fig=figure("Visible","off","Color","w", ...
            "Position",[80 80 1050 890]);
        tl=tiledlayout(fig,2,1,"Padding","compact", ...
            "TileSpacing","compact");
        ax1=nexttile(tl);hold(ax1,"on");
        ax2=nexttile(tl);hold(ax2,"on");
        for a=1:numel(arms)
            R=S(string(S.name)==rn & string(S.model)==arms(a),:);
            R=sortrows(R,"frequency_hz");
            assert(height(R)==numel(options.Frequencies) && ...
                isequal(double(R.frequency_hz),options.Frequencies'), ...
                "SPCompare:PlotsCoverage", ...
                "Incomplete frequency comparison %s/%s/%s", ...
                experiment,rn,arms(a));
            f=double(R.frequency_hz);
            mu=double(R.mean_sws);sd=double(R.std_sws);
            cv=double(R.cv_percent);
            errorbar(ax1,f,mu,sd,sd,"-o", ...
                "Color",C(a,:),"LineWidth",1.6, ...
                "MarkerSize",6,"CapSize",7, ...
                "DisplayName",labels(a));
            plot(ax2,f,cv,"-o", ...
                "Color",C(a,:),"LineWidth",1.6, ...
                "MarkerSize",6,"DisplayName",labels(a));
        end
        ylabel(ax1,"Mean SWS ± spatial SD (m/s)");
        ylim(ax1,options.FrequencyYLimits);
        ylabel(ax2,"Within-ROI CV (%)");
        xlabel(ax2,"Frequency (Hz)");
        xticks(ax1,options.Frequencies);
        xticks(ax2,options.Frequencies);
        xlim(ax1,[min(options.Frequencies) max(options.Frequencies)]);
        xlim(ax2,[min(options.Frequencies) max(options.Frequencies)]);
        grid(ax1,"on");grid(ax2,"on");
        legend(ax1,"Location","best","Interpreter","none");
        title(tl,experiment+" | "+rn+" | M="+string(options.M), ...
            "Interpreter","none");
        base=fullfile(figDir,"frequency_comparison_"+rn+"_M"+string(options.M));
        output=[output;export(fig,base,options.SavePDF)]; %#ok<AGROW>
        close(fig);
    end

    % Paired change in ROI mean (NO SWS accuracy claim without truth).
    fig=figure("Visible","off","Color","w", ...
        "Position",[80 80 1040 760]);
    t=tiledlayout(fig,2,1,"Padding","compact");
    for ri=1:numel(roiNames)
        rn=roiNames(ri);
        ax=nexttile(t);hold(ax,"on");
        A=ordered(S,rn,arms(1),options.Frequencies);
        B=ordered(S,rn,arms(2),options.Frequencies);
        D=ordered(S,rn,arms(3),options.Frequencies);
        plot(ax,options.Frequencies,double(B.mean_sws-A.mean_sws),"-o", ...
            "LineWidth",1.6,"DisplayName","B - A (filter only)");
        plot(ax,options.Frequencies,double(D.mean_sws-B.mean_sws),"-s", ...
            "LineWidth",1.6,"DisplayName","C - B (retraining)");
        plot(ax,options.Frequencies,double(D.mean_sws-A.mean_sws),"-^", ...
            "LineWidth",1.6,"DisplayName","C - A (total)");
        yline(ax,0,"k:");
        ylabel(ax,"Change in ROI mean SWS (m/s)");
        xlabel(ax,"Frequency (Hz)");
        title(ax,rn,"Interpreter","none");
        xticks(ax,options.Frequencies);grid(ax,"on");
        if ri==1,legend(ax,"Location","best","Interpreter","none");end
    end
    title(t,experiment+" | matched ROI comparisons", ...
        "Interpreter","none");
    output=[output;export(fig,fullfile(figDir,"paired_roi_mean_differences"), ...
        options.SavePDF)]; %#ok<AGROW>
    close(fig);

    % Fixed physical color scale across the five maps for each frequency.
    for f=options.Frequencies
        fig=figure("Visible","off","Color","w", ...
            "Position",[30 100 2310 610]);
        tl=tiledlayout(fig,1,numel(arms),"TileSpacing","compact", ...
            "Padding","compact");
        for a=1:numel(arms)
            source=fullfile(options.DataRoot,experiment,"estimates", ...
                options.ComparisonName,"REQ-ML",arms(a), ...
                sprintf("%gHz",f),"M"+string(options.M),"reqml_result.mat");
            assert(isfile(source),"SPCompare:PlotsMaps", ...
                "Missing map file: %s",source);
            map=swseval.io.loadReqmlResult(source);
            ax=nexttile(tl);
            X=double(map.x_mm(:));Z=double(map.z_mm(:));
            A=double(map.cs_map);
            A(~logical(map.valid_mask))=NaN;
            imagesc(ax,X,Z,A);
            axis(ax,"image");set(ax,"YDir","normal");
            colormap(ax,"turbo");
            clim(ax,options.SWSColorLimits);
            xlabel(ax,"x (mm)");
            if a==1,ylabel(ax,"z (mm)");end
            title(ax,labels(a),"Interpreter","none","FontSize",11);
            hold(ax,"on");
            for ri=1:numel(rois)
                r=rois(ri);
                pos=[r.center(1)-r.size(1)/2, ...
                     r.center(2)-r.size(2)/2, ...
                     r.size(1),r.size(2)];
                rectangle(ax,"Position",pos,"EdgeColor",[1 1 1], ...
                    "LineWidth",1.2,"LineStyle","--");
                if a==1
                    text(ax,pos(1),pos(2),r.name, ...
                        "Color","white","FontWeight","bold", ...
                        "VerticalAlignment","bottom");
                end
            end
            if a==numel(arms)
                cb=colorbar(ax);cb.Label.String="SWS (m/s)";
            end
        end
        title(tl,experiment+" | "+string(f)+" Hz | M="+string(options.M), ...
            "Interpreter","none");
        base=fullfile(figDir,sprintf("five_model_SWS_maps_%gHz_M%g",f,options.M));
        output=[output;export(fig,base,options.SavePDF)]; %#ok<AGROW>
        close(fig);
    end
    fprintf("Comparison figures saved in %s\n",figDir);
end
end

function R=ordered(T,roi,model,frequencies)
R=T(string(T.name)==roi & string(T.model)==model,:);
R=sortrows(R,"frequency_hz");
assert(height(R)==numel(frequencies) && ...
    isequal(double(R.frequency_hz),frequencies'), ...
    "SPCompare:PlotsPairs","Missing paired ROI/frequency data.");
end

function output=export(fig,base,savePDF)
exportgraphics(fig,base+".png",Resolution=180);
output=base+".png";
if savePDF
    exportgraphics(fig,base+".pdf",ContentType="vector");
    output=[output;base+".pdf"];
end
end