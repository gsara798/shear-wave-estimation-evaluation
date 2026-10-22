function files=plotROIFrequency(T,options)
%PLOTROIFREQUENCY Publication figure: ROI mean SWS +/- spatial std vs frequency.
% Spatial std describes within-ROI variation, not independent-sample uncertainty.
arguments
 T table
 options.OutputDir (1,1) string
 options.Formats (1,:) string = ["png","pdf","tiff"]
 options.Frequencies (1,:) double = []
 options.YLim (1,:) double = []
 options.YDecimals (1,1) double {mustBeInteger,mustBeNonnegative} = 2
 options.ShowTitles (1,1) logical = false
end
if ~isfolder(options.OutputDir),mkdir(options.OutputDir);end
theme=swseval.viz.figureTheme();
models=unique(string(T.model),"stable");
ms=unique(double(T.M),"stable");
roiNames=unique(string(T.name),"stable");
if isempty(options.Frequencies)
 allFreq=unique(double(T.frequency_hz))';
else
 allFreq=unique(options.Frequencies,"stable");
end
files=strings(0,1);
for model=models'
 for m=ms'
  S=T(string(T.model)==model & double(T.M)==m,:);
  if isempty(S),continue;end
  fig=figure('Visible','off','Color','w','Position',[100 100 900 600]);
  cleanup=onCleanup(@()close(fig));
  ax=axes(fig);hold(ax,'on');
  for ri=1:numel(roiNames)
   R=S(string(S.name)==roiNames(ri),:);
   R=R(ismember(double(R.frequency_hz),allFreq),:);
   if isempty(R),continue;end
   [freq,order]=sort(double(R.frequency_hz));
   values=double(R.mean_sws(order));
   spread=double(R.std_sws(order));
   color=theme.roi_colors(mod(ri-1,size(theme.roi_colors,1))+1,:);
   errorbar(ax,freq,values,spread,spread,'-o', ...
    'Color',color,'LineWidth',theme.line_width, ...
    'MarkerSize',6,'MarkerFaceColor','w', ...
    'CapSize',8,'DisplayName',sprintf('ROI_{%d}',ri));
  end
  xlabel(ax,'Frequency (Hz)');ylabel(ax,'SWS (m/s)');
  set(ax,'FontName',char(theme.font),'FontSize',theme.font_size_pt+2, ...
   'TickDir','out','LineWidth',0.8,'Box','on');
  xticks(ax,sort(allFreq));
  xtickformat(ax,'%.0f');
  if numel(allFreq)==1
   xlim(ax,allFreq(1)+[-1 1]*max(1,allFreq(1)*.05));
  else
   xlim(ax,[min(allFreq) max(allFreq)]);
  end
  ytickformat(ax,sprintf('%%.%df',options.YDecimals));
  if ~isempty(options.YLim)
   assert(numel(options.YLim)==2 && options.YLim(1)<options.YLim(2), ...
    'swseval:InvalidYLim','YLim must contain increasing bounds.');
   ylim(ax,options.YLim);
  end
  grid(ax,'on');
  lgd=legend(ax,'Location','best');set(lgd,'Interpreter','tex');
  if options.ShowTitles
   title(ax,model+" | M="+string(m)+" | mean and spatial std", ...
    'FontName',char(theme.font),'FontWeight','normal');
  end
  base=fullfile(options.OutputDir, ...
   "roi_mean_std_vs_frequency_"+model+"_M"+string(m));
  swseval.viz.exportFigure(fig,base,options.Formats);
  files(end+1,1)=base; %#ok<AGROW>
  clear cleanup
 end
end
end
