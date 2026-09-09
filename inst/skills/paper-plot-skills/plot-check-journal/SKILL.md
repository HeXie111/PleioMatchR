---
name: plot-check-journal
description: |
  Pre-submission figure compliance checker against journal specifications.
  Use when the user asks "这个图能投 Nature 吗", "按 Cell 规范检查我的图",
  "journal figure check", "投稿格式自检", "字体字号 dpi 是否符合期刊要求",
  or before exporting figures for a specific journal.
  Reads catalog/journal_specs.json, inspects a matplotlib script or an image,
  prints a parameter-by-parameter report with one-click fix code.
---

# Plot Check Journal

内置各期刊绘图规范库（字体 / 字号 / 线宽 / DPI / 格式 / 栏宽），运行后输出
投稿检查报告，并给出一键修复代码。规范库在 `catalog/journal_specs.json`，
可自行增补或修正（投稿前务必以期刊官网最新 Author Guidelines 为准）。

## 用法

```bash
# 检查脚本（最精确）
python plot-check-journal/scripts/check_script.py \
  --script my_figure.py --journal nature --out report.md

# 只检查成品图（只能检查 dpi / 尺寸 / 格式）
python plot-check-journal/scripts/check_script.py \
  --image my_figure.png --journal cell --out report.md

# 直接生成修复后的脚本副本
python plot-check-journal/scripts/check_script.py \
  --script my_figure.py --journal nature --fix
```

## 支持期刊（catalog/journal_specs.json）

nature · nature_communications · cell · science · plos_one · bmj · lancet ·
jama · nejm · elife

## Agent 工作流

1. 拿到脚本先跑 `--script` 模式；只有 PNG/TIFF 时跑 `--image` 模式。
2. 逐条看报告：
   - ✗ = 必须修；⚠ = 脚本未显式声明（按 matplotlib 默认值推断，建议显式设置）；
     ✓ = 达标。
3. 一键修复：让 agent 把报告里的 rcParams 块放进脚本；DPI/格式按提示改
   `savefig` 调用；需要批量时交给 `plot-batch-style`。
4. 字号换算提醒：面板缩放到期刊栏宽（89/183 mm）后，字号应落在规范区间；
   脚本里 8pt 对应最终印刷 8pt 的前提是 figsize 与栏宽匹配，可用
   `plot_utils.panel_size_mm(journal, double=...)` 换算 figsize。
5. 多子图复合图：先 `plot-panel` 拼好，再对整图做最终检查。

## 判定口径

| 参数 | 判定 |
|------|------|
| font.family | 必须命中期刊允许字体列表（Nature/Cell 系要求 Arial/Helvetica 类无衬线） |
| font.size | 落在期刊字号区间（Nature 7–8pt） |
| axes.linewidth | 落在期刊线宽区间（Nature 0.5–1.0pt） |
| savefig dpi | ≥ 期刊最低值（多为 300，Cell/JAMA/BMJ 600/350） |
| 输出格式 | 扩展名 ∈ 期刊允许格式 |
| 成品图 | 检查像素尺寸与 dpi metadata，字体只能提示“需用脚本核验” |
