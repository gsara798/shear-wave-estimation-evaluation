function cmap=mapColormap(n)
%MAPCOLORMAP Canonical SWS colormap matching simviz.colormapSws.
arguments
 n (1,1) double {mustBeInteger,mustBePositive}=256
end
theme=swseval.viz.paperTheme();
anchors=[theme.rgb.blue.main;theme.rgb.teal.main; ...
 theme.rgb.green.light;theme.rgb.orange.light;theme.rgb.red.main];
cmap=interp1(linspace(0,1,size(anchors,1)),anchors,linspace(0,1,n),'pchip');
cmap=min(1,max(0,cmap));
end
