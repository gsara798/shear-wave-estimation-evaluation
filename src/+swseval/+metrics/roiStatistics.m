function T=roiStatistics(map,rois)
%ROISTATISTICS Descriptive ROI statistics; avoid independence assumptions.
map=swseval.io.validateMap(map);
assert(isstruct(rois)&&~isempty(rois),'swseval:InvalidROIs');
n=numel(rois);
name=strings(n,1);units=strings(n,1);
selected_pixels=zeros(n,1);valid_pixels=zeros(n,1);valid_fraction=nan(n,1);
mean_sws=nan(n,1);median_sws=nan(n,1);std_sws=nan(n,1);
cv_percent=nan(n,1);iqr_sws=nan(n,1);p05_sws=nan(n,1);
p95_sws=nan(n,1);min_sws=nan(n,1);max_sws=nan(n,1);
for i=1:n
 name(i)=string(rois(i).name);units(i)=string(rois(i).units);
 mask=swseval.roi.mask(rois(i),map);
 valid=mask & map.valid_mask;
 selected_pixels(i)=nnz(mask);valid_pixels(i)=nnz(valid);
 if selected_pixels(i)>0,valid_fraction(i)=valid_pixels(i)/selected_pixels(i);end
 y=double(map.cs_map(valid));
 if isempty(y),continue;end
 mean_sws(i)=mean(y);median_sws(i)=median(y);std_sws(i)=std(y);
 if abs(mean_sws(i))>eps,cv_percent(i)=100*std_sws(i)/mean_sws(i);end
 iqr_sws(i)=iqr(y);p05_sws(i)=prctile(y,5);p95_sws(i)=prctile(y,95);
 min_sws(i)=min(y);max_sws(i)=max(y);
end
T=table(name,units,selected_pixels,valid_pixels,valid_fraction, ...
 mean_sws,median_sws,std_sws,cv_percent,iqr_sws,p05_sws,p95_sws, ...
 min_sws,max_sws);
end
