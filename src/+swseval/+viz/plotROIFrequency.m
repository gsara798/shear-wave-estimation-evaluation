function files=plotROIFrequency(T,options)
%PLOTROIFREQUENCY ROI median SWS vs frequency; bars show spatial IQR.
% Error bars are descriptive spatial spread, NOT independent-sample CI.
arguments
 T table
 options.OutputDir (1,1) string
 options.Formats (1,:) string = ["png","pdf","tiff"]
end
if ~isfolder(options.OutputDir),mkdir(options.OutputDir);end
theme=swseval.viz.figureTheme();
models=unique(string(T.model),"stable");
ms=unique(double(T.M),"stable");
roiNames=unique(string(T.name),"stable");
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
   if isempty(R),continue;end
   [freq,order]=sort(double(R.frequency_hz));
   values=double(R.median_sws(order));
   low=values-double(R.p05_sws(order));
   high=double(R.p95_sws(order))-values;
   color=theme.roi_colors(mod(ri-1,size(theme.roi_colors,1))+1,:);
   errorbar(ax,freq,values,low,high,'-o', ...
    'Color',color,'LineWidth',theme.line_width, ...
    'MarkerSize',6,'MarkerFaceColor','w', ...
    'CapSize',8,'DisplayName',sprintf('ROI_{%d}',ri));
  end
  xlabel(ax,'Frequency (Hz)');ylabel(ax,'SWS (m/s)');
  set(ax,'FontName',char(theme.font),'FontSize',theme.font_size_pt+2, ...
   'TickDir','out','LineWidth',0.8,'Box','on');
  grid(ax,'on');
  lgd=legend(ax,'Location','best');set(lgd,'Interpreter','tex');
  title(ax,model+" | M="+string(m)+" | median and spatial P5–P95", ...
   'FontName',char(theme.font),'FontWeight','normal');
  base=fullfile(options.OutputDir,model+"_M"+string(m)+"_sws_vs_frequency");
  swseval.viz.exportFigure(fig,base,options.Formats);
  files(end+1,1)=base; %#ok<AGROW>
  clear cleanup
 end
end
end
