function build_models
%BUILD_MODELS 创建三套单相半波可控整流 Simulink 模型。
% 本脚本只搭建并保存模型，不执行仿真。

rootDir = fileparts(mfilename('fullpath'));
oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir)); %#ok<NASGU>
cd(rootDir);

load_system('simulink');
load_system('powerlib');

create_one('half_wave_R', 'R', false, rootDir);
create_one('half_wave_RL', 'RL', false, rootDir);
create_one('half_wave_RL_freewheel', 'RL', true, rootDir);

fprintf('三套模型已保存到：%s\n', rootDir);
end

function create_one(mdl, branchType, withFreewheel, rootDir)
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
new_system(mdl);

set_param(mdl, ...
    'StopTime', '0.1', ...
    'SolverType', 'Variable-step', ...
    'Solver', 'ode23tb', ...
    'MaxStep', '1e-5', ...
    'ReturnWorkspaceOutputs', 'on');

mw = get_param(mdl, 'ModelWorkspace');
assignin(mw, 'U2_rms', 220);
assignin(mw, 'freq_hz', 50);
assignin(mw, 'R_load', 50);
assignin(mw, 'L_load', 0.5);
assignin(mw, 'alpha_deg', 30);

add_block('powerlib/powergui', [mdl '/powergui'], ...
    'Position', [35 25 115 60]);
set_param([mdl '/powergui'], 'SimulationMode', 'Continuous');

add_block('powerlib/Electrical Sources/AC Voltage Source', ...
    [mdl '/AC Source 220V 50Hz'], ...
    'Position', [80 175 145 255], 'Orientation', 'down');
set_param([mdl '/AC Source 220V 50Hz'], ...
    'Amplitude', 'sqrt(2)*U2_rms', ...
    'Frequency', 'freq_hz', ...
    'Phase', '0');

add_block('powerlib/Power Electronics/Thyristor', [mdl '/Thyristor VT'], ...
    'Position', [220 105 295 165]);

add_block('simulink/Sources/Pulse Generator', [mdl '/Gate Pulse'], ...
    'Position', [185 25 300 65]);
set_param([mdl '/Gate Pulse'], ...
    'Amplitude', '1', ...
    'Period', '1/freq_hz', ...
    'PulseWidth', '5', ...
    'PhaseDelay', 'alpha_deg/360/freq_hz', ...
    'SampleTime', '0');

add_block('powerlib/Measurements/Current Measurement', [mdl '/Current id'], ...
    'Position', [345 110 405 160]);

add_block('powerlib/Elements/Series RLC Branch', [mdl '/Load'], ...
    'Position', [485 170 550 255], 'Orientation', 'down');
if strcmp(branchType, 'R')
    set_param([mdl '/Load'], ...
        'BranchType', 'R', ...
        'Resistance', 'R_load');
else
    set_param([mdl '/Load'], ...
        'BranchType', 'RL', ...
        'Resistance', 'R_load', ...
        'Inductance', 'L_load', ...
        'SetiL0', 'on', ...
        'InitialCurrent', '0');
end

if withFreewheel
    add_block('powerlib/Power Electronics/Diode', [mdl '/Freewheel Diode VD'], ...
        'Position', [620 175 690 235], 'Orientation', 'left');
end

add_block('powerlib/Measurements/Voltage Measurement', [mdl '/Voltage u2'], ...
    'Position', [75 325 145 370]);
add_block('powerlib/Measurements/Voltage Measurement', [mdl '/Voltage ud'], ...
    'Position', [475 325 545 370]);
add_block('powerlib/Measurements/Voltage Measurement', [mdl '/Voltage uT'], ...
    'Position', [235 325 305 370]);

src = get_param([mdl '/AC Source 220V 50Hz'], 'PortHandles');
vt  = get_param([mdl '/Thyristor VT'], 'PortHandles');
cur = get_param([mdl '/Current id'], 'PortHandles');
loadp = get_param([mdl '/Load'], 'PortHandles');
vu2 = get_param([mdl '/Voltage u2'], 'PortHandles');
vud = get_param([mdl '/Voltage ud'], 'PortHandles');
vut = get_param([mdl '/Voltage uT'], 'PortHandles');
pulse = get_param([mdl '/Gate Pulse'], 'PortHandles');

add_line(mdl, src.LConn(1), vt.LConn(1), 'autorouting', 'on');
add_line(mdl, vt.RConn(1), cur.LConn(1), 'autorouting', 'on');
add_line(mdl, cur.RConn(1), loadp.LConn(1), 'autorouting', 'on');
add_line(mdl, loadp.RConn(1), src.RConn(1), 'autorouting', 'on');
add_line(mdl, pulse.Outport(1), vt.Inport(1), 'autorouting', 'on');

connect_sensor(mdl, vu2, src.LConn(1), src.RConn(1));
connect_sensor(mdl, vud, loadp.LConn(1), loadp.RConn(1));
connect_sensor(mdl, vut, vt.LConn(1), vt.RConn(1));

