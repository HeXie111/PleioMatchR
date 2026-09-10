---
name: plot-with-table
description: |
  One command that produces a results figure AND its styled statistics table
  (same fonts, ready for supplementary material). Use when the user asks for
  "MR 的 IVW 结果表 + 森林图", "figure plus table", "图和配套统计表一起出",
  "supplementary table", "带 OR/CI 的方法汇总表图".
  Consumes method-level tables such as TwoSampleMR `mr()` output rows.
---

# Plot With Table

结果表格 + 绘图联动：同一份统计表，产出
1) 图（默认森林/CI 图，方法为行、OR/HR/β + 95%CI 为菱形行）；
2) 排版一致的表格 PNG（可直接放 supplementary）；
3) 规范化的 CSV（保留）。

## 用法

```bash
python plot-with-table/scripts/figure_plus_table.py \
  --input mr_methods.csv --out-dir results/ --journal nature
```

输入列（自动别名识别）：

| 语义 | 别名 |
|------|------|
| method | method, method_name |
| nsnp | nsnp, n_snp, n |
| effect | or, hr, b, beta, est |
| lower/upper | or_lci95, or_uci95, lci, uci, lower, upper |
| p | pval, p, pvalue |

TwoSampleMR `mr()` 输出的 method 行（`or, or_lci95, or_uci95, pval`）可直接用。
输出到 `--out-dir`：`forest_methods.png`、`table.png`、`formatted_table.csv`。

## Agent 工作流

1. 输入若不是标准列名，用 `--method-col/--effect-col/--lower-col/--upper-col/--p-col`
   显式指定，或先让 R/包导出统一列名。
2. 决定图类型：`--style forest`（默认，OR/HR）或 `--style beta`（线性效应）。
3. 检查 p<0.05 行是否高亮；行顺序按 CSV 顺序（IVW 等请预先排好）。
4. 最终版跑 `plot-check-journal` 校验；与 `plot-panel` 拼多方法图时用同一模板。

## PleioMatchR 联动

`direction_heterogeneity()` 的 WDC/I² 与 `pleio_test()` 的 locus_table 汇总后，
可整理成 method 行喂给本技能；更常用的 MR 方法表（IVW / weighted median /
MR-Egger）来自 TwoSampleMR，列名已兼容。
