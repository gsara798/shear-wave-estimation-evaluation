function tests=test_reqml_bilayer_configuration
% Configuration-only regression test. No k-Wave solver is executed.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
studyDir=fullfile(fileparts(fileparts(mfilename("fullpath"))), ...
    "studies","reqml_frequency_bias_kwave");
addpath(studyDir,"-begin");
simRoot="/Users/sara/local/shear-wave-simulation-framework";
template=fullfile(simRoot,"examples","kwave","3d","opposed_x_disks","config.json");
assumeTrue(testCase,isfile(template), ...
    "Custom develop/v2 simulation framework not available.");
testCase.TestData.simRoot=simRoot;
testCase.TestData.outputRoot=string(tempname);
end

function teardownOnce(testCase)
if isfield(testCase.TestData,"outputRoot") && ...
        isfolder(testCase.TestData.outputRoot)
    rmdir(testCase.TestData.outputRoot,"s");
end
end

function testReadOnlyPlan(testCase)
root=testCase.TestData.outputRoot;
T=prepare_bilayer_pilot(SimulationRoot=testCase.TestData.simRoot, ...
    OutputRoot=root,GridSpacingM=0.0005,WriteConfigs=false);
verifyEqual(testCase,height(T),4);
verifyEqual(testCase,T.frequency_hz,[300;400;500;600]);
verifyFalse(testCase,isfolder(root));
end

function testExactActuatorCloneAndSeparatePaths(testCase)
root=testCase.TestData.outputRoot;
sim=testCase.TestData.simRoot;
T=prepare_bilayer_pilot(SimulationRoot=sim,OutputRoot=root, ...
    GridSpacingM=0.0005,InterfaceZM=0,WriteConfigs=true);
H=prepare_homogeneous_pilot(SimulationRoot=sim,OutputRoot=root, ...
    GridSpacingM=0.0005,WriteConfigs=false);
fields=["disk_radius_m","source_plane_inset_m", ...
    "source_node_spacing_points","source_velocity_amplitude_m_s", ...
    "source_relative_phase_rad","source_polarization_xyz", ...
    "grid_spacing_m","domain_size_m_xyz","roi_size_m_xz", ...
    "frequency_hz","density_kg_m3","compressional_speed_factor", ...
    "cfl","settling_cycles","analysis_cycles","pml_size_points"];
for i=1:height(T)
    f=T.frequency_hz(i);
    j=find(H.cs_m_s==1.8 & H.frequency_hz==f);
    verifyEqual(testCase,numel(j),1);
    original=jsondecode(fileread(H.config_file(j)));
    bilayer=jsondecode(fileread(T.config_file(i)));
    for field=fields
        verifyEqual(testCase,bilayer.(field),original.(field), ...
            "Actuator or observation parameter changed: "+field);
    end
    verifyEqual(testCase,string(bilayer.experiment), ...
        "opposed_x_disks_bilayer_3d");
    verifyTrue(testCase,logical(bilayer.bilayer.enabled));
    verifyEqual(testCase,double(bilayer.bilayer.interface_z_m),0);
    verifyEqual(testCase,double(bilayer.bilayer.negative_z_cs_m_s),1.8);
    verifyEqual(testCase,double(bilayer.bilayer.positive_z_cs_m_s),3.0);
    verifyTrue(testCase,contains(T.config_file(i),"bilayer"));
    verifyFalse(testCase,strcmp(T.run_file(i),H.run_file(j)));
end
% Repeated preparation must validate, never overwrite, the same JSONs.
again=prepare_bilayer_pilot(SimulationRoot=sim,OutputRoot=root, ...
    GridSpacingM=0.0005,InterfaceZM=0,WriteConfigs=true);
verifyEqual(testCase,again.config_file,T.config_file);
end

function testRunnerIsGuarded(testCase)
out=run_one_bilayer_case( ...
    SimulationRoot=testCase.TestData.simRoot, ...
    OutputRoot=testCase.TestData.outputRoot, ...
    GridSpacingM=0.0005,Execute=false);
verifyEqual(testCase,string(out.status),"planned");
verifyFalse(testCase,isfile(out.run_file));
end
