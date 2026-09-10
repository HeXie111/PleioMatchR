# 数据契约与 PleioMatchR 联动

所有统计类脚本都吃**扁平的 CSV/TSV**，列名按别名自动识别，也可以显式传
`--*-col`。下面给出三个常用来源的映射与导出片段。

## 1. PleioMatchR `pmr_pleio` → 森林图

`pleio_test()` 的结果对象里 `x$locus_table` 已含所需列。在 R 里导出：

```r
# PleioMatchR -> plot-with-stats/forest_metaanalysis.py 输入
res <- pleio_test(demo_sentinels, demo_outcome,
                  controls = ctrl, n_perm = 200, seed = 1, verbose = FALSE)
write.table(res$locus_table[, c("sentinel_id", "aligned_beta",
                                "aligned_se", "hit")],
            "locus_table.tsv", sep = "\t", quote = FALSE, row.names = FALSE)
```

然后：

```bash
python plot-with-stats/scripts/forest_metaanalysis.py \
  --input locus_table.tsv --scale beta --hit-col hit \
  --out forest.png --table meta_stats.csv --journal nature
```

脚本自动识别 `sentinel_id / aligned_beta / aligned_se / hit`。

## 2. TwoSampleMR `res_single` / `mr()` → 森林图 / 方法汇总

单 SNP 结果（`SNP, b, se`）：

```bash
python plot-with-stats/scripts/forest_metaanalysis.py \
  --input res_single.csv --id-col SNP --est-col b --se-col se \
  --scale or --method random --journal bmj
```

方法级汇总表（IVW / weighted median / MR-Egger 行）→ 图 + 表：

```bash
python plot-with-table/scripts/figure_plus_table.py \
  --input mr_methods.csv --out-dir mr_results/ --journal nature
```

`mr()` 输出列 `method, nsnp, b, se, pval, or, or_lci95, or_uci95`
均被别名覆盖；p<0.05 行会在表格里高亮。

## 3. 通用数据契约汇总

| 脚本 | 输入列（别名） | 输出 |
|------|----------------|------|
| `paired_bar_ttest.py` | wide: `baseline, method`；long: `subject, condition, value` | 柱图 + `paired_stats.csv`（t/df/p/stars/Cohen's dz） |
| `forest_metaanalysis.py` | `id, est, se`（或 `lower, upper`） | 森林图 + `meta_stats.csv`（含 pooled 行） |
| `volcano_de.py` | `gene, log2fc, pvalue`（可加 `padj`） | 火山图 + `de_annotated.csv`（含 padj/direction） |
| `volcano_deseq2.R` | `counts.csv`（基因×样本）+ `design.csv`（sample,group） | `de_table.csv` |
| `survival_km.py` | `time, event, group`（两组） | KM 图 + `km_stats.csv` |
| `figure_plus_table.py` | `method, or, or_lci95, or_uci95, pval` | `forest_methods.png` + `table.png` + CSV |

## 4. 命名与单位规范

- 效应量统一“每行一个研究/位点”；OR/HR 用 `--scale or|hr` 时 est 为 log 尺度，
  脚本在图上指数显示，统计表同时给原始与指数列。
- 列名不要包含单位；单位放表头注释或单独列（`est_x_unit` 等）。
- 布尔列（`hit`/`direction_ok`）允许 0/1、TRUE/FALSE、yes/no 文本。

## 5. 反估数据的伦理纪律

`plot-from-image` 的 `pixel_to_data.py` 反估坐标用于复现/再分析。若目标论文
已提供补充数据，一律以补充数据为准；图表数字引用他人结果时标注来源与
“estimated from figure” 字样。
