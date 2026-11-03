function out=run_plots(varargin)
%RUN_PLOTS Recreate comparison figures from saved estimates and ROI CSV.
c=sp_comparison_config(varargin{:});
out=plot_model_comparison(DataRoot=c.DataRoot, ...
    Experiments=c.Experiments,Frequencies=c.Frequencies, ...
    M=c.M,ComparisonName=c.comparisonName);
end
