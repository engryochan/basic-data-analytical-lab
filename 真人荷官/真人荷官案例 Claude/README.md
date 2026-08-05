# 风控四表分析交付物

## 目录结构

```
risk_report/
├── risk_analysis_report.qmd          # Quarto 静态分析报告(HTML) — 总览仪表盘(100行样本)
├── member_deep_dive_report.qmd       # Quarto 深度报告 — 地毯式画像/统计推断/蒙特卡洛模拟/准回测(100行样本)
├── top_tier_methodology_report.qmd   # Quarto 顶级方法论报告 — 贝叶斯层级模型/HMM/生存分析/MASE回测(10万行全量)
├── app.R                              # Shiny 交互式探索应用
├── data/                              # 100行样本数据(用于前两份报告)
│   └── ...
├── data_full/                         # 10万行全量数据(用于顶级方法论报告)
│   ├── dealer_profit_stat.csv
│   ├── dealer_profit_stat_hourly.csv
│   ├── player_pair_stat.csv
│   └── player_pair_stat_hourly.csv
└── README.md
```

## ⚠️ 关于 top_tier_methodology_report.qmd 的重要提醒

这份报告涉及 **Stan贝叶斯MCMC采样**（两个brm()模型各跑4条链）+ **142次独立HMM拟合** + **10万行数据的生存分析**，计算量远超前两份报告：

- **首次运行前**，`brms`包会自动调用`rstan`编译C++模型代码，需要电脑装有C++编译工具链（Windows上通常需要先装 **Rtools**，你之前已经装过 `rtools45`，这个应该够用）
- **完整渲染预计耗时从几分钟到二三十分钟不等**，取决于你的CPU核心数（`options(mc.cores = parallel::detectCores())` 已设置为自动使用全部核心并行跑MCMC链）
- 建议**先跑一次单独测试**贝叶斯模型能否正常拟合，再执行完整渲染：
  ```r
  library(brms)
  test_fit <- brm(mpg ~ wt, data = mtcars, chains = 1, iter = 500)
  ```
  如果这个能正常跑完，说明Stan环境配置没问题，可以放心渲染完整报告。

## 在 Positron 中运行

### 前置：安装所需 R 包（首次运行前执行一次）

```r
install.packages(c(
  "data.table", "dplyr", "tidyr", "lubridate", "ggplot2",
  "plotly", "DT", "gt", "gtExtras", "corrr", "igraph", "ggraph",
  "scales", "patchwork", "shiny", "bslib", "forecast", "MASS", "glue",
  "brms", "rstan", "survival", "ranger", "depmixS4", "lme4",
  "xgboost", "keras3"
))

# keras3 首次使用需要额外安装 Python 后端(TensorFlow)：
library(keras3)
install_keras()
```

`brms`/`rstan`首次安装耗时较长（需要编译），且**依赖系统装有C++编译工具链**。Windows下如果之前没配置过，需要先装 **Rtools**（你的电脑上如果已经有`rtools45`，通常已经满足要求）。

`keras3`底层调用TensorFlow(Python)，`install_keras()`会自动创建一个独立的Python虚拟环境并安装好TensorFlow，首次运行需要联网下载，耗时几分钟。

如果用 uv/renv 管理项目依赖，建议改用 `renv::snapshot()` 锁定这份依赖清单。

### 渲染 Quarto 报告

在 Positron 终端里：
```bash
quarto render risk_analysis_report.qmd
quarto render member_deep_dive_report.qmd
quarto render top_tier_methodology_report.qmd
```
渲染完成后会生成对应的 `.html` 文件，双击用浏览器打开即可查看完整报告（包含交互式图表和表格，可离线分享）。

也可以直接在 Positron 编辑器里打开 `.qmd` 文件，点击顶部的 **Render** 按钮一键渲染+预览。

### 运行 Shiny 应用

在 Positron 终端里：
```r
shiny::runApp("app.R")
```
或者直接打开 `app.R` 文件，Positron 编辑器右上角会出现 **Run App** 按钮，点击即可在内置浏览器/Viewer面板中打开交互应用。

## 核心发现速览

