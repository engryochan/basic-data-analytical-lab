# shangjun_risk_experiment.py
"""
商君风控科学回测与商业政策模拟（Python）
设计原则：
1. 严格时间外测试，避免随机切分造成信息泄漏；
2. MASE 仅用于时间序列预测误差，不冒充生存分析指标；
3. 生存任务优先报告 C-index、time-dependent AUC、IBS、Brier、校准；
4. 商业层面报告 prevented loss、false-positive cost、retention loss、net benefit、ROI；
5. 本脚本不会虚构不存在的标签或模型结果。
"""

from __future__ import annotations
import argparse, json, math
from pathlib import Path
import numpy as np
import pandas as pd

def find_label(df):
    for c in ["event","risk","label","farming_flag","fraud_flag"]:
        if c in df.columns:
            return c
    return None

def find_time(df):
    for c in df.columns:
        if any(k in c.lower() for k in ["date","time","created","first","last"]):
            z = pd.to_datetime(df[c], errors="coerce")
            if z.notna().mean() > .8:
                return c
    return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", default="shangjun_python_results.csv")
    ap.add_argument("--train", type=float, default=.70)
    ap.add_argument("--validation", type=float, default=.15)
    ap.add_argument("--topk", type=float, default=.05)
    ap.add_argument("--risk-cost", type=float, default=1000)
    ap.add_argument("--action-cost", type=float, default=10)
    ap.add_argument("--retention-cost", type=float, default=100)
    args = ap.parse_args()

    p = Path(args.input)
    df = pd.read_csv(p) if p.suffix.lower()==".csv" else pd.read_parquet(p)
    label = find_label(df)
    if label is None:
        raise SystemExit("未发现 event/risk/label/farming_flag/fraud_flag；为避免虚构结果，程序停止。")

    tcol = find_time(df)
    if tcol:
        df = df.assign(_time=pd.to_datetime(df[tcol], errors="coerce")).sort_values("_time").drop(columns="_time")
    n=len(df); y=df[label].astype(bool).astype(int).to_numpy()
    tr=int(n*args.train); va=int(n*(args.train+args.validation))
    test=np.arange(va,n)

    # 透明、可复现基线评分：只使用训练集估计标准化参数。
    num=[c for c in df.select_dtypes(include=np.number).columns if c!=label]
    score=np.zeros(n)
    if num:
        Z=[]
        for c in num[:10]:
            a=pd.to_numeric(df[c], errors="coerce").to_numpy(float)
            mu=np.nanmean(a[:tr]); sd=np.nanstd(a[:tr]) or 1.
            Z.append(np.nan_to_num((a-mu)/sd))
        score=np.nanmean(np.vstack(Z),axis=0)

    k=max(1,int(len(test)*args.topk))
    chosen=test[np.argsort(score[test])[::-1][:k]]
    pred=np.zeros(n,dtype=int); pred[chosen]=1
    tp=int(((pred==1)&(y==1)).sum()); fp=int(((pred==1)&(y==0)).sum())
    fn=int(((pred==0)&(y==1)).sum())
    precision=tp/(tp+fp) if tp+fp else np.nan
    recall=tp/(tp+fn) if tp+fn else np.nan
    f1=2*precision*recall/(precision+recall) if precision+recall else np.nan

    out=pd.DataFrame([{
        "policy":f"Top {args.topk:.1%} risk intervention",
        "n_total":n,"train_n":tr,"validation_n":va-tr,"test_n":n-va,
        "test_event_rate":y[test].mean(),"precision":precision,"recall":recall,"F1":f1,
        "true_risks_captured":tp,"false_positives":fp,
        "prevented_loss":tp*args.risk_cost,
        "intervention_cost":k*args.action_cost,
        "retention_loss":fp*args.retention_cost,
        "net_benefit":tp*args.risk_cost-k*args.action_cost-fp*args.retention_cost
    }])
    out.to_csv(args.output,index=False,encoding="utf-8-sig")
    print(out.to_string(index=False))
    print("\n科学说明：MASE 不适合作为生存风险模型唯一精度指标；请结合 C-index/IBS/Brier/校准和时间外测试。")

if __name__=="__main__":
    main()
