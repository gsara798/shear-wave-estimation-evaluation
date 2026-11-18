function report=analyze_full21_filter_cutoff_pair(results,masks,caseInfo,outputDir,options)
%ANALYZE_FULL21_FILTER_CUTOFF_PAIR Descriptive paired raw/donut mask study.
% Both arms must be inferred with the SAME frozen Full21 and spatial grid.
% Evaluates the published VALIDATION cutoff and other cutoffs EXPLORATORILY.
% Never calibrates a deployment threshold from experimental observations.
arguments
    results (1,2) cell
    masks (1,2) cell
    caseInfo (1,1) struct
    outputDir (1,1) string
    options.ExploratoryCutoffs (1,:) double = [.20 .24 .30 .40]
    options.SaveFigures (1,1) logical = true
    options.Visible (1,1) logical = false
    options.SwsLimits (1,2) double = [1.5 3.5]
end
assert(isequal(options.SwsLimits,[1.5 3.5]) && ...
    all(isfinite(options.ExploratoryCutoffs)) && ...
    all(options.ExploratoryCutoffs>0 & options.ExploratoryCutoffs<=1), ...
    "AdaptiveREQ:FilterPilotSettings","Invalid diagnostic display/cutoffs.");
R=results{1};
F=results{2};
A=masks{1};
B=masks{2};
required=["original_sws_map","risk_score_map","original_valid_mask", ...
    "q_map","cutoff","x_mm","z_mm"];
assert(all(isfield(A,cellstr(required))) && all(isfield(B,cellstr(required))), ...
    "AdaptiveREQ:FilterPilotMasks","Missing saved mask maps.");
assert(isequal(size(A.original_sws_map),size(B.original_sws_map)) && ...
    isequal(double(A.x_mm(:)),double(B.x_mm(:))) && ...
    isequal(double(A.z_mm(:)),double(B.z_mm(:))) && ...
    isequal(size(A.risk_score_map),size(B.risk_score_map)) && ...
    isequaln(double(R.cs_map),double(A.original_sws_map)) && ...
    isequaln(double(F.cs_map),double(B.original_sws_map)), ...
    "AdaptiveREQ:FilterPilotGrid", ...
    "Raw and filtered SWS maps must have exactly the same physical grid.");
frozen=double(A.cutoff);
assert(abs(double(B.cutoff)-frozen)<1e-12 && ...
    frozen>0 && frozen<1, ...
    "AdaptiveREQ:FilterPilotCutoff","Both arms must use one frozen mask.");
