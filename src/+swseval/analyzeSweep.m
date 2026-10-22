function T=analyzeSweep(rois,options)
%ANALYZESWEEP Analyze REQ-ML results across frequency, model and window M.
% Expects: EstimatesRoot/REQ-ML/<model>/<frequency>Hz/M<M>/reqml_result.mat
arguments
 rois (1,:) struct
 options.EstimatesRoot (1,1) string
 options.Models (1,:) string = ["candidate","candidate10"]
 options.Frequencies (1,:) double = [300 400 500 600]
 options.MValues (1,:) double = [2 3]
 options.OutputDir (1,1) string = ""
 options.SWSColorLimits (1,:) double = []
 options.ContinueOnMissing (1,1) logical = false
 options.ExportMaps (1,1) logical = true
end
assert(~isempty(rois)&&numel(unique(string({rois.name})))==numel(rois), ...
 'swseval:DuplicateROI','ROI names must be unique');
assert(all(isfinite(options.Frequencies)&options.Frequencies>0));
assert(all(isfinite(options.MValues)&options.MValues>0));
if options.OutputDir==""
 out=fullfile(options.EstimatesRoot,"evaluation","roi_analysis");
else
 out=options.OutputDir;
end
if ~isfolder(out),mkdir(out);end
parts=cell(numel(options.Models)*numel(options.Frequencies)*numel(options.MValues),1);
n=0;missing=strings(0,1);
for model=options.Models
 for m=options.MValues
  for f=options.Frequencies
   sample=fullfile(options.EstimatesRoot,"REQ-ML",model, ...
     sprintf("%gHz",f),"M"+string(m),"reqml_result.mat");
   if ~isfile(sample)
    if options.ContinueOnMissing
     missing(end+1,1)=sample; %#ok<AGROW>
     warning("swseval:MissingEstimate","Missing %s",sample);
     continue
    end
    error("swseval:MissingEstimate","Missing estimate %s",sample);
   end
   map=swseval.io.loadReqmlResult(sample);
   if options.ExportMaps
    folder=fullfile(out,"maps",model,"M"+string(m),sprintf("%gHz",f));
    A=swseval.analyzeROIs(map,rois,OutputDir=folder, ...
      SWSColorLimits=options.SWSColorLimits);
   else
    A=swseval.metrics.roiStatistics(map,rois);
   end
   A.model=repmat(model,height(A),1);
   A.frequency_hz=repmat(f,height(A),1);
   A.M=repmat(m,height(A),1);
   A.source_file=repmat(sample,height(A),1);
   n=n+1;parts{n}=A;
   fprintf("Analyzed %s | %g Hz | M=%g | %d ROIs\n",model,f,m,height(A));
  end
 end
end
assert(n>0,"swseval:NoEstimates","No matching estimates found");
T=vertcat(parts{1:n});
T=movevars(T,["model","frequency_hz","M"],"Before",1);
writetable(T,fullfile(out,"roi_statistics_all.csv"));
save(fullfile(out,"roi_sweep.mat"),"T","rois","options","-v7.3");
if ~isempty(missing)
 fid=fopen(fullfile(out,"missing_files.txt"),"w");
 if fid>0
  clean=onCleanup(@()fclose(fid));fprintf(fid,"%s\n",missing);
 end
end
swseval.viz.plotROIFrequency(T, ...
 OutputDir=fullfile(out,"figures"));
fprintf("ROI sweep saved in %s\n",out);
end
