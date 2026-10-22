function theme=figureTheme()
%FIGURETHEME Backward-compatible view over the canonical simulation template.
base=swseval.viz.paperTheme();
theme=base;
theme.font=base.style.font_name;
theme.font_size_pt=base.style.font_size_pt;
theme.line_width=base.style.line_width;
theme.resolution_dpi=base.figure.resolution_dpi;
theme.roi_colors=[base.rgb.blue.main; base.rgb.red.main; ...
 base.rgb.green.main; base.rgb.purple.main; ...
 base.rgb.teal.main; base.rgb.orange.main];
end
