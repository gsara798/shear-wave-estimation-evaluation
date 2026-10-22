function files=renderROIs(map,rois,outputBase,options)
%RENDERROIS Draw physical map and labeled ROI rectangles using paper palette.
arguments
 map struct
 rois struct
 outputBase (1,1) string
 options.SWSColorLimits (1,:) double=[]
 options.Formats (1,:) string=["png","pdf","tiff"]
 options.ShowTitles (1,1) logical=false
end
map=swseval.io.validateMap(map);theme=swseval.viz.figureTheme();
fig=figure('Visible','off','Color','w','Position',[100 100 900 720]);
clean=onCleanup(@()close(fig));ax=axes(fig);
A=double(map.cs_map);A(~map.valid_mask)=NaN;
imagesc(ax,map.x_mm,map.z_mm,A,'AlphaData',isfinite(A));
set(ax,'YDir','normal');axis(ax,'image');hold(ax,'on');
colormap(ax,swseval.viz.mapColormap());cb=colorbar(ax);ylabel(cb,'SWS (m/s)');
if ~isempty(options.SWSColorLimits),clim(ax,options.SWSColorLimits);end
for i=1:numel(rois)
 [~,e]=swseval.roi.mask(rois(i),map);
 if string(rois(i).units)=="pixel"
  xmin=interp1(1:numel(map.x_mm),map.x_mm,e(1),'linear','extrap');
  xmax=interp1(1:numel(map.x_mm),map.x_mm,e(2),'linear','extrap');
  zmin=interp1(1:numel(map.z_mm),map.z_mm,e(3),'linear','extrap');
  zmax=interp1(1:numel(map.z_mm),map.z_mm,e(4),'linear','extrap');
 else
  xmin=e(1);xmax=e(2);zmin=e(3);zmax=e(4);
 end
 color=theme.roi_colors(mod(i-1,size(theme.roi_colors,1))+1,:);
 rectangle(ax,'Position',[xmin,zmin,xmax-xmin,zmax-zmin], ...
  'EdgeColor',color,'LineWidth',2.2);
 text(ax,xmin,zmin,string(rois(i).name),'Color',color, ...
  'FontWeight','bold','FontSize',theme.font_size_pt+2, ...
  'VerticalAlignment','bottom','Interpreter','none');
end
xlabel(ax,'x (mm)');ylabel(ax,'z (mm)');
set(ax,'FontName',theme.font,'FontSize',theme.font_size_pt, ...
 'LineWidth',0.8,'TickDir','out','Box','on');
if options.ShowTitles,title(ax,'SWS and ROIs');end
files=swseval.viz.exportFigure(fig,outputBase,options.Formats);
end
