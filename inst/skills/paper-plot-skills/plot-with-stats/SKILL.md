---
name: plot-with-stats
description: |
  Integrated plotting + statistics skills (the differentiator of the suite).
  Use when the user asks for a figure that also needs the statistical test
  run at the same time: "配对柱状图加配对 t 检验并标星号", "森林图同时跑
  meta 分析", "火山图自动做差异分析并标 top20 基因", "paired bar with t-test",
  "meta-analysis forest with I2", "volcano with BH FDR".
  All workflows write the figure AND the statistics table with one command,
  ready for supplementary material.
---

# Plot With Stats

绘图 + 统计一体化：同一份输入数据，同时产出图、统计量、可复现表格。
不再需要用户先算好 p 值再画图。

## 三条标准流程

### 1. 配对柱状图 + 配对 t 检验

```bash
python plot-with-stats/scripts/paired_bar_ttest.py \
  --wide my_pairs.csv --col-a baseline --col-b method \
  --out paired_bar.png --table paired_stats.csv --journal nature
```

输出：均值±SEM 配对柱图（个体连线 + 显著性括号星号）+ 统计表
（均值/SD/SEM/mean diff/95%CI/Cohen's dz/t/df/p/stars）。

### 2. 森林图 + meta 分析

```bash
# 任意研究表：beta/se 或 OR/HR + CI；列名自动识别（含 PleioMatchR/TWMR）
python plot-with-stats/scripts/forest_metaanalysis.py \
  --input mr_locus.tsv --scale beta --method both \
  --out forest.png --table meta_stats.csv --journal nature
```

输出：固定效应（IV）与随机效应（DerSimonian-Laird）汇总、Q/p_het、I²、
森林图 + 统计表。与 PleioMatchR 联动见 `data-contracts.md`：

- `pleio_test()` 的 `locus_table`（`sentinel_id, aligned_beta, aligned_se, hit`）
  可直接作为输入（`--scale beta --hit-col hit`）；
- TwoSampleMR `res_single`（`SNP, b, se`）可直接作为输入（`--scale or`）；
- MR 方法汇总表（IVW / weighted median / MR-Egger 行）用 `plot-with-table` 画。

### 3. 火山图 + 差异分析

数据是基因统计结果时直接画：

```bash
python plot-with-stats/scripts/volcano_de.py \
  --stats de_stats.csv --fc-threshold 1 --p-threshold 0.05 \
  --label-top 20 --out volcano.png --table de_annotated.csv
```

数据是原始 counts 时，先用 R 跑 DESeq2（模板在
`plot-with-stats/scripts/volcano_deseq2.R`）：

```bash
Rscript volcano_deseq2.R counts.csv design.csv de_table.csv
```

再对输出的 `de_table.csv` 跑本技能火山图。脚本会自动补 BH-FDR，
并按 padj 取 top-N（默认 20）标注基因名。

## Agent 工作流

1. 解析用户意图 → 确定统计检验：
   - 配对设计 → paired t-test；
   - 两组独立 → 用 scipy 的 ttest_ind / Mann-Whitney（参考本文件原则）；
   - 多研究效应量 → meta 分析；
   - counts 矩阵 → DESeq2 模板（R）。
2. 确认输入数据契约（见 `data-contracts.md`）；列名不合时用 `--*-col` 指定。
3. 跑对应脚本，把图 + 表路径告诉用户。
4. 显著性星号统一规则：`* p<0.05，** p<0.01，*** p<0.001，ns 不显著`。
5. 结果表格同时输出 CSV；需要“表+图同一字体”的精修版走 `plot-with-table`。

## 已知边界

- 本技能内置的是常用频率学派检验；混合效应/生存模型等复杂设计请在
  `plot-with-table` 阶段接入 R/相应包的结果表。
- DESeq2 需要 R 环境；若本机没有 R，向用户说明并退回“基因统计表直接画”。
- 图上色板默认 Okabe-Ito / CVD-safe；不要改成红绿对比（除非用户坚持并经
  `check-colorblind` 确认）。
