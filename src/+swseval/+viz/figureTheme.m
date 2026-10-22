function theme=figureTheme()
%FIGURETHEME Consistent palette with REQ-ML and swsynth.
% Same hex codes as reqml.viz.figureTheme (2026).
theme=struct();
theme.font="Times New Roman";
theme.font_size_pt=9;
theme.line_width=1.5;
theme.resolution_dpi=300;
theme.colors=struct('blue',"#4834D4",'purple',"#30336B", ...
 'red',"#EB4D4B",'green',"#6AB04C",'teal',"#22A6B3", ...
 'orange',"#F0932B",'yellow',"#F9CA24",'gray',"#535C68");
theme.roi_colors=[hex2rgb(theme.colors.blue);hex2rgb(theme.colors.red); ...
 hex2rgb(theme.colors.green);hex2rgb(theme.colors.red); ...
 hex2rgb(theme.colors.teal);hex2rgb(theme.colors.purple)];
end
function out=hex2rgb(value)
v=char(erase(string(value),'#'));out=double(sscanf(v,'%2x%2x%2x')')/255;
end
