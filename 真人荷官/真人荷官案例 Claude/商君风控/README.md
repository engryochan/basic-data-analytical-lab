# 商君风控科学实验三件套

本包包含：
1. `app/app.R`：一键启动 Shiny 风控回测与商业政策模拟应用
2. `python/shangjun_risk_experiment.py`：Python 版回测与政策模拟
3. `report/shangjun_scientific_experiment_report.qmd`：科学实验报告

重要说明：
- 本环境当前未暴露用户所称压缩包的可直接读取内容，因此没有伪造“已完成真实数据回测”的结果。
- 代码会优先读取真实数据；没有真实标签时会明确停止监督评价，避免虚报。
- MASE 不作为生存模型唯一指标。
- 正式实验应采用时间外测试、bootstrap CI、校准、C-index/IBS/Brier、PR-AUC、Top-K Lift 与商业净收益。

检测到的 /mnt/data ZIP 文件：
[
  {
    "file": "真人荷官案例 Claude(1).zip",
    "members": 51,
    "examples": [
      "真人荷官案例 Claude/",
      "真人荷官案例 Claude/app.R",
      "真人荷官案例 Claude/app_pro_max.R",
      "真人荷官案例 Claude/data/",
      "真人荷官案例 Claude/data/dealer_profit_stat.csv",
      "真人荷官案例 Claude/data/dealer_profit_stat_hourly.csv",
      "真人荷官案例 Claude/data/player_pair_stat.csv",
      "真人荷官案例 Claude/data/player_pair_stat_hourly.csv",
      "真人荷官案例 Claude/data_full/",
      "真人荷官案例 Claude/data_full/bayes_model.rds",
      "真人荷官案例 Claude/data_full/bayes_model_cmdstan.rds",
      "真人荷官案例 Claude/data_full/centrality_dt.rds",
      "真人荷官案例 Claude/data_full/dealer_profit_stat.csv",
      "真人荷官案例 Claude/data_full/dealer_profit_stat_hourly.csv",
      "真人荷官案例 Claude/data_full/EV行为偏离_地毯式全部记录.csv",
      "真人荷官案例 Claude/data_full/freq_model.rds",
      "真人荷官案例 Claude/data_full/gravity_bayes.rds",
      "真人荷官案例 Claude/data_full/loo_result.rds",
      "真人荷官案例 Claude/data_full/player_pair_stat.csv",
      "真人荷官案例 Claude/data_full/player_pair_stat_hourly.csv",
      "真人荷官案例 Claude/data_full/pps.rds",
      "真人荷官案例 Claude/data_full/rsf_fit.rds",
      "真人荷官案例 Claude/data_full/三方法交叉验证_最高优先级复核清单_全部10万条.csv",
      "真人荷官案例 Claude/data_full/双方法交叉验证_最高优先级复核清单.csv",
      "真人荷官案例 Claude/data_full/图论团伙头目识别_地毯式全部节点.csv",
      "真人荷官案例 Claude/data_full/客户分级地毯式全量_全部玩家.csv",
      "真人荷官案例 Claude/data_full/流水极端异常账号_待核实清单.csv",
      "真人荷官案例 Claude/data_full/玩家配对Autoencoder异常检测_全部10万条.csv",
      "真人荷官案例 Claude/data_full/玩家配对XGBoost残差评分_全部10万条.csv",
      "真人荷官案例 Claude/data_full/玩家配对地毯式生存风险评分_全部10万条.csv"
    ]
  }
]
