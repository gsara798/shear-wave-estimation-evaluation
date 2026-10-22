function tests=test_roi_statistics
tests=functiontests(localfunctions);
end
function testRectanglesAndCoverage(testCase)
map=struct('cs_map',[2 3 4;2 3 4;2 3 4], ...
 'x_mm',[0 1 2],'z_mm',[0;1;2],'valid_mask',true(3));
roi=swseval.roi.rectangle("C",Center=[1 1],Size=[1 1],Units="mm");
T=swseval.metrics.roiStatistics(map,roi);
verifyEqual(testCase,T.valid_pixels,1);
verifyEqual(testCase,T.median_sws,3);
roi2=swseval.roi.rectangle("all",Center=[2 2],Size=[4 4],Units="pixel");
T2=swseval.metrics.roiStatistics(map,roi2);
verifyEqual(testCase,T2.selected_pixels,9);
end
