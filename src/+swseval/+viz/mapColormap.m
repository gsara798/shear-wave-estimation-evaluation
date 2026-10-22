function cmap=mapColormap(n)
%MAPCOLORMAP REQ-ML SWS palette: blue, teal, green-light, orange-light, red.
arguments
 n (1,1) double {mustBeInteger,mustBePositive}=256
end
anchor=["#4834D4","#22A6B3","#BADC58","#FFBE76","#EB4D4B"];
rgb=zeros(numel(anchor),3);
for i=1:numel(anchor)
 rgb(i,:)=double(sscanf(char(erase(anchor(i),'#')),'%2x%2x%2x')')/255;
end
cmap=interp1(linspace(0,1,5),rgb,linspace(0,1,n),'pchip');
cmap=min(1,max(0,cmap));
end
