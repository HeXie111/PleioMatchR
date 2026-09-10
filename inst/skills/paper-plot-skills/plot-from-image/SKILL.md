---
name: plot-from-image
description: |
  v2 layered reproduction of any academic figure from an uploaded image.
  Use when: user uploads/attaches a paper figure and asks to reproduce it;
  user says "复现这个图", "reproduce this plot", "match this figure",
  "照着这个图画", "把这张图的数据估出来", "导出这张图的 CSV";
  or provides a paper figure PNG/screenshot and wants matplotlib/ggplot2/R code.
  v2 adds semantic layer decomposition (axes / error bars / annotations /
  arrows / legends / insets / filled regions / text), reverse estimation of
  data coordinates to CSV, LaTeX-label conversion and style-library matching.
---

# Plot From Image（v2 分层解析）

把一张论文图拆成可复现的结构，而不是整张糊在一起：先分层识别元素，再
（可选）反估数据点，最后生成代码。所有步骤都有脚本/清单兜底，agent 负责
视觉判断与参数微调。

## Workflow

### 0. 测量画布

```python
python3 -c "from PIL import Image; img=Image.open('fig.png'); print(img.size, f'AR={img.size[0]/img.size[1]:.2f}')"
```

记录 `image_px`，后面复现 `figsize` 必须保持同一长宽比。

### 1. 语义分层解析（核心新增）

按 `references/layer_inventory_schema.json` 写出 `layers.json`。逐元素识别并记录
（像素 bbox + 风格 token）：

| 层类型 | 必查内容 |
|--------|----------|
| axes_frame | 四边/L 形、spine 线宽、刻度朝向 |
| axis_label / tick / gridline | 文本、字号、颜色、虚线样式 |
| series_line / scatter_points / bar | 颜色、线型、marker、透明度、误差棒 |
| error_bar | 须/帽样式，是否对称 |
| filled_region | 填充颜色、alpha、边界 |
| annotation_box / text_label / formula_label | 框线、底色、圆角、文本 |
| arrow | 箭头样式、颜色、线宽 |
| legend | 位置、框线、列数 |
| inset | 位置比例、连接虚线 |
| axis_break | 断点位置与样式 |
| table_cell | 行列结构、底色高亮 |

同时判断 `library_hint`（matplotlib / ggplot2 / base-R / origin）。ggplot2 特征：
灰底 `panel.background`、白色格线、无边框 → 可直接走 `plot-style-transfer`
输出 R 代码。

### 2. 匹配现有风格（快路径）

| 特征 | 风格 |
|------|------|
| 配对柱 + 箭头 | `bar_paired_delta` |
| 斜线填充分组柱 | `bar_grouped_hatch` |
| 置信区间阴影曲线 | `line_confidence_band` |
| 断点 + 参考线 | `line_training_curve` |
| L 形 spine + inset | `line_loss_with_inset` |
| 聚类散点 + 注释框 | `scatter_tsne_cluster` |
| 折断轴 | `scatter_broken_axis` |
| 雷达网图 | `radar_dual_series` |
| 效应量横线图 | `forest_meta_analysis`（转 plot-with-stats） |
| 火山散点 | `volcano_de` |
| 阶梯生存线 | `survival_km` |

命中 → 读 `../plot-from-data/references/<name>.md` 参数 → 换数据。未命中才做
from-scratch（`references/reproduction_guide.md` 全清单）。

### 3. 数据逆向估算（可选）

视觉模型/agent 在图上标出坐标轴校准点和数据点像素坐标，脚本换算成数据值：

```bash
python plot-from-image/scripts/pixel_to_data.py \
  --image fig.png --points points.csv \
  --x-px 120 900 --x-val 0 100 \
  --y-px 850 90  --y-val 0 50 \
  --out estimated_data.csv --xunit "%" --yunit "accuracy"
```

`points.csv` 列：`px, py [, label]`（原点左上，py 向下）。
支持 log 轴（`--xlog/--ylog`）。输出 CSV 可直接喂给 `plot-from-data`。

**精度纪律**：反估数据是近似值，仅供复现与再分析；引用他人结果必须回到
原文数值或作者提供的数据。对散点/柱状/折线逐点估计时，校准点越多误差越小。

### 4. LaTeX 标签转换

```bash
python plot-from-image/scripts/latexify_labels.py --text "beta-hat for 10^-5"
python plot-from-image/scripts/latexify_labels.py --file axis_labels.txt --out labels_latex.tsv
```

规则库在 `references/latex_rules.json`（希腊字母、上下标、R²、10^n、p-value…），
输出 matplotlib `r"$...$"` mathtext。转换后人工核对：期刊 LaTeX 可用 usetex=True
渲染同一字符串。

### 5. 生成 & 迭代

```
写脚本 → python3 脚本 → 对照 layers.json 逐项核对 → 修正比例/颜色/字号 → 重跑
```

核对清单：
- [ ] AR 与原图一致（PIL 测量）
- [ ] 分层元素齐全（对照 layers.json，误差棒/inset/箭头不要丢）
- [ ] 字体族正确（serif↔sans-serif；ggplot2 灰底要转 R 主题）
- [ ] 颜色与原文 ±10 RGB
- [ ] spine/刻度/网格/图例位置一致
- [ ] 文本标签已 LaTeX 化（有公式时）
- [ ] 反估数据 CSV 已导出（若用户要求）

## 资源

- Schema：`references/layer_inventory_schema.json`
- 分析清单：`references/reproduction_guide.md`
- 数据反演：`scripts/pixel_to_data.py`
- LaTeX 标签：`scripts/latexify_labels.py` + `references/latex_rules.json`
- 风格库：`../plot-from-data/references/`（11 个风格参数文件）
- 风格转移：`../plot-style-transfer/`（matplotlib/seaborn/ggplot2/origin）
