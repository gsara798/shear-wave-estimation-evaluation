function labels=swsynth_short_model_names(names)
%SWSYNTH_SHORT_MODEL_NAMES Compact, stable plot aliases for frozen arms.
% Labels are presentation-only; model IDs and saved analysis retain originals.
names=string(names);
labels=names;
for i=1:numel(names)
    switch names(i)
        case "reduced14"
            labels(i)="R14 raw";
        case "reduced14_filtered"
            labels(i)="R14 donut";
        case "qmv2_unfiltered_reduced14"
            labels(i)="Q14 raw";
        case "qmv2_unfiltered_reduced14_frequency"
            labels(i)="Q14+f raw";
        case "qmv2_unfiltered_expanded20"
            labels(i)="Q20 raw";
        case "qmv2_unfiltered_expanded20_frequency"
            labels(i)="Q20+f raw";
        case "qmv2_fixed_donut_reduced14"
            labels(i)="Q14 donut";
        case "qmv2_fixed_donut_reduced14_frequency"
            labels(i)="Q14+f donut";
        case "qmv2_fixed_donut_expanded20"
            labels(i)="Q20 donut";
        case "qmv2_fixed_donut_expanded20_frequency"
            labels(i)="Q20+f donut";
    end
end
end
