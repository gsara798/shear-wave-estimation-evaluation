# Shared figure template

Mirrors `REQ-ML/src/+reqml/+viz/figureTheme.m` and `mapColormap.m`:

- Typography: Times New Roman, 9 pt; line width 1.5, axes 0.8.
- Map colors (SWS): `#4834D4` → `#22A6B3` → `#BADC58` → `#FFBE76` → `#EB4D4B`, pchip-interpolated.
- ROI annotation colors: blue, orange, green, red, teal, purple (from matching theme).
- Export: PNG/TIFF 300 DPI; PDF vector.
- Color limits should be fixed across comparable maps.

This package includes its own small theme functions intentionally so estimator-independent analysis does not require REQ-ML on MATLAB path.
