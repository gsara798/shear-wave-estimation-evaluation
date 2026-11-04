function out=run_signal_quality_study(options)
%RUN_SIGNAL_QUALITY_STUDY Reuse saved REQ-ML/EWP MATs; no processing/inference.
% Run from MATLAB: addpath('studies/reqml_signal_quality');
%                  run_signal_quality_study();
arguments
    options.DataRoot (1,1) string = ...
        "/Users/sara/local/experimental-data-reorganized/2026-02-27"
    options.Experiments (1,:) string = ...
        ["2026Feb27_homo_5perc_rswe","2026Feb27_homo_5perc_sp"]
    options.Frequencies (1,:) double {mustBePositive} = [300 400 500 600]
    options.EstimationRun (1,1) string = "reqml_sp_compare_m2_0p8_8_v1"
    options.Arm (1,1) string = "reduced14_filtered"
    options.M (1,1) double {mustBePositive} = 2
    options.QualityRun (1,1) string = "quality_hotspot_check"
    options.OutputRun (1,1) string = "signal_quality_reduced14_v1"
    options.ROIs (1,:) struct = ...
        swseval.roi.rectangle("central",Center=[19 19.25], ...
            Size=[17 15],Units="mm")
    options.WindowWidthMM (1,1) double {mustBeNonnegative} = 0
    options.HighTailPercentile (1,1) double = 90
    options.R2Threshold (1,1) double = 0.98
    options.RatioThreshold (1,1) double = 10
    options.ContinueOnMissing (1,1) logical = true
    options.ExportFigures (1,1) logical = true
end

root=string(fileparts(mfilename("fullpath")));
evalSrc=fullfile(root,"..","..","src");
if isempty(which("swseval.signalquality.loadAndAlign"))
    addpath(evalSrc);
end
summaryRows=table();metricRows=table();gateRows=table();
missing=strings(0,1);
for experiment=options.Experiments
    experimentRoot=fullfile(options.DataRoot,experiment);
    for frequency=options.Frequencies
        stem=sprintf("test1_%gHz",frequency);
        estimateFile=fullfile(experimentRoot,"estimates",options.EstimationRun, ...
            "REQ-ML",options.Arm,sprintf("%gHz",frequency), ...
            "M"+string(options.M),"reqml_result.mat");
        diagnosis=fullfile(experimentRoot,"analysis",options.QualityRun);
        iqFile=fullfile(diagnosis,"iq_quality",stem,"iq_quality.mat");
        temporalFile=fullfile(diagnosis,"displacement_quality",stem, ...
            "temporal_consistency.mat");
        files=[estimateFile iqFile temporalFile];
        present=isfile(files);
        if ~all(present)
            absent=files(~present);
            for file=absent
                missing(end+1,1)=string(file); %#ok<AGROW>
            end
            if options.ContinueOnMissing
                warning("swseval:SignalQualityMissing", ...
                    "Skipping %s %g Hz. Missing:\n%s",experiment,frequency, ...
                    strjoin(absent,newline));
                continue
            end
            error("swseval:SignalQualityMissing", ...
                "Missing input MAT(s) for %s %g Hz:\n%s",experiment,frequency, ...
                strjoin(absent,newline));
        end

        D=swseval.signalquality.loadAndAlign(estimateFile,temporalFile,iqFile, ...
            WindowWidthMM=options.WindowWidthMM);
        for roi=options.ROIs
            A=swseval.signalquality.analyze(D,roi, ...
                HighTailPercentile=options.HighTailPercentile, ...
                R2Threshold=options.R2Threshold,RatioThreshold=options.RatioThreshold);
            analysisDir=fullfile(experimentRoot,"analysis",options.OutputRun, ...
                sprintf("%gHz",frequency),"M"+string(options.M),options.Arm, ...
                string(roi.name));
            if ~isfolder(analysisDir),mkdir(analysisDir);end
            summary=A.summary;metrics=A.metrics;gates=A.gates; %#ok<NASGU>
            provenance=struct("estimate_file",estimateFile, ...
                "temporal_file",temporalFile,"iq_file",iqFile); %#ok<NASGU>
            save(fullfile(analysisDir,"quality_association.mat"), ...
                "summary","metrics","gates","provenance");
            writetable(A.metrics,fullfile(analysisDir,"metric_associations.csv"));
            writetable(A.gates,fullfile(analysisDir,"exploratory_gates.csv"));
            if options.ExportFigures
                fig=swseval.signalquality.plotComparison(D,A);
                swseval.viz.exportFigure(fig,fullfile(analysisDir,"hotspot_quality"), ...
                    ["png","pdf"]);
                close(fig);
            end
            % Set column names explicitly: expressions such as
            % string(roi.name) can otherwise create automatic VarN names,
            % which may collide when horizontally concatenating tables.
            prefix=table();
            prefix.experiment=string(experiment);
            prefix.frequency_hz=double(frequency);
            prefix.roi=string(roi.name);
            prefix.arm=string(options.Arm);
            prefix.M=double(options.M);
            row=prefix;
            row.valid_count=A.summary.valid_count;
            row.high_count=A.summary.high_count;
            row.median_sws_m_s=A.summary.median_sws_m_s;
            row.high_threshold_m_s=A.summary.high_threshold_m_s;
            row.window_width_mm=A.summary.window_width_mm;
            metricRow=[repmat(prefix,height(A.metrics),1), A.metrics];
            gateRow=[repmat(prefix,height(A.gates),1), A.gates];
            if isempty(summaryRows)
                summaryRows=row;
                metricRows=metricRow;
                gateRows=gateRow;
            else
                summaryRows=[summaryRows;row]; %#ok<AGROW>
                metricRows=[metricRows;metricRow]; %#ok<AGROW>
                gateRows=[gateRows;gateRow]; %#ok<AGROW>
            end
            fprintf("[%s %g Hz | %s] %d valid, %d upper-tail pixels\n", ...
                experiment,frequency,roi.name,A.summary.valid_count, ...
                A.summary.high_count);
        end
    end
end

outputRoot=fullfile(options.DataRoot,options.OutputRun);
if ~isfolder(outputRoot),mkdir(outputRoot);end
if ~isempty(summaryRows)
    writetable(summaryRows,fullfile(outputRoot,"summary_all.csv"));
    writetable(metricRows,fullfile(outputRoot,"metric_associations_all.csv"));
    writetable(gateRows,fullfile(outputRoot,"exploratory_gates_all.csv"));
end
if ~isempty(missing)
    missing=unique(missing,"stable");
    writelines(missing,fullfile(outputRoot,"missing_inputs.txt"));
end
out=struct("summary",summaryRows,"metrics",metricRows,"gates",gateRows, ...
    "missing",missing,"output_root",outputRoot);
end
