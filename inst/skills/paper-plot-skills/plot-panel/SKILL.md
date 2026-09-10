---
name: plot-panel
description: |
  Assemble 4-6 independent sub-figures into one submission-ready multi-panel
  composite (fig, ((ax1,ax2),(ax3,ax4)) style) with (a)(b)(c)(d) labels,
  letterboxing to a common panel size, controlled spacing and journal-grade
  export. Use when the user says "拼图", "合成多子图", "multi-panel figure",
  "加上 (a)(b)(c)(d) 标签", "把这四张图拼成 Figure 1".
---

# Plot Panel

输入 4-6 张独立子图，自动生成统一尺寸的复合图：等大画板、统一间距、
自动 (a)(b)(c)(d) 标签、可选白边裁剪，并按期刊 dpi/格式导出。

## 用法

```bash
# 四张图 2x2
python plot-panel/scripts/make_panel.py \
  --images panel_a.png panel_b.png panel_c.png panel_d.png \
  --layout 2x2 --out figure1.tiff --dpi 600 --journal nature

# 六张图 2x3，自定义标签
python plot-panel/scripts/make_panel.py \
  --images p1.png p2.png p3.png p4.png p5.png p6.png \
  --layout 2x3 --labels "a b c d e f" --trim --out figure1.png
```

## Agent 工作流

1. **先统一再拼**：如果子图来自不同脚本，先用 `plot-batch-style` 统一字体/
   字号/线宽，或让所有子图脚本共用同一套 rcParams；否则拼出的面板会露馅。
2. 确认最终印刷栏宽：默认按期刊 double-column 宽度计算 figsize；
   半栏图用 `--single-column`。
3. 运行 `make_panel.py`；检查：
   - 字母标签大小 ≥ 最终印刷 7pt（脚本按 label-size 参数换算）；
   - 各子图间留白均匀、坐标轴不重叠；
   - 子图内字号与 `(a)` 字号视觉协调。
4. 对成品跑 `plot-check-journal --image` 做最终 dpi/尺寸校验。
5. 源子图若含白边过多 → 加 `--trim`；若需重排顺序/布局，直接改 layout。

## 输出

- PNG/TIFF/SVG 由 `--out` 扩展名决定；
- `--dpi` 建议 300（Nature 系）或 600（Cell/BMJ，按 journal 参数自动给默认）。

## 局限与替代

- 本技能面向“图片级拼合”。若需要跨子图共享坐标轴（如 common x-axis）或
  数据级联动，应改在单一脚本里用 `plt.subplots` 重画（参考 plot-from-data 模板）。
- 子图字体已光栅化后无法改变；要在拼合前统一风格，务必先走
  `plot-batch-style` 重渲染。