1. **数据质量问题**：`dealer_profit_stat` 候选表本次导出的100条样本，`dealer_id` 全部为哨兵值 `-1`，风险评分字段全部无效。诊断为**候选表查询未按 `risk_score DESC` 排序**导致的截断问题，而非评分链路整体失效。README 末尾附验证 SQL。
2. **关键结构修正（重要）**：`player_pair_stat` 的 `player_a` 字段全部为同一玩家（唯一值），说明这100条记录是**该玩家一人与100个不同搭档的完整配对清单**，不是候选池的随机样本。这一点在 `member_deep_dive_report.qmd` 第一节有详细核查，会改变对"地毯式分析"和"网络图团伙检测"结果的正确解读方式——早期版本报告中的网络连通分量分析结论需要按此重新理解。
3. **方法论修正（重要）**：用泊松回归做统计检验会因忽略"过度离散"而产生大量假阳性；改用负二项回归 + Benjamini-Hochberg多重比较校正后，之前"疑似显著"的搭档大多无法通过严格检验——这提示当前样本规模下**统计检验力不足**，而非"确认无风险"，详见深度报告第二、六节。
4. `player_pair_stat` 数据质量良好，已构建正交化因子风险模型 + 网络关系图 + 引力模型统计推断，可作探索性分析参考。
5. 报告与应用中前两份报告所有数值均基于100行样本计算，仅供方法论验证；`top_tier_methodology_report.qmd`已改用10万行全量数据，结论可信度更高。
6. **全量10万行验证（`top_tier_methodology_report.qmd`）**：`risk_score`/`dealer_std_roi`/`roi_zscore`在全部10万行里100%无效，**确认是系统性计算链路失效，不再是抽样偶然**。已用贝叶斯层级模型（brms/rstan）、HMM状态切换检测、Cox生存分析+随机生存森林+XGBoost生存模型、Autoencoder无监督异常检测（keras3/TensorFlow）、XGBoost监督回归残差分析，对**全部142位荷官、全部289位焦点玩家、全部10万条配对记录**给出独立于失效字段的风险评分，并导出为可直接接入复核流程的CSV清单。
7. **三方法交叉验证**：贝叶斯统计模型、Autoencoder无监督深度学习、XGBoost监督回归——三种完全独立的方法，同时命中的记录被列为最高优先级复核对象，这是没有标签数据情况下能拿到的最高置信度信号。
8. 经MASE多模型回测验证，**当前3天数据跨度下不适合使用LSTM/Transformer做时间序列预测**（经典模型如ETS/ARIMA在小数据量下稳定优于深度学习模型）；**Transformer作为欺诈分类器同样不可行**（无标签数据）；但**Autoencoder（无监督异常检测）和XGBoost（监督回归/生存分析）都已实际采用**，因为它们不需要标签数据、且在10万行规模下有充分数据支撑。
9. **数据源说明**：`risk_analysis_report.qmd`和`top_tier_methodology_report.qmd`已改用全量`data_full/`；`member_deep_dive_report.qmd`经核实后**刻意继续使用`data/`专案数据**——因为该报告分析对象(玩家273467)是一份独立的定向调查导出，不存在于全量数据中，属于两种不同性质的数据集，不能互相替换。

## 验证 SQL（用于确认第1点诊断）

```sql
SELECT * FROM dealer_profit_stat
WHERE dealer_id != -1
ORDER BY risk_score DESC
LIMIT 100;

SELECT
  SUM(CASE WHEN dealer_id = -1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS sentinel_pct
FROM dealer_profit_stat;
```

## 后续可扩展方向

- 因子模型权重（0.35/0.30/0.20/0.15）目前是经验设定，建议在有历史"已确认作弊"标签数据后，改用逻辑回归或树模型做权重的数据驱动校准，而非人工拍板
- 网络图目前用简单阈值(`risk_score`分位数)筛选边，可以升级为社区发现算法(如 Louvain, `igraph::cluster_louvain()`)自动识别团伙边界，而不是靠肉眼看图
- Shiny 应用可以接入 `pool` + 数据库连接包，改为直接连 Superset 后端数据库实时查询，替代当前的静态 CSV 读取
