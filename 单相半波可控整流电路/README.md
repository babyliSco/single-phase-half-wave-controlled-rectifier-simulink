# 实验一：单相半波可控整流电路

本目录用于 MATLAB R2024b、Simulink 和 Simscape Electrical（Specialized Power Systems）。实验参数已经按指导书设置：

- 交流电源有效值：220 V；
- 频率：50 Hz；
- 电阻：50 Ω；
- 电感：0.5 H；
- 控制角：30°、60°、90°、120°；
- 门极脉冲宽度：周期的5%，即0.001 s；
- 仿真时间：0.1 s；
- 最大步长：1e-5 s。

## 文件说明

- `half_wave_R.slx`：电阻负载；
- `half_wave_RL.slx`：阻感负载，无续流二极管；
- `half_wave_RL_freewheel.slx`：阻感负载，带续流二极管；
- `run_all_cases.m`：依次运行三套模型和四个控制角；
- `export_model_images.m`：导出三张模型结构图，不执行仿真；
- `实验报告模板.md`：实验原理、思考题答案和结论框架；
- `build_models.m`：重新生成模型，通常不需要再次运行。

## 最省事的运行方法

1. 用 MATLAB 打开本文件夹。
2. 在命令行运行：

```matlab
run_all_cases
```

3. 等待脚本执行结束，打开 `results` 文件夹。

脚本会生成：

- 12张波形图，每种负载4张；
- `实验数据汇总.csv`；
- `实验数据表.md`。

每张波形图从上到下依次为交流电源电压 `u2`、负载电压 `ud`、负载电流 `id`、晶闸管端电压 `uT`。

## 单独打开模型

双击任意 `.slx` 文件即可查看模型。模型工作区中的 `alpha_deg` 默认是30。需要手动修改时，在 MATLAB 命令行执行：

```matlab
mdl = 'half_wave_R';       % 也可以换成另外两个模型名
load_system(mdl);
mw = get_param(mdl,'ModelWorkspace');
assignin(mw,'alpha_deg',90);
open_system(mdl);
```

然后点击 Simulink 的运行按钮。模型中的 Scope 已接入四路波形。

## 平均电压说明

模型内的 Display 显示从0时刻开始累计的运行平均值，适合快速观察。批处理脚本使用最后一个工频周期的数据进行积分：

```matlab
Ud = trapz(t, ud) / T;
```

阻感负载存在启动暂态，实验数据应优先采用脚本生成的最后周期平均值。

电阻负载以及带续流二极管的理想阻感负载使用：

$$
U_d=\frac{\sqrt{2}U_2}{2\pi}(1+\cos\alpha).
$$

无续流二极管的阻感负载使用：

$$
U_d=\frac{\sqrt{2}U_2}{2\pi}(\cos\alpha-\cos\beta),
$$

其中灭弧角 `β` 由负载电流降为零的条件数值求解。

## 注意事项

- 仿真模型采用 Specialized Power Systems 元件，必须保留 `powergui`。
- `AC Voltage Source` 的幅值参数使用峰值 `sqrt(2)*U2_rms`，不是220。
- 电感负载的启动阶段不代表稳态平均值。
- 波形图和表格生成后，把对应控制角写在实验报告图片旁边。
- 如果波形开关瞬间不够平滑，可将模型最大步长从 `1e-5` 调小，但仿真时间会增加。
