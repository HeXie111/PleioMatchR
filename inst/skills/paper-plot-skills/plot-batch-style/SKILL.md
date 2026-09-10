---
name: plot-batch-style
description: |
  Batch-style standardisation of many figure scripts with one global
  matplotlib rcParams template. Use when the user has several figure scripts
  (or outputs from plot-from-data) that must share identical fonts, sizes,
  line widths, dpi, legend placement and export settings before composing a
  multi-panel figure or submitting to a journal.
  Triggers: "把这几张图统一风格", "批量统一字号字体", "apply one style to all
  figures", "统一 dpi 和字体再拼面板".
---

# Plot Batch Style

把一套全局 matplotlib rcParams 模板批量注入到多个绘图脚本，统一字体、字号、
线宽、dpi、图例位置与导出格式。

## 用法

```bash
# 内置期刊模板：Nature / Cell / PLOS / Lancet
python plot-batch-style/scripts/apply_rcparams.py \
  --rcparams plot-batch-style/stylebank/rcparams_nature.json \
  --files fig_a.py fig_b.py fig_c.py \
  --out-dir unified_figs/

# 图例位置等额外统一项可直接写进模板 JSON（任何 matplotlib rcParams key 均可）
python plot-batch-style/scripts/apply_rcparams.py \
  --rcparams my_team_style.json --files *.py --inplace
```

## rcParams 模板字段（可扩展）

```json
{
  "font.family": "sans-serif",
  "font.sans-serif": ["Arial", "Helvetica"],
  "font.size": 8,
  "axes.labelsize": 8,
  "xtick.labelsize": 7,
  "ytick.labelsize": 7,
  "legend.fontsize": 7,
  "legend.loc": "upper right",
  "axes.linewidth": 0.75,
  "figure.dpi": 100,
  "savefig.dpi": 300,
  "savefig.format": "png",
  "font.style": "normal"
}
```

## Agent 工作流

1. 确认用户提供的输入：
   - 若给的是 **脚本**：直接批量注入（脚本会写到 `--out-dir`，不覆盖原件）。
   - 若给的是 **图片**：无源码时无法重渲；流程改为：用 `plot-from-image`
     反向提取参数 → 重建脚本 → 再走本技能；或直接用 `plot-panel` 拼合时统一白底。
2. 选模板：先问目标期刊或用 `plot-check-journal` 决定；本技能只负责“套用”。
3. 运行脚本；检查输出中是否有 “later override” 警告（脚本后面又改了 rcParams，
   会覆盖全局模板 → 让 agent 删除或注释掉后面的局部 update）。
4. 重新运行被注入的脚本，逐一确认字号/线宽/图例位置一致。

## 注意事项

- 注入发生在文件首个 `plt.rcParams.update(...)` 之后（若没有则插在 import 之后），
  保证模板覆盖该脚本自己的默认设置。
- 若用户要求统一“图例位置”，统一放进模板 JSON（`legend.loc`）。
- 本技能只处理 matplotlib/`rcParams` 生态；ggplot2(R) 脚本的批量统一请走
  `plot-style-transfer` 输出等价 R 代码后自行维护主题函数。
