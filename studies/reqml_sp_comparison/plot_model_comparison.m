function output = plot_model_comparison(options)
%PLOT_MODEL_COMPARISON Comparative experimental SWS plots for 4, 5, 7, or 9 arms.
%
%   output=plot_model_comparison();
%
% Reads the ROI CSV made by run_analysis()
% and the saved per-frequency reqml_result.mat files. No reprocessing,
% model fitting, or new REQ predictions occur in this function.
%
% Figures per SP experiment (one large central ROI for homogeneous):
%   - One frequency-dependence figure for each ROI: mean SWS +/- spatial
%     SD and spatial CV, with selected arms on shared axes.
%   - One SWS map montage per frequency (fixed [1,4] m/s color range).
%   - ROI-mean differences B-A/C-B/C-A and filtered-minus-raw candidate contrasts.
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
    options.AnalysisName (1,1) string = ""
    options.Arms (1,:) string = ["A_raw_v1","B_filtered_v1", ...
        "C_filtered_v2","candidate10","candidate", ...
        "candidate10_filtered","candidate_filtered"]
    options.SWSColorLimits (1,2) double = [1 4]
    options.FrequencyYLimits (1,2) double = [1 4]
    options.SavePDF (1,1) logical = true
end
legacyArms=["A_raw_v1","B_filtered_v1","C_filtered_v2", ...
    "candidate10","candidate", ...
    "candidate10_filtered","candidate_filtered"];
allArms=[legacyArms,"reduced14","reduced14_filtered"];
allLabels=["A | reduced16 raw", "B | reduced16 filtered", ...
    "C | reduced16 filtered-v2", "candidate10 raw", "candidate raw", ...
    "candidate10 filtered", "candidate filtered", ...
    "reduced14 raw", "reduced14 filtered (transfer)"];
arms=options.Arms;
fourArms=["A_raw_v1","reduced14","B_filtered_v1","reduced14_filtered"];
fiveArms=[fourArms,"candidate10_filtered"];
isFocused=isequal(arms,fourArms) || isequal(arms,fiveArms);
assert(isequal(arms,legacyArms) || isequal(arms,allArms) || isFocused, ...
    "SPCompare:PlotsArms","Expect focused four/five or frozen seven/nine-arm comparison.");
positions=zeros(1,numel(arms));
for k=1:numel(arms)
    positions(k)=find(allArms==arms(k),1);
end
labels=allLabels(positions);
analysisName=options.AnalysisName;
if analysisName=="",analysisName=options.ComparisonName;end
armTag=string(numel(arms))+"arms";
if numel(arms)==4
    mapTag="four";
elseif numel(arms)==5
    mapTag="five";
elseif numel(arms)==7
    mapTag="seven";
else
    mapTag="nine";
end
C=lines(numel(arms));
file=fullfile(options.DataRoot,analysisName, ...
    "all_experiments_roi_statistics.csv");
assert(isfile(file),"SPCompare:PlotsInput", ...
    "ROI summary not found; run Stage=analyze first: %s",file);
T=readtable(file,Delimiter=",",ReadVariableNames=true, ...
    TextType="string",VariableNamingRule="preserve");
required=["experiment","model","frequency_hz","M","name", ...
    "mean_sws","std_sws","cv_percent","valid_fraction"];
assert(all(ismember(required,string(T.Properties.VariableNames))), ...
    "SPCompare:PlotsSchema","Missing ROI statistics columns.");

