function tests=test_reqml_frequency_swsynth_configuration
% No simulation is executed; validates all 20 JSONs and paired geometry.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
study=fullfile(fileparts(fileparts(mfilename("fullpath"))), ...
    "studies","reqml_frequency_bias_swsynth");
addpath(study,"-begin");
sim="/Users/sara/local/shear-wave-simulation-framework";
assumeTrue(testCase,isfile(fullfile(sim,"run_simulation.m")), ...
    "Simulation framework checkout unavailable.");
testCase.TestData.simRoot=sim;
testCase.TestData.outputRoot=string(tempname);
end

function teardownOnce(testCase)
if isfield(testCase.TestData,"outputRoot") && ...
        isfolder(testCase.TestData.outputRoot)
    rmdir(testCase.TestData.outputRoot,"s");
end
end

function testCaseCountsAndGrid(testCase)
T=prepare_swsynth_frequency_study( ...
    OutputRoot=testCase.TestData.outputRoot,WriteConfigs=true);
verifyEqual(testCase,height(T),20);
verifyEqual(testCase,nnz(T.group=="plane_homogeneous"),8);
verifyEqual(testCase,nnz(T.group=="plane_bilayer"),4);
verifyEqual(testCase,nnz(T.group=="point_homogeneous"),8);
for i=1:height(T)
    C=jsondecode(fileread(T.config_file(i)));
    verifyEqual(testCase,C.domain.Lx_m,0.05);
    verifyEqual(testCase,C.domain.Lz_m,0.05);
    verifyEqual(testCase,C.domain.dx_m,0.0002);
    verifyEqual(testCase,C.domain.dz_m,0.0002);
    verifyEqual(testCase,C.geometry,"projected3d");
    verifyEqual(testCase,C.measurement.axis_xyz(:).',[0 0 1]);
end
% Running this builder again must be idempotent.
T2=prepare_swsynth_frequency_study( ...
    OutputRoot=testCase.TestData.outputRoot,WriteConfigs=true);
verifyEqual(testCase,T2.config_file,T.config_file);
end

function testPairedPlaneWavesAndLayerTruth(testCase)
T=prepare_swsynth_frequency_study( ...
    OutputRoot=testCase.TestData.outputRoot,WriteConfigs=true);
addpath(fullfile(testCase.TestData.simRoot,"src"),"-begin");
for f=[300 400 500 600]
    idxHom=find(T.group=="plane_homogeneous" & ...
        T.reference_cs_m_s==1.8 & T.frequency_hz==f);
    idxBil=find(T.group=="plane_bilayer" & T.frequency_hz==f);
    A=jsondecode(fileread(T.config_file(idxHom)));
    B=jsondecode(fileread(T.config_file(idxBil)));
    verifyEqual(testCase,A.incidence,B.incidence);
    verifyEqual(testCase,A.domain,B.domain);
    verifyEqual(testCase,A.harmonic,B.harmonic);
    verifyEqual(testCase,B.propagation.phase_method,"eikonal");
    g=swsynth.domain.buildGrid( ...
        struct("geometry","projected3d","Lx_m",0.05,"Lz_m",0.05, ...
        "dx_m",0.0002,"dz_m",0.0002,"observation_y_m",0));
    maps=swsynth.medium.buildMaps(g,B.medium);
    verifyEqual(testCase,unique(maps.cs_map_zx),[1.8;3.0],"AbsTol",1e-12);
    verifyEqual(testCase,maps.cs_map_zx(1,1),1.8,"AbsTol",1e-12);
    verifyEqual(testCase,maps.cs_map_zx(end,1),3,"AbsTol",1e-12);
end
end

function testDiskPointLocations(testCase)
T=prepare_swsynth_frequency_study( ...
    OutputRoot=testCase.TestData.outputRoot,WriteConfigs=true);
for i=find(T.group=="point_homogeneous").'
    C=jsondecode(fileread(T.config_file(i)));
    points=double(C.sources.positions.position_xyz_m);
    verifyEqual(testCase,size(points),[26 3]);
    verifyEqual(testCase,unique(points(:,1)),[-0.008;0.058],"AbsTol",1e-12);
    verifyEqual(testCase,nnz(abs(points(:,1)+0.008)<1e-12),13);
    verifyEqual(testCase,nnz(abs(points(:,1)-0.058)<1e-12),13);
    verifyLessThanOrEqual(testCase,max(hypot(points(:,2),points(:,3)-0.025)), ...
        0.003+1e-12);
    verifyEqual(testCase,C.sources.excitation.force_direction_xyz(:).',[1 0 0]);
    verifyEqual(testCase,double(C.sources.excitation.phase_rad(:)),zeros(26,1));
end
end

function testAllConfigsDryRun(testCase)
T=prepare_swsynth_frequency_study( ...
    OutputRoot=testCase.TestData.outputRoot,WriteConfigs=true);
addpath(testCase.TestData.simRoot,"-begin");
addpath(fullfile(testCase.TestData.simRoot,"src"),"-begin");
for i=1:height(T)
    dry=run_simulation(T.config_file(i),DryRun=true, ...
        OutputRoot=fullfile(testCase.TestData.outputRoot,"dryrun"), ...
        PlotFigures=false);
    verifyEqual(testCase,string(dry.status),"dry_run_valid");
end
end
