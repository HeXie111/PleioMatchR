---
name: check-colorblind
description: |
  Colour-blind accessibility checker for figures and palettes.
  Use when the user asks to verify or fix CVD safety: "这个配色色盲友好吗",
  "check colorblind", "模拟红绿色盲视图", "换一个色盲安全色板",
  "red-green safe palette", or when a figure/palette uses red-green contrasts
  (volcano plots, t-SNE clusters, group comparisons).
  Simulates protanopia/deuteranopia/tritanopia, flags confusable pairs and
  proposes Okabe-Ito / ColorBrewer replacements.
---

# Check Colorblind

内置 Okabe-Ito、ColorBrewer 色盲安全配色，可一键模拟红-绿色盲视图并给出配色修改建议。

## 两种入口

### 1. 检查调色板（推荐先做）

```bash
python check-colorblind/scripts/simulate_and_fix.py \
  --palette "#E41A1C,#377EB8,#4DAF4A,#984EA3" \
  --out check-colorblind/preview_palette.png
```

输出：
- `preview_palette.png`：原始视图 + protan/deutan/tritan 模拟视图对比
- 控制台/`--report out.json`：易混淆颜色对 + 建议替换（来自 Okabe-Ito）

### 2. 检查整张图

```bash
python check-colorblind/scripts/simulate_and_fix.py \
  --image my_figure.png --out check-colorblind/preview_figure.png --top 8
```

自动提取主色，模拟三种 CVD 视图，报告哪些色对在图里难以区分。

## Agent 工作流

1. 判断图的编码方式：
   - 只靠颜色区分类别 → 必须过 CVD 检查；建议同时加 marker/线型/纹理。
   - 已有形状/纹理/标签 → CVD 风险低，但主色仍建议换安全色板。
2. 运行 palette 或 image 模式，拿到 `pairs` 和 `suggestions`。
3. 若用户接受，直接改脚本中的颜色列表：
   - 类别 ≤ 8 → Okabe-Ito（`catalog/palettes.json`）
   - 类别 > 8 → ColorBrewer Dark2 追加，或改用 viridis。
4. 改完重跑生成图，必要时用 `plot-batch-style` 全批量重渲。
5. 禁止把红绿对（#E41A1C vs #4DAF4A 等）留作唯一编码，除非用户明确坚持。

## 色板速查（catalog/palettes.json）

| palette | CVD safe | 建议用途 |
|---------|----------|----------|
| okabe-ito | ✅ | 默认分类色（≤8 类） |
| brewer-dark2 | ✅ | 8-16 类 |
| brewer-set2 | ✅ | 柔和分类 |
| viridis | ✅ | 连续/热力 |
| cvd-safe-diverging | ✅ | 双向连续（如 MR 效应方向） |
| brewer-set1 / paired | ❌ | 仅在确认无 CVD 读者时使用 |
