# Style: survival_km（Kaplan-Meier 生存曲线，Lancet/NEJM 风格）

**风格来源**：best-practice 模板（临床随访/流行病学论文布局）  
**图表类型**：生存曲线（KM）  
**脚本**：`plot-from-data/scripts/survival_km.py`  
**所属学科**：流行病学 / 临床 / 队列研究

---

## 视觉特征

- 阶梯式生存概率曲线（step + where='post'），两臂 Okabe-Ito 蓝/橙
- 删失点用短竖线 `|` 标在对应平台上
- 图内右下角 log-rank p 值；无顶/右边框

## 关键参数

```python
x = time; y = survival probability (0-1)
step  = 'post'
colors = #0072B2, #D55E00      # Okabe-Ito
censoring marker = '|'
log-rank p 显示在 axes 内右下
```

## 数据契约

CSV/TSV：

| 列 | 说明 |
|----|------|
| time | 随访时间 |
| event | 1=事件发生，0=删失 |
| group | 恰好两组（本模板为双臂设计） |

## 用法示例

```bash
python plot-from-data/scripts/survival_km.py \
  --input km.csv --out km.png --table km_stats.csv --journal lancet
```

输出 `km_stats.csv`：每组 n / events / median survival + log-rank p。

## 已知限制

- 仅双组 + log-rank；多臂/分层/HR(Cox) 请用 R `survival::survfit`/`coxph`
  并把结果表喂给 `plot-with-table`。
- 风险表（numbers at risk）未内置，需要时 agent 按 `plot-panel` 在下方补一行。
