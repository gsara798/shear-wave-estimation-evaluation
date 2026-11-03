function out=analyze_swsynth_comparison(C)
%ANALYZE_SWSYNTH_COMPARISON ROI summaries with known truth/common valid pixels.
% A shared valid mask is formed per case across all selected model arms.
arguments
    C (1,1) struct
end
assert(~isempty(which("swseval.metrics.roiStatistics")), ...
    "SynthCompare:SWSEvalMissing","SWS-Eval src unavailable.");
T=C.Cases;
rows=cell(height(T)*numel(C.Arms)*2,1);
n=0;
for i=1:height(T)
    caseID=T.case_id(i);
    armMaps=cell(numel(C.Arms),1);
    for a=1:numel(C.Arms)
        file=swsynth_comparison_estimate_file(C,T(i,:),C.Arms(a));
        assert(isfile(file),"SynthCompare:EstimateMissing", ...
            "Missing inference for %s / %s: %s",caseID,C.Arms(a),file);
        armMaps{a}=swseval.io.loadReqmlResult(file);
    end
    reference=armMaps{1};
    common=reference.valid_mask;
    for a=2:numel(C.Arms)
        map=armMaps{a};
        assert(isequal(size(map.cs_map),size(reference.cs_map)) && ...
            isequal(map.x_mm,reference.x_mm) && ...
            isequal(map.z_mm,reference.z_mm), ...
            "SynthCompare:UnpairedGrids", ...
            "Model patch centers differ for %s; common support undefined.",caseID);
        common=common & map.valid_mask;
    end
    [rois,truth]=swsynth_comparison_rois(T.group(i), ...
        T.reference_cs_m_s(i));
    for ri=1:numel(rois)
        [selected,~]=swseval.roi.mask(rois(ri),reference);
        shared=selected & common;
        N=nnz(shared);
        selectedN=nnz(selected);
        if N==0
            warning("SynthCompare:EmptyCommonSupport", ...
                "No common valid pixels in %s / %s.",caseID,rois(ri).name);
        end
        for a=1:numel(C.Arms)
            map=armMaps{a};
            row=swseval.metrics.roiStatistics(map,rois(ri));
            speed=double(map.cs_map(shared));
            q=nan(size(speed));
            if isfield(map,"q_map") && ...
                    isequal(size(map.q_map),size(map.cs_map))
                q=double(map.q_map(shared));
            end
            q=q(isfinite(q));
            row.series=T.series(i);
            row.case_id=caseID;
            row.group=T.group(i);
            row.model=C.Arms(a);
            row.frequency_hz=T.frequency_hz(i);
            row.M=C.M;
            row.reference_cs_m_s=truth(ri);
            row.common_valid_pixels=N;
            row.common_valid_fraction=N/max(1,selectedN);
            row.mean_sws_common=NaN;
            row.median_sws_common=NaN;
            row.std_sws_common=NaN;
            row.cv_percent_common=NaN;
            row.bias_m_s_common=NaN;
            row.bias_percent_common=NaN;
            row.mae_m_s_common=NaN;
            row.mape_percent_common=NaN;
            row.mean_q_common=NaN;
            row.median_q_common=NaN;
            row.std_q_common=NaN;
            row.finite_q_count=numel(q);
            if ~isempty(speed)
                row.mean_sws_common=mean(speed);
                row.median_sws_common=median(speed);
                row.std_sws_common=std(speed);
                row.cv_percent_common=100*std(speed)/mean(speed);
                errors=speed-truth(ri);
                row.bias_m_s_common=mean(errors);
                row.bias_percent_common=100*mean(errors)/truth(ri);
                row.mae_m_s_common=mean(abs(errors));
                row.mape_percent_common=100*mean(abs(errors))/truth(ri);
            end
            if ~isempty(q)
                row.mean_q_common=mean(q);
                row.median_q_common=median(q);
                row.std_q_common=std(q);
            end
            row=movevars(row, ...
                ["series","case_id","group","model", ...
                "frequency_hz","M","reference_cs_m_s"],"Before",1);
            n=n+1;
            rows{n}=row;
        end
    end
    fprintf("[%d/%d] analyzed %s (%d common valid patch centers)\n", ...
        i,height(T),caseID,nnz(common));
end
assert(n>0,"SynthCompare:NoStatistics","No ROI values evaluated.");
summary=vertcat(rows{1:n});
root=C.analysisRoot;
if ~isfolder(root),mkdir(root);end
summaryFile=fullfile(root,"all_cases_roi_statistics.csv");
writetable(summary,summaryFile);
shifts=frequencyShifts(summary,C);
shiftFile=fullfile(root,"frequency_shifts_300_600.csv");
writetable(shifts,shiftFile);
out=struct("summary",summary,"frequency_shifts",shifts, ...
    "summary_file",summaryFile,"frequency_shifts_file",shiftFile);
fprintf("ROI summary: %s\n300-to-600 Hz shifts: %s\n", ...
    summaryFile,shiftFile);
end

function D=frequencyShifts(T,C)
series=unique(string(T.series),"stable");
entries=cell(numel(series)*numel(C.Arms)*2,1);
n=0;
for s=series'
    S=T(string(T.series)==s,:);
    roiNames=unique(string(S.name),"stable");
    for a=C.Arms
        for roi=roiNames'
            R=S(string(S.model)==a & string(S.name)==roi,:);
            R=sortrows(R,"frequency_hz");
            assert(height(R)==4 && ...
                isequal(double(R.frequency_hz),C.Frequencies'), ...
                "SynthCompare:IncompleteSeries", ...
                "Expected four frequencies for %s/%s/%s.",s,a,roi);
            n=n+1;
            entries{n}=table(s,a,roi,R.reference_cs_m_s(1), ...
                R.mean_sws_common(4)-R.mean_sws_common(1), ...
                R.bias_m_s_common(4)-R.bias_m_s_common(1), ...
                R.median_q_common(4)-R.median_q_common(1), ...
                R.mape_percent_common(1),R.mape_percent_common(4), ...
                VariableNames=["series","model","roi","reference_cs_m_s", ...
                "delta_mean_sws_600_minus_300_m_s", ...
                "delta_bias_600_minus_300_m_s", ...
                "delta_median_q_600_minus_300", ...
                "mape_300_percent","mape_600_percent"]);
        end
    end
end
D=vertcat(entries{1:n});
end
