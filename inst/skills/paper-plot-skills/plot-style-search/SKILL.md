---
name: plot-style-search
description: |
  Intelligent style retrieval for the paper-plot-skills catalog.
  Use when the user describes the figure they want in plain language without a
  style id, e.g. "给我一个Nature风格森林图", "画一张生信火山图", "ML 分组柱状图",
  "a Lancet-style Kaplan-Meier curve", "Cell 风格差异表达图"; or asks which
  style/script fits their figure type, journal, palette or discipline.
  Reads catalog/styles.json tags and returns ranked templates with scripts.
---

# Plot Style Search

风格库智能化的入口：每张模板都有标签（图类型 / 期刊风格 / 配色 / 学科），
用自然语言就能定位到具体风格，不再需要记忆函数名。

## 标签体系（catalog/styles.json）

| 维度 | 例子 |
|------|------|
| figure_type | bar / line / scatter / radar / forest / volcano / survival |
| journal_hint | Nature-style / Cell-style / Lancet-style / PLOS-style |
| palette | Okabe-Ito / viridis / custom #A8C8E8 |
| discipline | 生信 / 流行病学 / MR / 机器学习 / 临床 |
| stats | paired t-test / meta-analysis / BH FDR / log-rank |
| aliases | 森林图 / 火山图 / 配对柱 / training curve ... |

## Workflow

1. 把用户原话转成检索词，跑检索脚本（或直接用下面表格判断）：

   ```bash
   python plot-style-search/scripts/search_styles.py "Nature风格 森林图 meta分析"
   python plot-style-search/scripts/search_styles.py "Cell 火山图 生信" --json
   ```

2. 取 top-1/top-2：读出 `script` 与 `reference` 字段（相对套件根目录）。
3. 打开 reference（精确 rcParams / 数据契约），复制 script 到工作目录并替换数据。
4. 如果查询命中多个，向用户展示候选差异（颜色/字体/坐标轴风格），默认取第一。

## 常见映射速查

| 用户意图 | style id | 说明 |
|----------|----------|------|
| Nature 风格森林图 / meta 森林图 / MR 森林图 | `forest_meta_analysis` | 汇总菱形 + I²，吃 `id,est,se` |
| 生信火山图 / 差异表达 | `volcano_de` | 蓝/橙上调下调，BH FDR，top-N 标注 |
| Lancet 生存曲线 / KM 曲线 | `survival_km` | log-rank + 删失 |
| 配对柱 + t 检验 | `bar_paired_test` | 自动星号 |
| baseline vs method 配对增益柱 | `bar_paired_delta` | MemEvolve 风格 |
| 消融分组柱 | `bar_grouped_hatch` | SPICE 风格 |
| 训练曲线 + 置信区间 | `line_confidence_band` | EMA + fill_between |
| t-SNE 聚类散点 | `scatter_tsne_cluster` | 圆角注释框 |
| 折断轴散点 | `scatter_broken_axis` | 双面板 |
| 双方法雷达图 | `radar_dual_series` | DoRA 风格 |

## 维护规则

- 新增模板时必须在 `catalog/styles.json` 注册：补齐四个标签维度 + `script` + `reference`。
- alias 建议同时写中文与英文，检索脚本对中文按子串、英文按词打分。
- `plot-from-data` 与 `plot-style-search` 共用同一份 catalog，禁止两边各维护一张表。
