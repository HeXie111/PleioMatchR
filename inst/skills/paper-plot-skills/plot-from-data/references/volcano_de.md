# Style: volcano_de（差异分析火山图，Cell/Nature 风格）

**风格来源**：best-practice 模板（转录组差异表达论文常见布局）  
**图表类型**：火山图（volcano）  
**脚本**：`plot-with-stats/scripts/volcano_de.py`（统计部分）  
**DESeq2 R 模板**：`plot-with-stats/scripts/volcano_deseq2.R`  
**所属学科**：生信 / 转录组 / 蛋白质组

---

## 视觉特征

- 上调：橙色 #D55E00；下调：蓝 #0072B2；不显著：灰 #B3B3B3（CVD-safe，非红绿）
- 阈值虚线：x = ±log2FC threshold；y = -log10(p threshold)
- top-N（默认 20）按 padj 升序标注基因名，5.8pt 深灰文字
- 无顶/右边框，图例左上

## 关键参数

```python
FC_THRESHOLD  = 1.0      # |log2FC| >= 1
P_THRESHOLD   = 0.05     # padj < 0.05
LABEL_TOP     = 20       # 按 padj 最小取 top-N 标注
colors = {"up": "#D55E00", "down": "#0072B2", "ns": "#B3B3B3"}
```

## 数据契约

| 模式 | 输入 | 说明 |
|------|------|------|
| 基因统计表（推荐） | `gene, log2fc, pvalue` | 脚本自动 BH-FDR，输出 `padj/direction` 列 |
| 已校正 | `gene, log2fc, pvalue, padj` | `--padj-col padj` 跳过重复计算 |
| 原始 counts | `counts.csv` + `design.csv` | 先跑 `volcano_deseq2.R`，再喂回输出 |

## 用法示例

```bash
python plot-with-stats/scripts/volcano_de.py \
  --stats de_table.csv --fc-threshold 1 --p-threshold 0.05 \
  --label-top 20 --out volcano.png --table de_annotated.csv
```

## 已知限制

- top-N 标注取“显著特征中 padj 最小”，不额外按 |log2FC| 加权；需要“效应最强”
  可让 agent 按自定义列排序后再标。
- counts 模式依赖 R + DESeq2（脚本已检查缺失并报错）。
