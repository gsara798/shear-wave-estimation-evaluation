function T=roiStatistics(map,rois)
%ROISTATISTICS Descriptive ROI statistics and reproducible physical geometry.
% Original coordinates retain input units. *_mm columns refer to the actual
% bounding box of selected pixel centers (NaN if no pixels are selected).
map=swseval.io.validateMap(map);
assert(isstruct(rois)&&~isempty(rois),'swseval:InvalidROIs');
n=numel(rois);
name=strings(n,1);units=strings(n,1);
center_x=zeros(n,1);center_z=zeros(n,1);
width=zeros(n,1);height=zeros(n,1);
xmin=zeros(n,1);xmax=zeros(n,1);zmin=zeros(n,1);zmax=zeros(n,1);
selected_xmin_mm=nan(n,1);selected_xmax_mm=nan(n,1);
selected_zmin_mm=nan(n,1);selected_zmax_mm=nan(n,1);
selected_pixels=zeros(n,1);valid_pixels=zeros(n,1);valid_fraction=nan(n,1);
mean_sws=nan(n,1);median_sws=nan(n,1);std_sws=nan(n,1);
cv_percent=nan(n,1);iqr_sws=nan(n,1);p05_sws=nan(n,1);
p95_sws=nan(n,1);min_sws=nan(n,1);max_sws=nan(n,1);
for i=1:n
 name(i)=string(rois(i).name);units(i)=string(rois(i).units);
 center_x(i)=rois(i).center(1);center_z(i)=rois(i).center(2);
 width(i)=rois(i).size(1);height(i)=rois(i).size(2);
 [selected,extent]=swseval.roi.mask(rois(i),map);
 xmin(i)=extent(1);xmax(i)=extent(2);
 zmin(i)=extent(3);zmax(i)=extent(4);
 xcol=any(selected,1);zrow=any(selected,2);
 if any(xcol) && any(zrow)
  xs=map.x_mm(xcol);zs=map.z_mm(zrow);
  selected_xmin_mm(i)=min(xs);selected_xmax_mm(i)=max(xs);
  selected_zmin_mm(i)=min(zs);selected_zmax_mm(i)=max(zs);
 end
 valid=selected & map.valid_mask;
 selected_pixels(i)=nnz(selected);valid_pixels(i)=nnz(valid);
 if selected_pixels(i)>0,valid_fraction(i)=valid_pixels(i)/selected_pixels(i);end
 y=double(map.cs_map(valid));
 if isempty(y),continue;end
 mean_sws(i)=mean(y);median_sws(i)=median(y);std_sws(i)=std(y);
 if abs(mean_sws(i))>eps,cv_percent(i)=100*std_sws(i)/mean_sws(i);end
 iqr_sws(i)=iqr(y);p05_sws(i)=prctile(y,5);p95_sws(i)=prctile(y,95);
 min_sws(i)=min(y);max_sws(i)=max(y);
end
T=table(name,units,center_x,center_z,width,height, ...
 xmin,xmax,zmin,zmax,selected_xmin_mm,selected_xmax_mm, ...
 selected_zmin_mm,selected_zmax_mm, ...
 selected_pixels,valid_pixels,valid_fraction, ...
 mean_sws,median_sws,std_sws,cv_percent,iqr_sws,p05_sws,p95_sws, ...
 min_sws,max_sws);
end
