function files=plotROICombinedM(T,options)
%PLOTROICOMBINEDM One mean +/- spatial STD frequency plot per ROI and model.
% M curves use the shared paperTheme palette; spatial STD is not a CI.
arguments
 T table
 options.OutputDir (1,1) string
 options.Formats (1,:) string = ["png","pdf","tiff"]
 options.Frequencies (1,:) double = []
 options.MValues (1,:) double = []
 options.YLim (1,:) double = []
 options.YDecimals (1,1) double {mustBeInteger,mustBeNonnegative} = 2
 options.ShowErrorBars (1,1) logical = true
end
if ~isfolder(options.OutputDir),mkdir(options.OutputDir);end
required=["model","name","M","frequency_hz","mean_sws","std_sws"];
assert(all(ismember(required,string(T.Properties.VariableNames))), ...
 "swseval:InvalidSweepTable","Missing columns in sweep table.");
theme=swseval.viz.figureTheme();
models=unique(string(T.model),"stable");
roiNames=unique(string(T.name),"stable");
if isempty(options.Frequencies)
 frequencies=unique(double(T.frequency_hz))';
else
 frequencies=unique(double(options.Frequencies),"stable");
end
if isempty(options.MValues)
 mValues=unique(double(T.M))';
else
 mValues=unique(double(options.MValues),"stable");
end
assert(~isempty(frequencies)&&all(isfinite(frequencies)), ...
 "swseval:InvalidFrequencies","Expected finite frequencies.");
if ~isempty(options.YLim)
 assert(numel(options.YLim)==2 && options.YLim(1)<options.YLim(2), ...
  "swseval:InvalidYLim","YLim must contain increasing bounds.");
end
files=strings(0,1);
for model=models'
 for ri=1:numel(roiNames)
  roi=roiNames(ri);
  R=T(string(T.model)==model & string(T.name)==roi,:);
  fig=figure('Visible','off','Color','w','Position',[100 100 900 600]);
  cleanup=onCleanup(@()close(fig));
  ax=axes(fig);hold(ax,'on');
  plotted=false;
  for mi=1:numel(mValues)
   m=mValues(mi);
   S=R(double(R.M)==m & ismember(double(R.frequency_hz),frequencies),:);
   if isempty(S),continue;end
   S=sortrows(S,"frequency_hz");
   mColors=[theme.rgb.blue.main; theme.rgb.red.main; ...
    theme.rgb.green.main; theme.rgb.orange.main; ...
    theme.rgb.teal.main; theme.rgb.purple.main];
   color=mColors(mod(mi-1,size(mColors,1))+1,:);
   label="M="+string(m);
   if options.ShowErrorBars
    errorbar(ax,double(S.frequency_hz),double(S.mean_sws), ...
     double(S.std_sws),double(S.std_sws),'-o', ...
     'Color',color,'LineWidth',theme.line_width, ...
     'MarkerSize',6,'MarkerFaceColor','w','CapSize',8, ...
     'DisplayName',label);
   else
    plot(ax,double(S.frequency_hz),double(S.mean_sws),'-o', ...
     'Color',color,'LineWidth',theme.line_width, ...
     'MarkerSize',6,'MarkerFaceColor','w','DisplayName',label);
   end
   plotted=true;
  end
  if ~plotted
   clear cleanup
   continue;
  end
  xlabel(ax,'Frequency (Hz)');ylabel(ax,'SWS (m/s)');
  set(ax,'FontName',char(theme.font),'FontSize',theme.font_size_pt+2, ...
   'TickDir','out','LineWidth',0.8,'Box','on');
  xticks(ax,sort(frequencies));xtickformat(ax,'%.0f');
  if numel(frequencies)==1
   xlim(ax,frequencies(1)+[-1 1]*max(1,frequencies(1)*0.05));
  else
   xlim(ax,[min(frequencies) max(frequencies)]);
  end
  ytickformat(ax,sprintf('%%.%df',options.YDecimals));
  if ~isempty(options.YLim),ylim(ax,options.YLim);end
  grid(ax,'on');
  lgd=legend(ax,'Location','best');set(lgd,'Interpreter','none');
  safeName=regexprep(char(roi),'[^A-Za-z0-9_-]','_');
  if isempty(safeName),safeName=sprintf('roi_%d',ri);end
  base=fullfile(options.OutputDir, ...
   "roi_mean_std_vs_frequency_by_M_"+model+"_"+string(safeName));
  swseval.viz.exportFigure(fig,base,options.Formats);
  files(end+1,1)=base; %#ok<AGROW>
  clear cleanup
 end
end
end
