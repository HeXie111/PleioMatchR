---
name: plot-from-data
description: |
  Generate publication-quality matplotlib figures by selecting a pre-built paper style and substituting user data.
  Use when: user provides data (numbers, arrays, or CSV) and wants a chart in a specific academic style;
  user asks to "plot this data", "make a bar chart", "draw a radar chart", "用这个风格画图", "把我的数据画出来";
  or user selects a style name from the style catalog (bar_paired_delta, bar_grouped_hatch,
  line_confidence_band, line_training_curve, line_loss_with_inset, scatter_tsne_cluster,
  scatter_broken_axis, radar_dual_series, forest_meta_analysis, volcano_de, survival_km).
---

# Plot From Data

Generate a paper-quality figure by picking a style template and filling it with user data. All outputs are `dpi=300` PNG.

## 升级说明（v2）

- **自然语言选风格**：用户没给风格名时，先跑风格检索再决定模板：

  ```bash
  python ../plot-style-search/scripts/search_styles.py "Nature风格 森林图 meta"
  ```

  风格目录统一在 `catalog/styles.json`（图类型 / 期刊 / 配色 / 学科 / stats 标签）。
- **新增长尾风格**：`forest_meta_analysis`（森林图+meta 统计）、`volcano_de`
  （火山图+差异分析）、`survival_km`（生存曲线）——直接服务生信 / MR /
  流行病学场景，并与 `plot-with-stats` 共享脚本。
- **统计联动**：需要同时跑检验时（t-test / meta / FDR），数据契约不变，
  直接调用脚本即可；统计+表格+图一次输出。
- **输出路径**：所有脚本已修复为可移植输出（写到当前目录或 `--out` 指定
  路径），不再依赖作者机器上的绝对路径。

## Available Styles

| Style | Type | Script | 适用场景 |
|-------|------|---------|---------|
| `bar_paired_delta` | 柱状图 | `scripts/bar_memevolve.py` | Baseline vs method 配对对比 + 增益箭头 |
| `bar_grouped_hatch` | 柱状图 | `scripts/bar_spice.py` | 多方法消融，主方法斜线填充，柱顶数值 |
| `line_confidence_band` | 折线图 | `scripts/line_selfdistill.py` | 带置信区间的训练曲线 |
| `line_training_curve` | 折线图 | `scripts/line_aime.py` | 垂直断点线 + 水平参考线 |
| `line_loss_with_inset` | 折线图 | `scripts/line_loss_inset.py` | L 形 spine + 局部放大 inset |
| `scatter_tsne_cluster` | 散点图 | `scripts/scatter_tsne.py` | t-SNE 聚类 + 注释框 |
| `scatter_broken_axis` | 散点图 | `scripts/scatter_break.py` | 折断 X 轴，多 marker 系列 |
| `radar_dual_series` | 雷达图 | `scripts/radar_dora.py` | 双方法多维对比，正八边形网格 |
| `forest_meta_analysis` | 森林图 | `../plot-with-stats/scripts/forest_metaanalysis.py` | meta/森林图：固定+随机效应、I²、汇总菱形 |
| `volcano_de` | 火山图 | `../plot-with-stats/scripts/volcano_de.py` | 差异分析：BH-FDR、top-N 标注 |
| `survival_km` | 生存曲线 | `scripts/survival_km.py` | KM 曲线：log-rank p、删失刻度 |

## Workflow

```
1. 确认用户的图类型、目标期刊/配色/学科（可从对话推断，不必追问）
2. 没有 style id 时先跑 plot-style-search；有则直接用
3. 读取对应 references/<style_name>.md 获取精确参数与数据契约
4. 数据来自文件时按契约喂 CSV/TSV；数组数据可替换脚本顶部数据区
5. 运行脚本（默认输出当前目录或 --out）
6. 检查输出；需要批量统一风格时接 plot-batch-style；投稿前接 plot-check-journal
```

## Data Substitution Tips

每个 repro 脚本的数据区在文件顶部，通常是 `np.array(...)` 或字典。替换规则：
- 保持数组维度和类型不变
- 若类别数变化（如从 4 组改为 6 组），同步调整颜色列表和宽度计算
- x 轴标签、图例标签直接修改对应字符串列表

## Detailed Style Parameters

Read the corresponding file in `references/` for exact `rcParams`, colors, font sizes, spine settings, and tick directions before generating:

- Bar: `references/bar_paired_delta.md`, `references/bar_grouped_hatch.md`
- Line: `references/line_confidence_band.md`, `references/line_training_curve.md`, `references/line_loss_with_inset.md`
- Scatter: `references/scatter_tsne_cluster.md`, `references/scatter_broken_axis.md`
- Radar: `references/radar_dual_series.md`
- Forest/Volcano/Survival: `references/forest_meta_analysis.md`, `references/volcano_de.md`, `references/survival_km.md`

## 注意

- 旧 8 个 repro 脚本数据区在文件顶部（`np.array` / 字典），替换时保持维度。
- LaTeX 依赖已改为可选：`text.usetex` 默认 False（机器装有 TeX 时可改 True）。
- 期刊字体（Arial 7-8pt 等）统一由 `--journal`/stylebank rcParams 控制。
