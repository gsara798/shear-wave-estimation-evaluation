%% Adaptive REQ-ML: stage 01 - experimental IQ -> harmonic wavefields
% Run this SCRIPT from any MATLAB working directory.
% Eight experiments: homogeneous 5/10%, bilayer, inclusion; SP and RSWE.
% EWP does the processing; this script only coordinates datasets and figures.
%
% Processing: no spatial filter, no SVD removal, temporal FIR +/-20 Hz,
% harmonic lock-in (12 cycles), isotropic sampling. No movies.
% Figures are rendered from wavefield_sample.mat after processing so EWP
% does not retain large temporal intermediate.mat solely for plotting.
%
% Set PreviewOnly=true to inspect data availability without processing.
% Set SelectedCaseIDs to a subset to pilot one or two cases.

%% Editable settings
DataRoot = "/Users/sara/local/experimental-data-reorganized";
EwpRoot = "/Users/sara/local/experimental-wavefield-processing";
RunName = "adaptive_req_final_unfiltered_v1";
RequestedFrequenciesHz = [300 400 500 600];
SelectedCaseIDs = strings(1,0);    % empty = all eight cases
PreviewOnly = false;
UseParallel = true;
FigureFormats = ["png","pdf","fig"];

%% Experiment inventory (fixed dates/IDs from the acquisition folders)
caseIDs = [
    "2026Feb27_homo_10perc_sp"
    "2026Feb27_homo_10perc_rswe"
    "2026Feb27_homo_5perc_sp"
    "2026Feb27_homo_5perc_rswe"
    "2026Feb27_dl_sp"
    "2026Feb27_dl_rswe"
    "2026Feb19_inc_sp"
    "2026Feb19_inc_rswe"
];
caseDates = [
    repmat("2026-02-27",6,1)
    repmat("2026-02-19",2,1)
];
% The Feb-19 file pattern was not documented. Detect it from raw filenames.
% Set a particular entry here if there is more than one valid pattern.
filePatterns = [
    repmat("test1_{frequency}Hz.mat",6,1)
    ""
    ""
];

%% Setup and safeguards
assert(isfolder(DataRoot), "Data root does not exist: %s",DataRoot);
assert(isfile(fullfile(EwpRoot,"src","+ewp","runFrequencySweep.m")), ...
    "Cannot find EWP. Check EwpRoot: %s",EwpRoot);
addpath(fullfile(EwpRoot,"src"),"-begin");
assert(~isempty(which("ewp.runFrequencySweep")), ...
    "ewp.runFrequencySweep is not on the MATLAB path.");
if ~PreviewOnly
    assert(~isempty(which("ewp.viz.renderWavefieldSample")) && ...
        ~isempty(which("ewp.viz.renderBmodeAcquisition")), ...
        "EWP plotting functions are missing; use the EWP branch with B-mode support.");
end

if isempty(SelectedCaseIDs)
    SelectedCaseIDs = caseIDs;
end
assert(all(ismember(SelectedCaseIDs,caseIDs)), ...
    "SelectedCaseIDs contains an unknown experiment ID.");
summaryRows = cell(0,5);

fprintf("\nAdaptive REQ-ML | experimental processing | %d datasets\n", ...
    numel(SelectedCaseIDs));
fprintf("Run: %s | No spatial filtering | SVD=0 | No movies\n",RunName);

