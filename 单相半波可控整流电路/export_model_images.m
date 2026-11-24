%% 导出三张模型结构图（不执行仿真）
rootDir = fileparts(mfilename('fullpath'));
outDir = fullfile(rootDir, 'results');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

models = {'half_wave_R','half_wave_RL','half_wave_RL_freewheel'};
for k = 1:numel(models)
    mdl = models{k};
    load_system(fullfile(rootDir, [mdl '.slx']));
    set_param(mdl, 'ZoomFactor', 'FitSystem');
    print(['-s' mdl], '-dpng', '-r180', fullfile(outDir, [mdl '_model.png']));
    close_system(mdl, 0);
end
fprintf('模型图已保存到：%s\n', outDir);
