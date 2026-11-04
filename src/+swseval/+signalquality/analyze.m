function out=analyze(D,roi,options)
%ANALYZE Spatial association of signal quality with the upper SWS tail.
% This is a descriptive study, not a classifier of ground-truth errors.
% NaN pairs are dropped metric-by-metric; overlapping patches are correlated.
arguments
    D (1,1) struct
    roi (1,1) struct
    options.HighTailPercentile (1,1) double {mustBeGreaterThan(options.HighTailPercentile,0),mustBeLessThan(options.HighTailPercentile,100)} = 90
    options.AbsoluteHighSWSThresholdMS (1,1) double = NaN
    options.R2Threshold (1,1) double {mustBeGreaterThanOrEqual(options.R2Threshold,0),mustBeLessThanOrEqual(options.R2Threshold,1)} = 0.98
    options.RatioThreshold (1,1) double {mustBePositive} = 10
end
map=swseval.io.validateMap(D.map);
[roiMask,extent]=swseval.roi.mask(roi,map);
valid=roiMask & map.valid_mask;
cs=double(map.cs_map);
assert(nnz(valid)>=5,"swseval:SignalQualityEmptyROI", ...
    "ROI must contain at least five positive, valid SWS estimates.");
if isfinite(options.AbsoluteHighSWSThresholdMS)
    threshold=options.AbsoluteHighSWSThresholdMS;
    thresholdKind="absolute";
else
    threshold=prctile(cs(valid),options.HighTailPercentile);
    thresholdKind="within_ROI_percentile";
end
high=valid & cs>=threshold;
baseline=valid & cs<=median(cs(valid));

data=D.quality;
if isfield(map,"q_map") && isequal(size(map.q_map),size(cs))
    data.q_predicted=double(map.q_map);
end
names=string(fieldnames(data));
n=numel(names);
metric=strings(n,1);pair_count=zeros(n,1);
median_all=nan(n,1);median_high=nan(n,1);median_baseline=nan(n,1);
spearman_rho=nan(n,1);spearman_depth_adjusted=nan(n,1);
auc_high_when_metric_increases=nan(n,1);
for i=1:n
    metric(i)=names(i);
    y=double(data.(metric(i)));
    assert(isequal(size(y),size(cs)),"swseval:QualityShape", ...
        "Metric %s does not match estimation grid.",metric(i));
    pair=valid & isfinite(y);
    pair_count(i)=nnz(pair);
    if nnz(pair)<5,continue;end
    median_all(i)=median(y(pair));
    if any(high&pair),median_high(i)=median(y(high&pair));end
    if any(baseline&pair),median_baseline(i)=median(y(baseline&pair));end
    spearman_rho(i)=rho(cs(pair),y(pair));
    xres=nan(size(cs));yres=nan(size(y));
    for zi=1:size(cs,1)
        keep=pair(zi,:);
        if nnz(keep)<2,continue;end
        xres(zi,keep)=cs(zi,keep)-median(cs(zi,keep));
        yres(zi,keep)=y(zi,keep)-median(y(zi,keep));
    end
    ok=pair & isfinite(xres) & isfinite(yres);
    spearman_depth_adjusted(i)=rho(xres(ok),yres(ok));
    auc_high_when_metric_increases(i)=aucRank(y(pair),high(pair));
end
metrics=table(metric,pair_count,median_all,median_high,median_baseline, ...
    spearman_rho,spearman_depth_adjusted,auc_high_when_metric_increases);

flags={data.r_squared<options.R2Threshold, ...
    data.amplitude_to_residual_ratio<options.RatioThreshold, ...
    data.r_squared<options.R2Threshold | ...
        data.amplitude_to_residual_ratio<options.RatioThreshold};
rule=["r_squared_below_threshold";"ratio_below_threshold";"either_rule"];
roi_flagged_fraction=nan(3,1);high_tail_detected_fraction=nan(3,1);
high_tail_fraction_among_retained=nan(3,1);retained_count=zeros(3,1);
for i=1:numel(flags)
    flagged=flags{i};
    % An unavailable quality metric must not silently become a pass.
    if i==1
        observed=isfinite(data.r_squared);
    elseif i==2
        observed=isfinite(data.amplitude_to_residual_ratio);
    else
        observed=isfinite(data.r_squared) & ...
            isfinite(data.amplitude_to_residual_ratio);
    end
    eligible=valid & observed;
    if ~any(eligible),continue;end
    roi_flagged_fraction(i)=nnz(eligible&flagged)/nnz(eligible);
    if nnz(eligible&high)>0
        high_tail_detected_fraction(i)=nnz(eligible&high&flagged)/nnz(eligible&high);
    end
    retained=eligible & ~flagged;
    retained_count(i)=nnz(retained);
    if nnz(retained)>0
        high_tail_fraction_among_retained(i)=nnz(high&retained)/nnz(retained);
    end
end
gates=table(rule,roi_flagged_fraction,high_tail_detected_fraction, ...
    high_tail_fraction_among_retained,retained_count);

summary=struct("roi_name",string(roi.name),"roi_extent_mm",extent, ...
    "frequency_hz",D.frequency_hz,"window_width_mm",D.window_width_mm, ...
    "selected_count",nnz(roiMask),"valid_count",nnz(valid), ...
    "high_count",nnz(high),"baseline_count",nnz(baseline), ...
    "median_sws_m_s",median(cs(valid)),"mean_sws_m_s",mean(cs(valid)), ...
    "max_sws_m_s",max(cs(valid)),"high_threshold_m_s",threshold, ...
    "threshold_kind",thresholdKind);
out=struct("summary",summary,"metrics",metrics,"gates",gates, ...
    "roi_mask",roiMask,"valid_mask",valid,"high_mask",high, ...
    "baseline_mask",baseline);
end

function v=rho(x,y)
% Spearman rank coefficient with explicit ties and no p-value; patches
% overlap, so naive independent-pixel p-values would be misleading.
x=double(x(:));y=double(y(:));
v=NaN;
if numel(x)<3 || all(x==x(1)) || all(y==y(1)),return;end
r=corrcoef(midRanks(x),midRanks(y));
v=r(1,2);
end

function a=aucRank(scores,labels)
% AUC is P(score_high_tail > score_rest), ties counted as one half.
scores=double(scores(:));labels=logical(labels(:));
n1=nnz(labels);n0=nnz(~labels);a=NaN;
if n1==0 || n0==0,return;end
ranks=midRanks(scores);
a=(sum(ranks(labels))-n1*(n1+1)/2)/(n1*n0);
end

function ranks=midRanks(x)
% Exact midranks avoid a Statistics Toolbox dependency in this function.
x=double(x(:));n=numel(x);ranks=zeros(n,1);
[sorted,idx]=sort(x);
i=1;
while i<=n
    j=i;
    while j<n && sorted(j+1)==sorted(i),j=j+1;end
    ranks(idx(i:j))=(i+j)/2;
    i=j+1;
end
end