%% One loop for all experiments
for ii = 1:numel(caseIDs)
    caseID = caseIDs(ii);
    if ~ismember(caseID,SelectedCaseIDs), continue; end

    experimentRoot = fullfile(DataRoot,caseDates(ii),caseID);
    rawRoot = fullfile(experimentRoot,"raw");
    fprintf("\n[%s]\n",caseID);

    try
        [pattern,frequencies] = localFindAcquisitions( ...
            rawRoot,filePatterns(ii),RequestedFrequenciesHz);
        fprintf("  IQ pattern : %s\n",pattern);
        fprintf("  Frequencies: %s Hz\n",strjoin(string(frequencies),", "));

        missingHz = setdiff(RequestedFrequenciesHz,frequencies);
        if ~isempty(missingHz)
            warning("AdaptiveREQ:MissingFrequencies", ...
                "%s: no matching IQ files at %s Hz; these will not be processed.", ...
                caseID,strjoin(string(missingHz),", "));
        end

        if PreviewOnly
            for frequency = frequencies
                sampleFile = fullfile(experimentRoot,"processed",RunName, ...
                    sprintf("%gHz",frequency),"wavefield_sample.mat");
                summaryRows(end+1,:) = {caseID,frequency,"preview_ready","",sampleFile}; %#ok<SAGROW>
            end
            continue
        end

        % The acquisition is processed only once, even if plots are missing.
        % Crucially SaveFigures=false avoids EWP's automatic intermediate.mat.
        R = ewp.runFrequencySweep( ...
            InputRoot=rawRoot, ...
            FilePattern=pattern, ...
            Frequencies=frequencies, ...
            RunName=RunName, ...
            SpatialFilterMode="none", ...
            DonutEnabled=false, ...
            RemoveSVDModes=0, ...
            TemporalHalfBandwidthHz=20, ...
            LockinCycles=12, ...
            MakeIsotropic=true, ...
            UseParallel=UseParallel, ...
            SaveIntermediate=false, ...
            SaveFigures=false, ...
            SaveMovies=false, ...
            Diagnostics=strings(1,0), ...
            Resume=true, ...
            ContinueOnError=true);

        for jj = 1:height(R.summary)
            frequency = double(R.summary.frequency_hz(jj));
            frequencyDir = fullfile(R.output_root,sprintf("%gHz",frequency));
            sampleFile = fullfile(frequencyDir,"wavefield_sample.mat");
            processStatus = string(R.summary.status(jj));
            message = string(R.summary.message(jj));
            status = processStatus;

            if ismember(processStatus,["completed","skipped_existing"]) && ...
                    isfile(sampleFile)
                try
                    % Generate maps/figures from the saved harmonic field.
                    % Neither measured nor reconstructed movies are produced.
                    ewp.viz.renderWavefieldSample( ...
                        sampleFile,frequencyDir, ...
                        FigureFormats=FigureFormats, ...
                        CreateSummaryPlot=true, ...
                        CreateHarmonicMovie=false, ...
                        CreateTemporalMovie=false, ...
                        MovieStages=strings(1,0), ...
                        Overwrite=false);
                    rawFile = fullfile(rawRoot, ...
                        replace(pattern,"{frequency}",sprintf("%g",frequency)));
                    ewp.viz.renderBmodeAcquisition( ...
                        rawFile,frequencyDir, ...
                        FigureFormats=FigureFormats,Overwrite=false);
                    status = "ready";
                    fprintf("  %g Hz: field and figures ready\n",frequency);
                catch MEplot
                    status = "figures_failed";
                    message = string(MEplot.message);
                    warning("AdaptiveREQ:FigureFailure", ...
                        "%s %g Hz: %s",caseID,frequency,MEplot.message);
                end
            else
                warning("AdaptiveREQ:ProcessingFailed", ...
                    "%s %g Hz: %s (%s)",caseID,frequency,processStatus,message);
            end
            summaryRows(end+1,:) = {caseID,frequency,status,message,sampleFile}; %#ok<SAGROW>
        end
    catch ME
        warning("AdaptiveREQ:CaseFailed", ...
            "%s: %s",caseID,ME.message);
        summaryRows(end+1,:) = {caseID,NaN,"case_failed", ...
            string(ME.message),""}; %#ok<SAGROW>
    end
end

%% Export a combined summary without changing per-experiment outputs
S = cell2table(summaryRows,VariableNames= ...
    ["case_id","frequency_hz","status","message","sample_file"]);
S.case_id = string(S.case_id);
S.status = string(S.status);
S.message = string(S.message);
S.sample_file = string(S.sample_file);
disp(S(:,["case_id","frequency_hz","status"]));

if ~PreviewOnly
    outputDir = fullfile(DataRoot,"analysis","adaptive_req_final_experimental_v1");
    if ~isfolder(outputDir), mkdir(outputDir); end
    summaryFile = fullfile(outputDir,"processing_summary.csv");
    writetable(S,summaryFile);
    fprintf("\nSummary: %s\n",summaryFile);
end

%% Local helpers
function [pattern,frequencies] = localFindAcquisitions(rawRoot,preferred,requested)
    assert(isfolder(rawRoot),"Missing raw directory: %s",rawRoot);
    files = dir(fullfile(rawRoot,"*.mat"));
    assert(~isempty(files),"No MAT files in %s",rawRoot);
    preferred = string(preferred);

    if strlength(preferred)>0
        assert(contains(preferred,"{frequency}"), ...
            "Expected {frequency} in file pattern: %s",preferred);
        pattern = preferred;
    else
        candidates = strings(0,1);
        % Only filenames with an explicitly identifiable 300-600 Hz token.
        for k = 1:numel(files)
            tokens = regexp(files(k).name, ...
                '^(.*?)(300|400|500|600)Hz(.*?)\.mat$',"tokens","once");
            if isempty(tokens), continue; end
            candidates(end+1,1) = string(tokens{1}) + ...
                "{frequency}Hz" + string(tokens{3}) + ".mat"; %#ok<AGROW>
        end
        candidates = unique(candidates);
        assert(~isempty(candidates), ...
            "No recognizable {frequency}Hz MAT filenames in %s; specify filePatterns.",rawRoot);
        assert(numel(candidates)==1, ...
            "Multiple acquisition patterns in %s: %s. Set filePatterns explicitly.", ...
            rawRoot,strjoin(candidates,", "));
        pattern = candidates(1);
    end

    frequencies = zeros(1,0);
    for f = requested
        filename = replace(pattern,"{frequency}",sprintf("%g",f));
        if isfile(fullfile(rawRoot,filename))
            frequencies(end+1) = f; %#ok<AGROW>
        end
    end
    assert(~isempty(frequencies), ...
        "No IQ files matched %s in %s",pattern,rawRoot);
end
