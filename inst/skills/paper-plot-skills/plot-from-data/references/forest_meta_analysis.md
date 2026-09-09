# Style: forest_meta_analysis（meta 分析森林图，Nature/BMJ 风格）

**风格来源**：best-practice 模板（无单篇论文原图；参数取自 Nature/BMJ 常见
meta 森林图约定）  
**图表类型**：森林图（forest / meta-analysis）  
**脚本**：`plot-with-stats/scripts/forest_metaanalysis.py`  
**所属学科**：生信 / 流行病学 / 孟德尔随机化 / meta 分析

---

## 视觉特征

- 每行一个研究：正方形/菱形点 + 水平 CI 线；命中（hit）实心，否则空心
- 汇总行：固定/随机效应黑色菱形
- 参照线：β=0（或 OR/HR=1）灰色虚线
- 右侧列：权重百分比与合并效应标注（与左侧数据对齐，仿发表版森林图）
- 底部图内注释：I²、Q、p_het、k
- 色板：Okabe-Ito（默认蓝 #0072B2），CVD-safe
- 字体：Arial/Helvetica 7-8pt（可 --journal 切换 rcParams）

## 关键参数

```python
# 汇总方法
fixed   : inverse-variance fixed effect
random  : DerSimonian-Laird (tau^2 = max(0, (Q-df)/(sum w - sum w^2/sum w)))
I2      = 100 * max(0, (Q - df) / Q)
summary: black diamond; studies: #0072B2 squares
```

## 数据契约

必填：`id`、效应量、SE（或直接给 CI 上下限）。列名自动识别别名，例如：

| 角色 | 自动别名 |
|------|----------|
| id | sentinel_id, SNP, id, locus, rsid, study |
| est | aligned_beta, beta, b, logor, log_OR, effect |
| se | aligned_se, se, std_error, standard_error |
| CI | lower/upper, lci/uci, or_lci95/or_uci95 |
| hit（可选） | hit |

`--scale`：`beta`（默认，直接画 β）、`or`/`hr`（log 尺度 + 指数显示）。

## 用法示例

```bash
python plot-with-stats/scripts/forest_metaanalysis.py \
  --input loci.tsv --scale beta --hit-col hit \
  --out forest.png --table meta_stats.csv --journal nature
```

## PleioMatchR / TwoSampleMR 联动

- `pleio_test()` 的 `x$locus_table`：`sentinel_id, aligned_beta, aligned_se, hit`
  （详见套件根目录 `data-contracts.md` 的 R 导出片段）。
- TwoSampleMR `res_single`：`SNP, b, se` → `--scale or`。

## 已知限制

- 两组以上亚组分析、HR 多因素校正等需用 R `metafor`/`forestplot`；本模板是
  单层级研究效应量的标准实现。
- `--method both` 会同时给出固定与随机两行；若期刊只接受一种，默认 random。
