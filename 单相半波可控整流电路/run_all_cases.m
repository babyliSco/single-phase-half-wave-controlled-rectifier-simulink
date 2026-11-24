%% 单相半波可控整流：三种负载、四个控制角批量仿真
% 运行前先执行 build_models（模型文件已存在时不必重复执行）。
% 本脚本仿真后自动保存波形 PNG、CSV 数据表和 Markdown 数据表。

clearvars;
clc;

rootDir = fileparts(mfilename('fullpath'));
resultDir = fullfile(rootDir, 'results');
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

modelInfo = { ...
    'half_wave_R',              '电阻负载',             'R'; ...
    'half_wave_RL',             '阻感负载_无续流',      'RL'; ...
    'half_wave_RL_freewheel',   '阻感负载_带续流二极管','RLF'};
angles = [30 60 90 120];

U2 = 220;
f = 50;
R = 50;
L = 0.5;
stopTime = 0.1;

rows = cell(size(modelInfo,1) * numel(angles), 7);
rowIndex = 0;

for m = 1:size(modelInfo, 1)
    mdl = modelInfo{m, 1};
    caseName = modelInfo{m, 2};
    caseType = modelInfo{m, 3};
    load_system(fullfile(rootDir, [mdl '.slx']));
    mw = get_param(mdl, 'ModelWorkspace');

    for a = angles
        assignin(mw, 'alpha_deg', a);
        simOut = sim(mdl, 'StopTime', num2str(stopTime), ...
            'ReturnWorkspaceOutputs', 'on');

        u2 = simOut.get('u2');
        ud = simOut.get('ud');
        id = simOut.get('id');
        uT = simOut.get('uT');

        lastCycleStart = stopTime - 1/f;
        keep = ud.Time >= lastCycleStart;
        udMean = trapz(ud.Time(keep), ud.Data(keep)) / (1/f);

        [theory, betaDeg] = theoretical_ud(caseType, U2, f, R, L, a);
        relError = abs(udMean - theory) / max(abs(theory), eps) * 100;

        rowIndex = rowIndex + 1;
        rows(rowIndex,:) = {caseName, a, theory, udMean, relError, betaDeg, ...
            sprintf('%s_alpha_%03d.png', caseType, a)};

        fig = figure('Visible', 'off', 'Color', 'w', ...
            'Position', [100 100 1200 850]);
        tiledlayout(4,1, 'TileSpacing','compact', 'Padding','compact');
        plot_one(nexttile, u2, 'u_2 / V', sprintf('%s，控制角 \\alpha=%d^\\circ', caseName, a));
        plot_one(nexttile, ud, 'u_d / V', '');
        plot_one(nexttile, id, 'i_d / A', '');
        plot_one(nexttile, uT, 'u_T / V', '');
        xlabel('t / s');
        exportgraphics(fig, fullfile(resultDir, rows{rowIndex,7}), 'Resolution', 180);
        close(fig);
    end
    close_system(mdl, 0);
end

resultTable = cell2table(rows, 'VariableNames', { ...
    'LoadCase','AlphaDeg','TheoryUd_V','SimulationUd_V', ...
    'RelativeError_pct','ExtinctionBetaDeg','WaveformFile'});
writetable(resultTable, fullfile(resultDir, '实验数据汇总.csv'));
write_markdown_tables(resultTable, fullfile(resultDir, '实验数据表.md'));

disp(resultTable);
fprintf('\n结果已保存到：%s\n', resultDir);

function plot_one(ax, ts, yLabel, ttl)
plot(ax, ts.Time, ts.Data, 'LineWidth', 1.0);
grid(ax, 'on');
ylabel(ax, yLabel);
xlim(ax, [0 ts.Time(end)]);
if ~isempty(ttl)
    title(ax, ttl, 'Interpreter', 'tex');
end
end

function [Ud, betaDeg] = theoretical_ud(caseType, U2, f, R, L, alphaDeg)
alpha = deg2rad(alphaDeg);
Vm = sqrt(2) * U2;
if strcmp(caseType, 'RL')
    omega = 2*pi*f;
    phi = atan2(omega*L, R);
    decay = R/(omega*L);
    fun = @(theta) sin(theta-phi) - ...
        sin(alpha-phi).*exp(-decay.*(theta-alpha));
    gridTheta = linspace(max(pi,alpha+1e-5), alpha+2*pi, 5000);
    vals = arrayfun(fun, gridTheta);
    idx = find(vals(1:end-1).*vals(2:end) <= 0, 1, 'first');
    if isempty(idx)
        error('未找到控制角 %g 度对应的灭弧角。', alphaDeg);
    end
    beta = fzero(fun, [gridTheta(idx), gridTheta(idx+1)]);
    Ud = Vm/(2*pi) * (cos(alpha) - cos(beta));
    betaDeg = rad2deg(beta);
else
    Ud = Vm/(2*pi) * (1 + cos(alpha));
    betaDeg = NaN;
end
end

function write_markdown_tables(T, outFile)
fid = fopen(outFile, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid)); % #ok<NASGU>
fprintf(fid, '# 实验数据表\n\n');
cases = unique(T.LoadCase, 'stable');
for i = 1:numel(cases)
    name = cases{i};
    S = T(strcmp(T.LoadCase, name), :);
    fprintf(fid, '## %s\n\n', name);
    fprintf(fid, '| 控制角 α | 理论 Ud/V | 仿真 Ud/V | 相对误差/%% | 灭弧角 β |\n');
    fprintf(fid, '| ---: | ---: | ---: | ---: | ---: |\n');
    for k = 1:height(S)
        if isnan(S.ExtinctionBetaDeg(k))
            betaText = '-';
        else
            betaText = sprintf('%.2f°', S.ExtinctionBetaDeg(k));
        end
        fprintf(fid, '| %d° | %.4f | %.4f | %.3f | %s |\n', ...
            S.AlphaDeg(k), S.TheoryUd_V(k), S.SimulationUd_V(k), ...
            S.RelativeError_pct(k), betaText);
    end
    fprintf(fid, '\n');
end
end
