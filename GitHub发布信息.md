# GitHub 发布信息

## 仓库名称建议

`single-phase-half-wave-controlled-rectifier-simulink`

如果希望短一些，也可以使用：

`simulink-half-wave-rectifier`

## Description

Simulink models for a single-phase half-wave controlled rectifier with R, RL and freewheeling-diode loads, including automated waveform export and data summary.

## 中文简介

单相半波可控整流 Simulink 实验：包含电阻负载、阻感负载及带续流二极管的阻感负载模型，并提供四种控制角批处理、波形导出和数据汇总脚本。

## Topics

`matlab` `simulink` `power-electronics` `thyristor` `rectifier` `simscape-electrical`

## 新建仓库时的选项

- Visibility：`Public`
- Add README：关闭（本地已有 README）
- Add .gitignore：`MATLAB`
- License：如果希望别人可以自由学习、修改和传播代码，可选 `MIT License`；如果暂时不希望授予明确的再分发权利，可先选 `No license`。

## 首次提交说明

```text
Initial release: add Simulink rectifier models and batch analysis scripts
```

## 上传范围

建议上传当前目录中的以下文件：

- `README.md`
- `half_wave_R.slx`
- `half_wave_RL.slx`
- `half_wave_RL_freewheel.slx`
- `build_models.m`
- `run_all_cases.m`
- `export_model_images.m`
- `实验报告模板.md`

不要上传运行后产生的大量临时缓存。若生成了 `slprj`、`*.slxc`、`*.autosave` 等文件，应通过 `.gitignore` 排除。

