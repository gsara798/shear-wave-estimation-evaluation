function out=run_analysis(varargin)
%RUN_ANALYSIS Evaluate the saved five-arm estimates with fixed ROI definitions.
% Does not run EWP, fit models, or recompute predictions.
c=sp_comparison_config(varargin{:});
T=analyzeAll(c,c);
out=struct("stage","analyze","summary",T,"arms",c.arms, ...
    "comparison_name",c.comparisonName);
if c.MakeComparisonPlots
    plot_model_comparison(DataRoot=c.DataRoot, ...
        Experiments=c.Experiments,Frequencies=c.Frequencies, ...
        M=c.M,ComparisonName=c.comparisonName);
end
end

function T=analyzeAll(o,c)
assert(~isempty(which("swseval.analyzeSweep")), ...
    "SPCompare:SWSEval","swseval src not accessible.");
rois=[swseval.roi.rectangle("ROI1",Center=[18 10], ...
        Size=[10 5],Units="mm"), ...
      swseval.roi.rectangle("ROI2",Center=[18 25], ...
        Size=[10 5],Units="mm")];
parts=cell(numel(o.Experiments),1);
for i=1:numel(o.Experiments)
    experiment=o.Experiments(i);
    root=fullfile(o.DataRoot,experiment);
    estimateRoot=fullfile(root,"estimates",c.comparisonName);
    analysisRoot=fullfile(root,"analysis",c.comparisonName);
    fprintf("\n=== ANALYZE %s ===\n",experiment);
    tab=swseval.analyzeSweep(rois, ...
        EstimatesRoot=estimateRoot,Models=c.arms, ...
        Frequencies=o.Frequencies,MValues=o.M, ...
        OutputDir=analysisRoot, ...
        SWSColorLimits=[1 4],FrequencyYLim=[1 4], ...
        ContinueOnMissing=false,ExportMaps=true, ...
        PlotCombinedM=false,YDecimals=2);
    tab.experiment=repmat(experiment,height(tab),1);
    tab=movevars(tab,"experiment","Before",1);
    if any(tab.selected_pixels==0)
        warning("SPCompare:EmptyROI", ...
            "Some ROI(s) contain no map centers in %s.",experiment);
    end
    parts{i}=tab;
end
T=vertcat(parts{:});
reportDir=fullfile(o.DataRoot,c.comparisonName);
if ~isfolder(reportDir),mkdir(reportDir);end
writetable(T,fullfile(reportDir,"all_experiments_roi_statistics.csv"));
fprintf("\nCombined ROI table saved: %s\n",reportDir);
end