cutoffs=unique([frozen options.ExploratoryCutoffs],"sorted");
labels=["raw","fixed_donut"];
M={A,B};
x=double(A.x_mm(:)');
z=double(A.z_mm(:));
roiNames=["whole_fov",string({caseInfo.rois.name})];
roiMasks=cell(numel(roiNames),1);
roiMasks{1}=true(size(A.original_sws_map));
for i=1:numel(caseInfo.rois)
    roi=caseInfo.rois(i);
    c=double(roi.center_mm(:));
    sizeMM=double(roi.size_mm(:));
    roiMasks{i+1}=(z>=c(2)-sizeMM(2)/2 & z<=c(2)+sizeMM(2)/2) & ...
        (x>=c(1)-sizeMM(1)/2 & x<=c(1)+sizeMM(1)/2);
end
rows=cell(numel(cutoffs)*2*numel(roiNames),1);
idx=0;
for a=1:2
    Q=M{a};
    raw=double(Q.original_sws_map);
    valid=logical(Q.original_valid_mask);
    score=double(Q.risk_score_map);
    for k=1:numel(roiNames)
        within=roiMasks{k};
        original=valid&within;
        scored=original&isfinite(score);
        n=nnz(original);
        for c=1:numel(cutoffs)
            threshold=cutoffs(c);
            keep=scored&score<=threshold;
            rejected=scored&score>threshold;
            unscored=original&~scored;
            nKept=nnz(keep);
            assert(nnz(keep)+nnz(rejected)+nnz(unscored)==n, ...
                "AdaptiveREQ:FilterPilotPartition", ...
                "Keep/reject/unscored do not cover original valid SWS.");
            if abs(threshold-frozen)<1e-12
                cutoffType="frozen_VALIDATION";
            else
                cutoffType="exploratory_not_validated";
            end
            idx=idx+1;
            rows{idx}=table(labels(a),roiNames(k),threshold,cutoffType, ...
                n,nnz(scored),nKept,nnz(rejected),nnz(unscored), ...
                safePercent(nKept,n),safeMean(raw(original)), ...
                safeMedian(raw(original)),safeMean(raw(keep)), ...
                safeMedian(raw(keep)),safeMedian(score(scored)), ...
                safeMedian(double(Q.q_map(original))), ...
                'VariableNames',["arm","roi","cutoff","cutoff_type", ...
                "original_valid","scored","retained","rejected","unscored", ...
                "retention_pct","sws_mean_original","sws_median_original", ...
                "sws_mean_retained","sws_median_retained", ...
                "risk_score_median","q_median_original"]);
        end
    end
end
T=vertcat(rows{:});
if ~isfolder(outputDir),mkdir(outputDir);end
csv=fullfile(outputDir,"mask_retention_cutoff_sweep.csv");
writetable(T,csv);

% SWS comparisons use paired valid pixels at identical map centers.
pairedRows=cell(numel(roiNames),1);
rawCs=double(A.original_sws_map);
donutCs=double(B.original_sws_map);
qRaw=double(A.q_map);
qDonut=double(B.q_map);
riskRaw=double(A.risk_score_map);
riskDonut=double(B.risk_score_map);
for k=1:numel(roiNames)
    common=roiMasks{k}&logical(A.original_valid_mask)& ...
        logical(B.original_valid_mask);
    bothScored=common&isfinite(riskRaw)&isfinite(riskDonut);
    pairedRows{k}=table(roiNames(k),nnz(common),nnz(bothScored), ...
        safeMedian(rawCs(common)),safeMedian(donutCs(common)), ...
        safeMedian(donutCs(common)-rawCs(common)), ...
        safeMedian(qRaw(common)),safeMedian(qDonut(common)), ...
        safeMedian(qDonut(common)-qRaw(common)), ...
        safeMedian(riskRaw(bothScored)),safeMedian(riskDonut(bothScored)), ...
        safeMedian(riskDonut(bothScored)-riskRaw(bothScored)), ...
        'VariableNames',["roi","paired_valid_pixels","both_scored", ...
        "raw_sws_median","donut_sws_median","paired_delta_sws_median", ...
        "raw_q_median","donut_q_median","paired_delta_q_median", ...
        "raw_risk_median","donut_risk_median","paired_delta_risk_median"]);
end
P=vertcat(pairedRows{:});
pairedCsv=fullfile(outputDir,"paired_filter_effect.csv");
writetable(P,pairedCsv);

% Spectral feature shifts, restricted to the exact same valid centers.
names=string(R.patch_examples.Properties.VariableNames);
other=string(F.patch_examples.Properties.VariableNames);
exclude=["map_ix","map_iz","cx","cz","patch_idx","q_pred"];
shared=intersect(names,other,"stable");
featureRows=cell(0,1);
if isequal(double(R.patch_examples.map_ix(:)), ...
        double(F.patch_examples.map_ix(:))) && ...
        isequal(double(R.patch_examples.map_iz(:)), ...
        double(F.patch_examples.map_iz(:)))
    er=R.patch_examples;
    ef=F.patch_examples;
    linear=sub2ind(size(A.original_sws_map), ...
        double(er.map_iz),double(er.map_ix));
    use=logical(A.original_valid_mask(linear))& ...
        logical(B.original_valid_mask(linear));
    for feature=shared(:).'
        if ismember(feature,exclude),continue;end
        u=er.(char(feature));
        v=ef.(char(feature));
        if ~isnumeric(u)||~isnumeric(v)|| ...
                ~isvector(u)||~isvector(v),continue;end
        u=double(u(:));v=double(v(:));
        choose=use&isfinite(u)&isfinite(v);
        if ~any(choose),continue;end
        featureRows{end+1,1}=table(feature,nnz(choose), ...
            median(u(choose)),median(v(choose)), ...
            median(v(choose)-u(choose)), ...
            'VariableNames',["feature","paired_rows","raw_median", ...
            "donut_median","paired_delta_median"]); %#ok<AGROW>
    end
end
featureCsv="";
if ~isempty(featureRows)
    featureCsv=fullfile(outputDir,"paired_feature_shifts.csv");
    writetable(vertcat(featureRows{:}),featureCsv);
end

figureFiles=strings(0,1);
if options.SaveFigures
    figDir=fullfile(outputDir,"figures");
    if ~isfolder(figDir),mkdir(figDir);end
    vis="off";if options.Visible,vis="on";end
    cmap=swseval.viz.mapColormap();
    sws={rawCs,donutCs};
    % 2x2: same fixed threshold, before/after mask and raw/donut rows.
    fig=figure("Visible",vis,"Color","w", ...
        "Position",[100 100 1050 850]);
    guard=onCleanup(@()close(fig)); %#ok<NASGU>
    tl=tiledlayout(fig,2,2,"Padding","compact","TileSpacing","compact");
    for arm=1:2
        for col=1:2
            ax=nexttile(tl,(arm-1)*2+col);
            values=sws{arm};
            if col==2
                keep=logical(M{arm}.original_valid_mask)& ...
                    isfinite(M{arm}.risk_score_map)& ...
                    double(M{arm}.risk_score_map)<=frozen;
                values(~keep)=NaN;
            else
                values(~logical(M{arm}.original_valid_mask))=NaN;
            end
            drawMap(ax,values,x,z,options.SwsLimits,cmap, ...
                caseInfo.rois);
            if col==1,label="Original SWS";else,label="Frozen mask";end
            title(ax,labels(arm)+" | "+label,Interpreter="none");
        end
    end
    cb=colorbar(ax);cb.Layout.Tile="east";
    cb.Label.String="SWS (m/s)";
    cb.Ticks=1.5:.5:3.5;
    cb.Ruler.TickLabelFormat="%.1f";
    file=fullfile(figDir,"raw_vs_donut_frozen_mask_2x2.png");
    exportgraphics(fig,file,Resolution=240);
    figureFiles(end+1,1)=file;
    clear guard

    % Exploratory mask sweep: each raw/donut row, original + all cutoffs.
    fig=figure("Visible",vis,"Color","w", ...
        "Position",[30 50 300*(numel(cutoffs)+1) 650]);
    guard=onCleanup(@()close(fig)); %#ok<NASGU>
    tl=tiledlayout(fig,2,numel(cutoffs)+1, ...
        "Padding","compact","TileSpacing","compact");
    for arm=1:2
        for j=1:numel(cutoffs)+1
            ax=nexttile(tl,(arm-1)*(numel(cutoffs)+1)+j);
            values=sws{arm};
            values(~logical(M{arm}.original_valid_mask))=NaN;
            if j==1
                descriptor="original";
            else
                threshold=cutoffs(j-1);
                score=double(M{arm}.risk_score_map);
                keep=logical(M{arm}.original_valid_mask)& ...
                    isfinite(score)&score<=threshold;
                values(~keep)=NaN;
                descriptor=sprintf("cutoff %.3f",threshold);
                if abs(threshold-frozen)<1e-12
                    descriptor=descriptor+" [frozen]";
                end
            end
            drawMap(ax,values,x,z,options.SwsLimits,cmap, ...
                caseInfo.rois);
            title(ax,labels(arm)+" | "+descriptor,Interpreter="none", ...
                FontSize=10);
        end
    end
    cb=colorbar(ax);cb.Layout.Tile="east";cb.Label.String="SWS (m/s)";
    clim(ax,options.SwsLimits);
    file=fullfile(figDir,"exploratory_cutoff_sweep.png");
    exportgraphics(fig,file,Resolution=190);
    figureFiles(end+1,1)=file;
    clear guard

    % Risk score distribution on original-valid pixels, both arms.
    fig=figure("Visible",vis,"Color","w", ...
        "Position",[80 80 960 460]);
    guard=onCleanup(@()close(fig)); %#ok<NASGU>
    ax=axes(fig);hold(ax,"on");
    edges=linspace(0,1,51);
    for arm=1:2
        Q=M{arm};
        mask=logical(Q.original_valid_mask)&isfinite(Q.risk_score_map);
        histogram(ax,double(Q.risk_score_map(mask)),edges, ...
            Normalization="probability",DisplayStyle="stairs", ...
            LineWidth=2,DisplayName=labels(arm));
    end
    xline(ax,frozen,"k--","Frozen VALIDATION",LineWidth=1.6, ...
        HandleVisibility="off");
    xlabel(ax,"Ensemble risk score (not calibrated)");
    ylabel(ax,"Relative frequency");
    xlim(ax,[0 1]);legend(ax,"Location","best");grid(ax,"on");
    file=fullfile(figDir,"risk_distribution_raw_vs_donut.png");
    exportgraphics(fig,file,Resolution=230);
    figureFiles(end+1,1)=file;
    clear guard

    % Observed retention vs hypothetical cutoff, descriptive by ROI/arm.
    fig=figure("Visible",vis,"Color","w", ...
        "Position",[80 80 980 550]);
    guard=onCleanup(@()close(fig)); %#ok<NASGU>
    ax=axes(fig);hold(ax,"on");
    gridCutoffs=unique([linspace(0,1,101),frozen]);
    colors=lines(2*numel(roiNames));
    for k=1:numel(roiNames)
        for arm=1:2
            Q=M{arm};
            available=logical(Q.original_valid_mask)&roiMasks{k};
            score=double(Q.risk_score_map);
            denominator=nnz(available);
            fractions=nan(size(gridCutoffs));
            if denominator>0
                for ii=1:numel(gridCutoffs)
                    fractions(ii)=100*nnz(available& ...
                        isfinite(score)&score<=gridCutoffs(ii))/denominator;
                end
            end
            style="-";if arm==2,style="--";end
            plot(ax,gridCutoffs,fractions,style, ...
                "LineWidth",1.5,"Color",colors(2*k-2+arm,:), ...
                "DisplayName",labels(arm)+" | "+roiNames(k));
        end
    end
    xline(ax,frozen,"k:","Frozen VALIDATION",LineWidth=1.5, ...
        HandleVisibility="off");
    xlabel(ax,"Hypothetical risk-score cutoff (exploratory)");
    ylabel(ax,"Retained original-valid patches (%)");
    xlim(ax,[0 1]);ylim(ax,[0 100]);grid(ax,"on");
    legend(ax,"Location","eastoutside","Interpreter","none");
    file=fullfile(figDir,"retention_vs_cutoff_by_roi.png");
    exportgraphics(fig,file,Resolution=230);
    figureFiles(end+1,1)=file;
    clear guard
end

report=struct("cutoffs",cutoffs,"frozen_cutoff",frozen, ...
    "retention_csv",csv,"paired_csv",pairedCsv, ...
    "feature_csv",featureCsv,"figures",figureFiles, ...
    "rows",height(T),"pair_rows",height(P));
end

function drawMap(ax,values,x,z,limits,cmap,rois)
    imagesc(ax,x,z,values,"AlphaData",double(isfinite(values)));
    axis(ax,"image");
    set(ax,"YDir","normal","Color","w", ...
        "XLim",[min(x) max(x)],"YLim",[min(z) max(z)]);
    clim(ax,limits);
    colormap(ax,cmap);
    xlabel(ax,"x (mm)");ylabel(ax,"z (mm)");
    ax.TickDir="out";ax.LineWidth=1;
    xtickformat(ax,"%.1f");ytickformat(ax,"%.1f");
    hold(ax,"on");
    for i=1:numel(rois)
        c=double(rois(i).center_mm(:));
        w=double(rois(i).size_mm(:));
        rectangle(ax,"Position",[c(1)-w(1)/2,c(2)-w(2)/2,w(1),w(2)], ...
            "LineStyle","--","LineWidth",1.2,"EdgeColor","k");
    end
end
function x=safeMedian(v)
    x=NaN;if ~isempty(v),x=median(double(v));end
end
function x=safeMean(v)
    x=NaN;if ~isempty(v),x=mean(double(v));end
end
function x=safePercent(k,n)
    x=NaN;if n>0,x=100*double(k)/double(n);end
end