output=strings(0,1);
for experiment=options.Experiments
    S=T(string(T.experiment)==experiment & double(T.M)==options.M,:);
    assert(~isempty(S),"SPCompare:PlotsEmpty", ...
        "No ROI results for %s",experiment);
    rois=sp_comparison_rois(experiment);
    roiNames=string({rois.name});
    assert(isempty(setxor(unique(string(S.name)),roiNames(:))), ...
        "SPCompare:ROIs", ...
        "ROI table does not match the defined ROIs for %s. Rerun analysis.",experiment);
    figDir=fullfile(options.DataRoot,experiment, ...
        "analysis",analysisName,"comparison_figures");
    if ~isfolder(figDir),mkdir(figDir);end

    % One 2-panel frequency plot per ROI: same ROI for every arm.
    for rn=roiNames'
        fig=figure("Visible","off","Color","w", ...
            "Position",[80 80 1050 890]);
        tl=tiledlayout(fig,numel(roiNames),1,"Padding","compact", ...
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
        base=fullfile(figDir,"frequency_comparison_"+armTag+"_"+rn+ ...
            "_M"+string(options.M));
        output=[output;export(fig,base,options.SavePDF)]; %#ok<AGROW>
        close(fig);
    end

    % Historical A/B/C contrasts are defined only for the seven/nine-arm set.
    if ~isFocused
    % Paired change in ROI mean (NO SWS accuracy claim without truth).
    fig=figure("Visible","off","Color","w", ...
        "Position",[80 80 1040 760]);
    t=tiledlayout(fig,numel(roiNames),1,"Padding","compact");
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
    end

    % Additional paired contrasts: only the spatial filter changes for
    % each historical candidate. These are changes in SWS, not accuracy.
    if ~isFocused
    fig=figure("Visible","off","Color","w", ...
        "Position",[80 80 1040 760]);
    tiled=tiledlayout(fig,numel(roiNames),1,"Padding","compact");
    for ri=1:numel(roiNames)
        rn=roiNames(ri);
        ax=nexttile(tiled);hold(ax,"on");
        old10=ordered(S,rn,"candidate10",options.Frequencies);
        new10=ordered(S,rn,"candidate10_filtered",options.Frequencies);
        oldCandidate=ordered(S,rn,"candidate",options.Frequencies);
        newCandidate=ordered(S,rn,"candidate_filtered",options.Frequencies);
        plot(ax,options.Frequencies, ...
            double(new10.mean_sws-old10.mean_sws),"-o", ...
            "LineWidth",1.6, ...
            "DisplayName","candidate10: filtered - raw");
        plot(ax,options.Frequencies, ...
            double(newCandidate.mean_sws-oldCandidate.mean_sws),"-s", ...
            "LineWidth",1.6, ...
            "DisplayName","candidate: filtered - raw");
        if numel(arms)==9
            raw14=ordered(S,rn,"reduced14",options.Frequencies);
            filtered14=ordered(S,rn,"reduced14_filtered",options.Frequencies);
            plot(ax,options.Frequencies, ...
                double(filtered14.mean_sws-raw14.mean_sws),"-^", ...
                "LineWidth",1.6, ...
                "DisplayName","reduced14: filtered - raw (transfer)");
        end
        yline(ax,0,"k:");
        ylabel(ax,"Change in ROI mean SWS (m/s)");
        xlabel(ax,"Frequency (Hz)");
        title(ax,rn,"Interpreter","none");
        xticks(ax,options.Frequencies);
        grid(ax,"on");
        if ri==1
            legend(ax,"Location","best","Interpreter","none");
        end
    end
    title(tiled,experiment+" | spatial-filter effect (same fitted models)", ...
        "Interpreter","none");
    output=[output;export(fig, ...
        fullfile(figDir,"candidate_filter_effect_roi_mean"), ...
        options.SavePDF)]; %#ok<AGROW>
    close(fig);
    end

    % Controlled 2x2: same two frozen models, with and without filtering.
    % All contrasts are paired ROI SWS changes, not errors against truth.
    if isFocused
        fig=figure("Visible","off","Color","w", ...
            "Position",[80 80 1080 780]);
        t=tiledlayout(fig,numel(roiNames),1,"Padding","compact", ...
            "TileSpacing","compact");
        for ri=1:numel(roiNames)
            rn=roiNames(ri);
            ax=nexttile(t);hold(ax,"on");
            raw16=ordered(S,rn,"A_raw_v1",options.Frequencies);
            raw14=ordered(S,rn,"reduced14",options.Frequencies);
            filtered16=ordered(S,rn,"B_filtered_v1",options.Frequencies);
            filtered14=ordered(S,rn,"reduced14_filtered",options.Frequencies);
            plot(ax,options.Frequencies, ...
                double(raw14.mean_sws-raw16.mean_sws),"-o", ...
                "LineWidth",1.6, ...
                "DisplayName","reduced14 - reduced16 | raw");
            plot(ax,options.Frequencies, ...
                double(filtered14.mean_sws-filtered16.mean_sws),"-s", ...
                "LineWidth",1.6, ...
                "DisplayName","reduced14 - reduced16 | filtered");
            plot(ax,options.Frequencies, ...
                double(filtered16.mean_sws-raw16.mean_sws),"-^", ...
                "LineWidth",1.6, ...
                "DisplayName","filtered - raw | reduced16");
            plot(ax,options.Frequencies, ...
                double(filtered14.mean_sws-raw14.mean_sws),"-d", ...
                "LineWidth",1.6, ...
                "DisplayName","filtered - raw | reduced14");
            yline(ax,0,"k:");
            ylabel(ax,"Change in ROI mean SWS (m/s)");
            xlabel(ax,"Frequency (Hz)");
            title(ax,rn,"Interpreter","none");
            xticks(ax,options.Frequencies);
            grid(ax,"on");
            if ri==1
                legend(ax,"Location","best","Interpreter","none");
            end
        end
        title(t,experiment+" | feature ablation vs spatial filtering", ...
            "Interpreter","none");
        output=[output;export(fig, ...
            fullfile(figDir,"feature_filter_2x2_roi_mean"), ...
            options.SavePDF)]; %#ok<AGROW>
        close(fig);
    end

    % Candidate10 is an external filtered-input benchmark, not part of
    % the matched Reduced16/Reduced14 2x2 ablation.
    if isequal(arms,fiveArms)
        fig=figure("Visible","off","Color","w", ...
            "Position",[80 80 1040 760]);
        t=tiledlayout(fig,numel(roiNames),1,"Padding","compact");
        for ri=1:numel(roiNames)
            rn=roiNames(ri);
            ax=nexttile(t);hold(ax,"on");
            filtered16=ordered(S,rn,"B_filtered_v1",options.Frequencies);
            filtered14=ordered(S,rn,"reduced14_filtered",options.Frequencies);
            candidate=ordered(S,rn,"candidate10_filtered",options.Frequencies);
            plot(ax,options.Frequencies, ...
                double(candidate.mean_sws-filtered16.mean_sws),"-o", ...
                "LineWidth",1.6, ...
                "DisplayName","candidate10 - reduced16 | filtered");
            plot(ax,options.Frequencies, ...
                double(candidate.mean_sws-filtered14.mean_sws),"-s", ...
                "LineWidth",1.6, ...
                "DisplayName","candidate10 - reduced14 | filtered");
            yline(ax,0,"k:");
            ylabel(ax,"Change in ROI mean SWS (m/s)");
            xlabel(ax,"Frequency (Hz)");
            title(ax,rn,"Interpreter","none");
            xticks(ax,options.Frequencies);grid(ax,"on");
            if ri==1
                legend(ax,"Location","best","Interpreter","none");
            end
        end
        title(t,experiment+" | filtered-input candidate10 benchmark", ...
            "Interpreter","none");
        output=[output;export(fig, ...
            fullfile(figDir,"candidate10_filtered_vs_reduced_roi_mean"), ...
            options.SavePDF)]; %#ok<AGROW>
        close(fig);
    end

    % Fixed physical color scale across all maps at each frequency.
    for f=options.Frequencies
        fig=figure("Visible","off","Color","w", ...
            "Position",[30 100 320*numel(arms)+560 660]);
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
        base=fullfile(figDir,mapTag+sprintf("_model_SWS_maps_%gHz_M%g",f,options.M));
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