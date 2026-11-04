function fig=plotComparison(D,A,options)
%PLOTCOMPARISON Co-registered SWS, q, and quality with upper-tail outlines.
arguments
    D (1,1) struct
    A (1,1) struct
    options.Visible (1,1) string {mustBeMember(options.Visible,["on","off"])} = "off"
end

map=D.map; q=D.quality;
panels={ ...
    double(map.cs_map),"Estimated SWS (m/s)",[1 4.5],"turbo"; ...
    quantileOrNaN(map),"Predicted REQ quantile",[0.5 0.9],"parula"; ...
    q.r_squared,"Harmonic fit R^2 (center)",[0.85 1],"parula"; ...
    q.amplitude_to_residual_ratio,"Amplitude / residual (center)",[0 25],"parula"; ...
    q.correlation_mean,"IQ correlation (center)",[0.9975 0.999],"parula"; ...
    q.r_squared_window,"R^2 (patch-window average)",[0.85 1],"parula"};
[X,Z]=meshgrid(double(map.x_mm),double(map.z_mm));
ext=A.summary.roi_extent_mm;
fig=figure("Color","white","Visible",char(options.Visible), ...
    "Position",[100 100 1550 930]);
tiled=tiledlayout(fig,2,3,"TileSpacing","compact","Padding","compact");
for i=1:size(panels,1)
    ax=nexttile(tiled,i);
    surf(ax,X,Z,zeros(size(X)),panels{i,1},"EdgeColor","none");
    view(ax,2);hold(ax,"on");
    if any(A.high_mask(:))
        contour(ax,X,Z,double(A.high_mask),[0.5 0.5], ...
            "LineColor",[0.91 0.1 0.4],"LineWidth",1.35);
    end
    rectangle(ax,"Position",[ext(1) ext(3) ext(2)-ext(1) ext(4)-ext(3)], ...
        "LineStyle","--","LineWidth",1.1,"EdgeColor","w");
    set(ax,"YDir","reverse","Layer","top");axis(ax,"image");
    xlim(ax,[max(min(map.x_mm),ext(1)-1.5) min(max(map.x_mm),ext(2)+1.5)]);
    ylim(ax,[max(min(map.z_mm),ext(3)-1.5) min(max(map.z_mm),ext(4)+1.5)]);
    colormap(ax,char(panels{i,4}));
    clim(ax,panels{i,3});colorbar(ax);
    title(ax,panels{i,2},"Interpreter","none");
    xlabel(ax,"x (mm)");ylabel(ax,"z (mm)");
end
title(tiled,sprintf("%s | %g Hz | SWS upper tail >= %.2f m/s", ...
    char(A.summary.roi_name),D.frequency_hz,A.summary.high_threshold_m_s));
end

function q=quantileOrNaN(map)
q=nan(size(map.cs_map));
if isfield(map,"q_map") && isequal(size(map.q_map),size(q))
    q=double(map.q_map);
end
end
