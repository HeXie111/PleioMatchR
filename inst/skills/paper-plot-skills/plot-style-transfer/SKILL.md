---
name: plot-style-transfer
description: |
  Cross-library style transfer for the style catalog: emit equivalent code in
  matplotlib, seaborn, ggplot2 (R) or origin-py (OriginLab) from one style id
  and one tidy data CSV. Use when the user says "转成 ggplot2/R 代码",
  "convert to seaborn", "给我等价 R 代码", "origin 脚本", "matplotlib to R",
  or uploads a ggplot2 figure and wants both matplotlib and R reproductions.
---

# Plot Style Transfer

同一份数据 + 同一套风格参数（颜色/字体/字号/坐标轴约定），输出等价代码到
目标绘图库：

| 目标 | 输出 | 适用 |
|------|------|------|
| matplotlib | `.py` | 默认（本套件原生态） |
| seaborn | `.py` | 统计图快速分层 |
| ggplot2 (R) | `.R` | 期刊复现 / R 生态 |
| origin-py | `.py` | OriginLab 内部出图 |

## 用法

```bash
# 风格 id 从 catalog/styles.json 取（plot-style-search 可查）
python plot-style-transfer/scripts/convert_style.py \
  --style forest_meta_analysis --chart forest --target ggplot2 \
  --data loci.csv --out forest_ggplot2.R

python plot-style-transfer/scripts/convert_style.py \
  --style bar_paired_delta --chart bar --target seaborn \
  --data pairs.csv --groupcol condition --valuecol value \
  --palette "#A8C8E8,#1B3D6E" --out pairs_seaborn.py
```

数据列约定（tidy）：

| 列 | 说明 |
|----|------|
| x / 分组变量 | `--xcol` |
| y / 数值 | `--ycol`（bar 模式也可用 `--groupcol` + `--valuecol`） |
| group | 系列/颜色分组 `--groupcol` |
| error | 误差上下限 `--errorcol`（se）或 `--locol/--hicol` |

## Agent 工作流

1. 用户说“上传一张 ggplot2 图，要 matplotlib + R 代码”→ 走 `plot-from-image`
   分层解析，把 `library_hint: ggplot2` 与提取的风格 token 一起给本技能。
2. 选风格/配色：拿图内颜色（±10 RGB）填 `--palette`，字体/字号按原图判断。
3. 跑转换器生成目标脚本；代码里保留了数据读取 + 导出段，可直接运行/微调。
4. 转 ggplot2 后建议人工核对主题：本工具给出风格骨架（字体、色板、图例、
   主题线），复杂布局（断轴/雷达/inset）需 R 包（ggh4x / fmsb）扩展。
5. 目标为 seaborn/origin 时同理——转换器不保证 1:1 像素复现，保证风格等价。

## 已知边界（诚实清单）

- 支持 chart：bar（分组/配对）、line（多系列+误差带）、scatter（分组）、
  forest（pointrange）。
- 不支持自动转换：折断轴、雷达、inset 缩略图、t-SNE 注释框等复合装饰——
  需按 `plot-from-image` 的 layers.json 手工补。
- origin 输出仅在 OriginLab 的 Python 环境（`originpro`）里可运行。
