function roi=rectangle(name,options)
%RECTANGLE Reproducible rectangle in physical mm or map pixel coordinates.
arguments
 name (1,1) string
 options.Center (1,2) double = [NaN NaN]
 options.Size (1,2) double = [NaN NaN]
 options.Units (1,1) string {mustBeMember(options.Units,["mm","pixel","pixels"])}="mm"
end
assert(strlength(name)>0 && all(isfinite(options.Center)) && ...
 all(isfinite(options.Size)) && all(options.Size>0), ...
 'swseval:InvalidROI','ROI name/center/size invalid');
roi=struct('name',name,'shape',"rectangle",'center',options.Center, ...
 'size',options.Size,'units',replace(options.Units,"pixels","pixel"));
end
