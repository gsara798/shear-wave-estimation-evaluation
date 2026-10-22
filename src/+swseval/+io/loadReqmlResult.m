function map=loadReqmlResult(file)
%LOADREQMLRESULT Load saved reqml_result/result from REQ-ML inference.
arguments
 file (1,1) string
end
assert(isfile(file),'swseval:MissingFile','Missing estimate file: %s',file);
s=load(file);
if isfield(s,'reqml_result'),map=s.reqml_result;
elseif isfield(s,'result'),map=s.result;
else,error('swseval:MissingResult','No reqml_result or result variable');end
map=swseval.io.validateMap(map);
map.metadata.estimator="REQ-ML";
map.metadata.source_file=file;
end
