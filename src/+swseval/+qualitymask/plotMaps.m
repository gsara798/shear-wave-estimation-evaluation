function plotMaps(A,outputFile,options)
%PLOTMAPS Descriptive experimental risk/coverage maps, without ground truth.
arguments
    A (1,1) struct
    outputFile (1,1) string
    options.Title (1,1) string = "Reduced14 quality-mask transfer"
end
assert(~isfile(outputFile),"QualityTransfer:FigureExists", ...
    "Refusing to replace existing figure: %s",outputFile);
nr=numel(A.max_risks);
fig=figure("Visible","off","Color","w", ...
    "Position",[100 100 410*(nr+2) 440]);
closeFig=onCleanup(@()close(fig)); %#ok<NASGU>
t=tiledlayout(fig,1,nr+2,"TileSpacing","compact", ...
    "Padding","compact");
title(t,options.Title,"Interpreter","none");
original=A.original_sws_map;
values=original(isfinite(original));
if isempty(values)
    limits=[0 1];
else
    limits=[min(values) max(values)];
    if limits(2)<=limits(1),limits(2)=limits(1)+0.01;end
end
showOne(nexttile(t),A.x_mm,A.z_mm,original, ...
    "Original SWS [m/s]",limits);
showOne(nexttile(t),A.x_mm,A.z_mm,A.risk_map, ...
    "Predicted error risk",[0 1]);
for k=1:nr
    label="SWS | risk <= "+num2str(A.max_risks(k),"%.2g");
    showOne(nexttile(t),A.x_mm,A.z_mm, ...
        A.masked_sws_maps(:,:,k),label,limits);
end
exportgraphics(fig,outputFile,"Resolution",160);
end

function showOne(ax,x,z,data,label,limits)
im=imagesc(ax,x,z,double(data));
set(im,"AlphaData",double(isfinite(data)));
set(ax,"YDir","reverse","Color","w");
axis(ax,"image");
clim(ax,limits);
colorbar(ax);
xlabel(ax,"x [mm]");ylabel(ax,"Depth z [mm]");
title(ax,label,"Interpreter","none");
end
