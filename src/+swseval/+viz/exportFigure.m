function files=exportFigure(fig,base,formats)
%EXPORTFIGURE Publication PNG, vector PDF and TIFF.
if nargin<3,formats=["png","pdf","tiff"];end
if ~isfolder(fileparts(base)),mkdir(fileparts(base));end
files=strings(1,numel(formats));
for i=1:numel(formats)
 fmt=string(formats(i));files(i)=string(base)+"."+fmt;
 if fmt=="pdf"
  exportgraphics(fig,files(i),'ContentType','vector','BackgroundColor','white');
 else
  exportgraphics(fig,files(i),'Resolution',300,'BackgroundColor','white');
 end
end
end
