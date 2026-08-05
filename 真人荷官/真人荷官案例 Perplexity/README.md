# Dealer Profit Risk Dashboard (Streamlit 闪霓应用)

## 功能概览

- 从 `data/dealer_profit_stat_hourly.csv` 读取荷官–玩家获利小时快照数据。
- 提供按荷官、游戏、风险等级、时间范围的筛选。
- 展示总览指标：记录数、总下注次数、总盈利、平均玩家 ROI。
- 绘制：
  - 盈利与 ROI 的时间序列。
  - 盈利分布和玩家 ROI 分布直方图。
  - 风险等级分布柱状图。
  - Top-N 风险玩家明细表。

## 运行方式

1. 创建虚拟环境并安装依赖：

   ```bash
   uv venv
   .venv\Scripts\activate
   uv pip install -r requirements.txt
   ```

2. 启动应用：

   ```bash
   streamlit run app.py
   ```

3. 浏览器访问提示的本地地址（通常是 `http://localhost:8501`）。
