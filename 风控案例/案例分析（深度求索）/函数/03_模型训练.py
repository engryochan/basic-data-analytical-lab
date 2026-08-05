# ============================================================
# 文件：03_模型训练.py
# 用途：XGBoost 生存模型训练与评估
# 作者：OGDIL 实验室
# 日期：2026-07-29
# ============================================================

import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sksurv.metrics import concordance_index_censored

# 1. 读取特征集（假设已生成）
# member_features = pd.read_csv("features_member.csv")
# 此处用示例数据演示
# 假设包含字段：member_id, duration_days, event, avg_bet, max_bet, bet_count, ...

# 2. 准备训练数据
# 假设已从R或SQL导出包含生存时间、事件、特征的数据集
# 此处模拟
np.random.seed(42)
n = 10000
X = pd.DataFrame({
    'avg_bet': np.random.exponential(500, n),
    'max_bet': np.random.exponential(1000, n),
    'bet_count': np.random.poisson(20, n),
    'distinct_dealers': np.random.poisson(5, n),
    'total_profit': np.random.exponential(100, n)
})
y_time = np.random.exponential(100, n)
y_event = np.random.binomial(1, 0.3, n)

# 3. 分割训练/测试集
X_train, X_test, y_time_train, y_time_test, y_event_train, y_event_test = train_test_split(
    X, y_time, y_event, test_size=0.2, random_state=42
)

# 4. XGBoost 生存模型（Cox损失）
dtrain = xgb.DMatrix(X_train, label=y_time_train, weight=y_event_train)  # weight 用于指示事件
dtest = xgb.DMatrix(X_test)

params = {
    'objective': 'survival:cox',
    'eval_metric': 'cox-nloglik',
    'max_depth': 4,
    'eta': 0.1,
    'subsample': 0.8,
    'colsample_bytree': 0.8,
    'seed': 42
}

# 使用早停
watchlist = [(dtrain, 'train'), (dtest, 'eval')]
model = xgb.train(
    params,
    dtrain,
    num_boost_round=1000,
    evals=watchlist,
    early_stopping_rounds=50,
    verbose_eval=50
)

# 5. 评估
pred_risk = model.predict(dtest)
c_index = concordance_index_censored(y_event_test.astype(bool), y_time_test, -pred_risk)[0]
print(f"Test C-index: {c_index:.4f}")

# 6. 特征重要性
importance = model.get_score(importance_type='gain')
importance_df = pd.DataFrame({
    'feature': list(importance.keys()),
    'gain': list(importance.values())
}).sort_values('gain', ascending=False)
print(importance_df.head())

# 7. 保存模型
model.save_model('xgb_survival_model.json')
importance_df.to_csv('feature_importance.csv', index=False)
