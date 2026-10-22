function [selected,extent]=mask(roi,map)
%MASK Pixel-center membership in rectangular ROI, in mm or map pixels.
arguments
 roi (1,1) struct
 map (1,1) struct
end
assert(string(roi.shape)=="rectangle",'swseval:UnsupportedROI');
[nz,nx]=size(map.cs_map);
if string(roi.units)=="mm"
 xx=double(map.x_mm(:)');zz=double(map.z_mm(:));
else
 xx=1:nx;zz=(1:nz)';
end
xmin=roi.center(1)-roi.size(1)/2; xmax=roi.center(1)+roi.size(1)/2;
zmin=roi.center(2)-roi.size(2)/2; zmax=roi.center(2)+roi.size(2)/2;
selected=(zz>=zmin & zz<=zmax) & (xx>=xmin & xx<=xmax);
extent=[xmin xmax zmin zmax];
end