if withFreewheel
    diode = get_param([mdl '/Freewheel Diode VD'], 'PortHandles');
    % 二极管阳极接负载下端，阴极接负载上端。
    add_line(mdl, loadp.RConn(1), diode.LConn(1), 'autorouting', 'on');
    add_line(mdl, diode.RConn(1), loadp.LConn(1), 'autorouting', 'on');
    if ~isempty(diode.Outport)
        add_block('simulink/Sinks/Terminator', [mdl '/VD measurement terminator'], ...
            'Position', [725 230 745 250]);
        add_line(mdl, diode.Outport(1), ...
            get_param([mdl '/VD measurement terminator'], 'PortHandles').Inport(1));
    end
end

if ~isempty(vt.Outport)
    add_block('simulink/Sinks/Terminator', [mdl '/VT measurement terminator'], ...
        'Position', [315 175 335 195]);
    term = get_param([mdl '/VT measurement terminator'], 'PortHandles');
    add_line(mdl, vt.Outport(1), term.Inport(1), 'autorouting', 'on');
end

add_outputs(mdl, vu2.Outport(1), vud.Outport(1), cur.Outport(1), vut.Outport(1));
add_running_average(mdl, vud.Outport(1));

if strcmp(branchType, 'R')
    label = '电阻负载 R=50 Ohm';
elseif withFreewheel
    label = '阻感负载 R=50 Ohm, L=0.5 H，带续流二极管';
else
    label = '阻感负载 R=50 Ohm, L=0.5 H，无续流二极管';
end
description = Simulink.Annotation(mdl, label);
description.Position = [355 25 640 55];

Simulink.BlockDiagram.arrangeSystem(mdl, 'FullLayout', 'true');
set_param(mdl, 'ZoomFactor', 'FitSystem');
save_system(mdl, fullfile(rootDir, [mdl '.slx']));
close_system(mdl, 0);
end

function connect_sensor(mdl, sensorPorts, plusPort, minusPort)
add_line(mdl, plusPort, sensorPorts.LConn(1), 'autorouting', 'on');
add_line(mdl, minusPort, sensorPorts.LConn(2), 'autorouting', 'on');
end

function add_outputs(mdl, u2Port, udPort, idPort, uTPort)
signals = { ...
    'u2', u2Port, [775 80 855 105]; ...
    'ud', udPort, [775 125 855 150]; ...
    'id', idPort, [775 170 855 195]; ...
    'uT', uTPort, [775 215 855 240]};

add_block('simulink/Sinks/Scope', [mdl '/Scope 4 waveforms'], ...
    'Position', [930 105 990 225]);
set_param([mdl '/Scope 4 waveforms'], 'NumInputPorts', '4');
scopePorts = get_param([mdl '/Scope 4 waveforms'], 'PortHandles');

for k = 1:size(signals, 1)
    sigName = signals{k, 1};
    sigPort = signals{k, 2};
    pos = signals{k, 3};
    toName = ['To Workspace ' sigName];
    add_block('simulink/Sinks/To Workspace', [mdl '/' toName], ...
        'Position', pos);
    set_param([mdl '/' toName], ...
        'VariableName', sigName, ...
        'SaveFormat', 'Timeseries', ...
        'MaxDataPoints', 'inf');
    toPort = get_param([mdl '/' toName], 'PortHandles');
    lineH = add_line(mdl, sigPort, toPort.Inport(1), 'autorouting', 'on');
    set_param(lineH, 'Name', sigName);
    add_line(mdl, sigPort, scopePorts.Inport(k), 'autorouting', 'on');
end
end

function add_running_average(mdl, udPort)
add_block('simulink/Continuous/Integrator', [mdl '/Integral ud'], ...
    'Position', [770 300 805 330]);
add_block('simulink/Sources/Clock', [mdl '/Clock'], ...
    'Position', [770 350 805 380]);
add_block('simulink/Math Operations/Bias', [mdl '/Avoid division by zero'], ...
    'Position', [835 350 890 380]);
set_param([mdl '/Avoid division by zero'], 'Bias', '1e-12');
add_block('simulink/Math Operations/Divide', [mdl '/Running mean'], ...
    'Position', [925 305 965 365]);
add_block('simulink/Sinks/Display', [mdl '/Ud running mean display'], ...
    'Position', [1010 315 1110 355]);

intP = get_param([mdl '/Integral ud'], 'PortHandles');
clkP = get_param([mdl '/Clock'], 'PortHandles');
biasP = get_param([mdl '/Avoid division by zero'], 'PortHandles');
divP = get_param([mdl '/Running mean'], 'PortHandles');
dispP = get_param([mdl '/Ud running mean display'], 'PortHandles');

add_line(mdl, udPort, intP.Inport(1), 'autorouting', 'on');
add_line(mdl, intP.Outport(1), divP.Inport(1), 'autorouting', 'on');
add_line(mdl, clkP.Outport(1), biasP.Inport(1), 'autorouting', 'on');
add_line(mdl, biasP.Outport(1), divP.Inport(2), 'autorouting', 'on');
add_line(mdl, divP.Outport(1), dispP.Inport(1), 'autorouting', 'on');
end
