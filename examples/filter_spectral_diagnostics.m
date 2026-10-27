%% FILTER SPECTRAL DIAGNOSTICS — existing processed data only
% Compare no spatial filter / lowpass 1 m/s / donut 5 m/s at 300, 600 Hz.
% Spectra are computed on the SAME physically defined ROI for each filter.
% This is a *diagnostic of preprocessing*, not a calibrated SNR measurement.
clearvars; clc
evalRepo="/Users/sara/local/shear-wave-estimation-evaluation";
addpath(fullfile(evalRepo,"src"));
root="/Users/sara/local/experimental-data-reorganized/2026-02-27";
experiments=["2026Feb27_homo_5perc_sp","2026Feb27_homo_5perc_rswe", ...
             "2026Feb27_homo_10perc_sp","2026Feb27_homo_10perc_rswe"];
freqs=[300 600]; filters=["none","lowpass_1ms","donut_5ms"];
labels=["No filter","Lowpass 1 m/s","Donut 5 m/s"];
% ROI [center x, center z, width, height] in mm. Set separately per experiment
% if the common rectangle overlaps source/boundary/low-signal regions.
roi=[18 20 12 12];
% This script uses the SAME spatial region for all filters of one acquisition.
theme=swseval.viz.paperTheme();
colors=[theme.rgb.gray.main;theme.rgb.blue.main;theme.rgb.green.main];
allMetrics=table();
for ei=1:numel(experiments)
 expName=experiments(ei); expRoot=fullfile(root,expName);
 out=fullfile(expRoot,"analysis","filter_spectral_diagnostics");
 if ~isfolder(out),mkdir(out);end
 for f=freqs
  S=cell(numel(filters),1);
  ok=false(numel(filters),1);
  for j=1:numel(filters)
   fname=fullfile(expRoot,"processed","filterstudy_"+filters(j), ...
     sprintf("%gHz",f),"wavefield_sample.mat");
   if ~isfile(fname)
    warning("Missing: %s",fname);continue
   end
   q=load(fname,"wavefield_sample");w=q.wavefield_sample;
   U=double(w.wavefield.data_zx);
   x=double(w.coordinates.x_m(:)')*1e3;
   z=double(w.coordinates.z_m(:))*1e3;
   xi=find(x>=roi(1)-roi(3)/2 & x<=roi(1)+roi(3)/2);
   zi=find(z>=roi(2)-roi(4)/2 & z<=roi(2)+roi(4)/2);
   if numel(xi)<8 || numel(zi)<8
    warning("Insufficient ROI samples %s %gHz %s",expName,f,filters(j));continue
   end
   A=U(zi,xi);
   dx=median(diff(x(xi)))*1e-3; dz=median(diff(z(zi)))*1e-3;
   % Local Hanning reduces spectral leakage from the ROI crop.
   wx=hannLocal(numel(xi));wz=hannLocal(numel(zi));
   W=wz*wx'; F=fftshift(fft2(A.*W));
   P=abs(F).^2;
   [nz,nx]=size(P);
   kx=2*pi*(-floor(nx/2):ceil(nx/2)-1)/(nx*dx);
   kz=2*pi*(-floor(nz/2):ceil(nz/2)-1)/(nz*dz);
   [KX,KZ]=meshgrid(kx,kz);
   k0=2*pi*f/3;  % reference c_guess 3 m/s, used ONLY to normalize axes
   kr=hypot(KX,KZ)/k0;
   edges=linspace(0,max(kr(:)),90);
   bin=discretize(kr(:),edges);
   good=isfinite(bin);
   radial=accumarray(bin(good),P(good),[numel(edges)-1 1],@sum,0);
   radial=radial/max(sum(radial),realmin);
   cdf=cumsum(radial);
   S{j}=struct("P",P/max(sum(P(:)),realmin),"kx",kx/k0,"kz",kz/k0, ...
     "radial",radial,"cdf",cdf,"r",(edges(1:end-1)+edges(2:end))/2, ...
     "U",A,"dx",dx,"dz",dz);
   ok(j)=true;
   energy=sum(abs(A(:)).^2);
   centroid=sum(kr(:).*P(:))/max(sum(P(:)),realmin);
   % Median radial wavenumber: diagnostic, not REQ trained quantile.
   q50=S{j}.r(find(cdf>=0.5,1,"first"));
   allMetrics=[allMetrics;table(expName,f,filters(j),energy,centroid,q50, ...
      "VariableNames",["experiment","frequency_hz","filter","roi_energy", ...
                        "radial_centroid_k_over_k0","radial_median_k_over_k0"])]; %#ok<AGROW>
  end
  if ~any(ok),continue;end
  fig=figure("Visible","off","Color","w","Position",[100 100 1350 430]);
  tiledlayout(fig,1,3,"Padding","compact","TileSpacing","compact");
  for j=1:numel(filters)
   ax=nexttile; if ~ok(j),axis(ax,"off");continue;end
   P=S{j}.P;
   imagesc(ax,S{j}.kx,S{j}.kz,log10(P+1e-12));
   axis(ax,"image");set(ax,"YDir","normal");xlabel(ax,"k_x/k_0");ylabel(ax,"k_z/k_0");
   title(ax,labels(j),"FontWeight","normal");
   colormap(ax,swseval.viz.mapColormap(256));cb=colorbar(ax);ylabel(cb,"log_{10} normalized energy");
  end
  base=fullfile(out,sprintf("spectrum2d_%gHz",f));
  swseval.viz.exportFigure(fig,base,["png","pdf"]);close(fig);
  fig=figure("Visible","off","Color","w","Position",[100 100 860 580]);
  ax=axes(fig);hold(ax,"on");
  for j=1:numel(filters)
   if ok(j)
    plot(ax,S{j}.r,S{j}.cdf,"Color",colors(j,:), ...
      "LineWidth",1.8,"DisplayName",labels(j));
   end
  end
  xlabel(ax,"Radial k / k_0 (c_{guess}=3 m/s)");
  ylabel(ax,"Cumulative spectral energy");
  ylim(ax,[0 1]);grid(ax,"on");legend(ax,"Location","southeast");
  set(ax,"FontName",char(theme.style.font_name),"FontSize",11);
  base=fullfile(out,sprintf("radial_cdf_%gHz",f));
  swseval.viz.exportFigure(fig,base,["png","pdf"]);close(fig);
  fprintf("%s | %g Hz: %d filter spectra\n",expName,f,nnz(ok));
 end
end
if ~isempty(allMetrics)
 out=fullfile(root,"filter_spectral_diagnostics_summary");
 if ~isfolder(out),mkdir(out);end
 writetable(allMetrics,fullfile(out,"spectral_roi_metrics.csv"));
end

function w=hannLocal(n)
% Periodic Hann without signal-processing dependency.
w=0.5-0.5*cos(2*pi*(0:n-1)'/n);
end
