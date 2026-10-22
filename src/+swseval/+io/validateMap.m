function map=validateMap(map)
%VALIDATEMAP Validate map contract independent of estimator.
arguments
 map (1,1) struct
end
for key=["cs_map","x_mm","z_mm","valid_mask"]
 assert(isfield(map,key),'swseval:InvalidMap','Missing field %s',key);
end
A=map.cs_map;
assert(isnumeric(A)&&ismatrix(A)&&~isempty(A),'swseval:InvalidMap');
x=double(map.x_mm(:));z=double(map.z_mm(:));
assert(all(isfinite(x))&&all(isfinite(z))&&all(diff(x)>0)&&all(diff(z)>0), ...
 'swseval:InvalidMap','Physical axes must be finite and strictly increasing');
assert(isequal(size(A),[numel(z),numel(x)]) && ...
 isequal(size(map.valid_mask),size(A)),'swseval:InvalidMap','Axes/mask dimensions mismatch');
map.x_mm=x';map.z_mm=z;
map.valid_mask=logical(map.valid_mask)&isfinite(A)&A>0;
if ~isfield(map,'metadata'),map.metadata=struct();end
end
