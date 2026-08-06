# casino_v12_13_v2 变更记录

**审核范围说明（如实交代）**：这一轮只完整核实了 `README.md`、`lib/dimension_dict.py`、
`lib/player_scoring_core.py` 三个文件，外加全项目的文件名/import 一致性排查。
`player_scoring_advanced.py`、改名后的四个模块(时序安全抽样/时序滚动回测/贝叶斯串谋
分析/荷官评分引擎)、`tools/*.py`、`streamlit_app.py` 的业务逻辑本体，还没有逐行核实，
下一轮按承诺的顺序继续。

## 已修复（本轮完成，已验证）

### 1.【严重】中文文件名在 Linux 环境下会导致模块加载失败

原压缩包 `lib/` 下四个文件用中文命名：
- `时序安全抽样.py`
- `时序滚动回测.py`
- `贝叶斯串谋分析.py`
- `荷官评分引擎.py`

`app/streamlit_app.py` 里用中文文件名去 `from 荷官评分引擎 import ...`。这四行 import
本身合法，但压缩包打包时 Unicode 文件名标记没设对，标准 Linux `unzip` 解开后文件名会
变成乱码转义字符串（比如 `#U8377#U5b98...py`），导致上述 import 全部失败——不会让整个
应用崩溃（每处都包在 `try/except` 里），但会**静默**关闭荷官评分、串谋分析、时序安全
抽样、时序滚动回测这四个功能板块，容易没注意到就当成"没这个数据/没这个功能"。

**修复**：四个文件改名为 ASCII 文件名（`dealer_scoring_engine.py`、
`bayesian_collusion_analysis.py`、`time_series_safe_sampling.py`、
`time_series_rolling_backtest.py`），`streamlit_app.py` 里对应四处 `from ... import`
的模块路径同步改名，另外三处文档字符串/报错文案里残留的旧路径引用（`lib/贝叶斯串谋
分析.py` 等）一并更新，避免文档跟实际路径对不上。**只改了文件名和 import 路径，函数
内部的中文变量/函数名（如 `荷官完整流水线`）原样保留没有动**——这些是文件内容，不受
zip 文件名编码问题影响，改了反而徒增风险。

已验证：全项目重新扫描确认没有遗漏引用；改名涉及的全部文件过了 `py_compile` 语法检查。

### 2. `player_scoring_core.py`：小样本下 AP/RG/极端赢家标记会产生没有意义的结果

`assign_grades()` 里 AP 嫌疑、RG 高风险、极端赢家这三个标记全部基于 90/85/99 分位数
判断。样本量很小时（比如接下来要在 `/home/ryochan/` demo 表上练手，很可能只有几行假
数据），分位数本身没有统计意义。同一个文件里 `_quantile_grade_thresholds()` 已经对
等级门槛做过 `样本量<30` 的防护（小样本自动退回固定门槛），但这三个风险标记没有对齐
同一条防护——已补齐：样本量 <30 时，三个标记自动全部记为 `False`，并在
`scoring_meta` 里留一条 `小样本提示_small_sample_note` 说明原因，不会在 demo 数据上
打出看似煞有介事、实际没有意义的风险标签。

## 核实过、确认没问题、未改动的部分

- `ScoringConfig` 五个权重合计正好 1.0，等级门槛降序排列，正确。
- 熵权法（`_entropy_pair_weights`）公式核对无误：熵越高（分布越均匀、区分度越低）
  权重越低，符合标准熵权法定义，且对样本量<5的边界情况有正确防护，不会除零。
- `_data_driven_dim_weights()` 只作为诊断性对照指标写进 `scoring_meta`，不会反过来
  覆盖 `compute_scores()` 里实际使用的文献权重——这是刻意设计（避免用分数去反推权重
  造成循环论证），不是遗漏。
- `player_win = -total_ggr`、`roi = total_ggr/total_bet_amount` 这组正负号关系自洽，
  AP 嫌疑判定逻辑（高局数+高净赢+GGR为负）符合"优势玩家持续盈利"这个业务直觉。

## 尚待处理（如实列出，避免误以为已经全部弄完）

- `player_scoring_advanced.py`（16.8KB）——还没细看。
- `dealer_scoring_engine.py`、`bayesian_collusion_analysis.py`、
  `time_series_safe_sampling.py`、`time_series_rolling_backtest.py`——改名后语法检查
  通过，但内部算法逻辑还没有逐行核实。
- `tools/*.py`——命令行工具层，还没细看（不依赖前述四个改名模块，风险相对低）。
- `streamlit_app.py` 主体（12万+字节）——只改了 import 和三处路径引用，UI/展示逻辑
  本体没有细看。
- 字典对接（把 ODS Encyclopedia 结构层扫描输出转成 `字典_全局.csv`/`字典_桌表.csv`）
  ——还没开始写。
