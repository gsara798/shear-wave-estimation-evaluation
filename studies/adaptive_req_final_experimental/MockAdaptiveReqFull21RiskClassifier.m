classdef MockAdaptiveReqFull21RiskClassifier
%MOCKADAPTIVEREQFULL21RISKCLASSIFIER Lightweight TEST DOUBLE, never deployed.
% Implements just the predict/ClassNames interface used by stage-03 scoring.
% Deliberately avoids fitctree, training, licenses and model files.
%
% For synthetic tests only: the risk score is the 22nd feature (saved
% Full21 predicted q). This is NOT a model of physical SWS error.
    properties (SetAccess=private)
        ClassNames = [0;1]
    end
    methods
        function [labels,scores]=predict(~,X)
            assert(isnumeric(X) && ismatrix(X) && size(X,2)==22 && ...
                all(isfinite(X),"all"), ...
                "AdaptiveREQ:MockClassifierInputs", ...
                "Synthetic fixture needs finite 22-column features.");
            positive=double(X(:,22));
            assert(all(positive>=0 & positive<=1), ...
                "AdaptiveREQ:MockClassifierScores", ...
                "Synthetic risk scores must be in [0,1].");
            scores=[1-positive,positive];
            labels=double(positive>=.5);
        end
    end
end
