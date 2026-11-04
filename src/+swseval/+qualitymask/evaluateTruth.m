function [summary,rows]=evaluateTruth(A,roiMask,truthMap,options)
%EVALUATETRUTH Compare predicted quality risk against known simulated SWS.
% Reports only patches with a valid SWS estimate. Invalid SWS is counted
% separately; do not give the artificial invalid-risk sentinel AUC credit.
arguments
    A (1,1) struct
    roiMask logical
    truthMap double
    options.ErrorThresholdPct (1,1) double {mustBePositive} = 10
end
sz=size(A.original_sws_map);
assert(isequal(size(roiMask),sz) && isequal(size(truthMap),sz), ...
    "QualitySynth:ROIShape","ROI, truth and SWS must share a map grid.");
assert(all(isfinite(truthMap(roiMask)) & truthMap(roiMask)>0), ...
    "QualitySynth:Truth","True central SWS must be finite and positive.");
valid=roiMask & logical(A.valid_mask) & ...
    isfinite(A.original_sws_map) & A.original_sws_map>0;
count=nnz(valid);
assert(count>0,"QualitySynth:EmptyROI", ...
    "No valid SWS predictions exist inside the requested ROI.");
[iz,ix]=find(valid);
idx=sub2ind(sz,iz,ix);
truth=double(truthMap(idx));
speed=double(A.original_sws_map(idx));
risk=double(A.risk_map(idx));
errorPct=100*abs(speed-truth)./truth;
high=errorPct>options.ErrorThresholdPct;
scored=isfinite(risk) & risk>=0 & risk<=1;
if any(high(scored)) && any(~high(scored))
    nPos=nnz(high(scored));
    nNeg=nnz(~high(scored));
    ranked=tiedrank(risk(scored));
    pos=high(scored);
    auc=(sum(ranked(pos))-nPos*(nPos+1)/2)/(nPos*nNeg);
else
    auc=NaN; % AUC is undefined for a single observed error class.
end
brier=NaN;
if any(scored)
    brier=mean((risk(scored)-double(high(scored))).^2);
end
cutoffs=double(A.max_risks(:));
cells=cell(numel(cutoffs),1);
for j=1:numel(cutoffs)
    retained=scored & risk<=cutoffs(j);
    nRet=nnz(retained);
    retErr=NaN;retMape=NaN;
    if nRet>0
        retErr=mean(high(retained));
        retMape=mean(errorPct(retained));
    end
    highRemoved=NaN;
    if any(high),highRemoved=nnz(high & ~retained)/nnz(high);end
    correctRemoved=NaN;
    if any(~high),correctRemoved=nnz(~high & ~retained)/nnz(~high);end
    cells{j}=table(cutoffs(j),count,nnz(scored), ...
        nnz(roiMask & ~A.valid_mask),nRet,nRet/count, ...
        mean(high),mean(errorPct),mean(risk(scored)), ...
        auc,brier,retErr,retMape,highRemoved,correctRemoved, ...
        VariableNames=["max_risk","valid_count","scored_count", ...
        "invalid_count","retained_count","fraction_retained_valid", ...
        "high_error_fraction_valid","mape_valid_pct", ...
        "mean_predicted_risk","auc","brier", ...
        "high_error_fraction_retained","mape_retained_pct", ...
        "high_error_rejection_fraction", ...
        "correct_rejection_fraction"]);
end
summary=vertcat(cells{:});
rows=table(iz,ix,double(A.x_mm(ix(:))),double(A.z_mm(iz(:))), ...
    truth,speed,errorPct,high,risk,scored, ...
    VariableNames=["map_iz","map_ix","x_mm","z_mm", ...
    "truth_sws_m_s","estimated_sws_m_s","absolute_error_pct", ...
    "high_error","risk_probability","risk_scored"]);
end
