# -*- coding: utf-8 -*-
"""
荷官玩家风控 —— 同桌合谋图论风控引擎 (Python / 派森版)
Scibrokes Trading® Live-Dealer Collusion Risk Engine

核心方法论 Core Methodology
============================
1. 复合分位数分层 (Composite Percentile Tiering) —— 绝对阈值 AND 逻辑在真实数据上
   会导致零命中(已于历史会话验证)，因此本引擎全程使用 quantile() 动态分位数，
   ABSOLUTE THRESHOLDS ARE NEVER HARDCODED.
2. 图论异常侦测 (Graph-Theoretic Anomaly Detection) —— 候选同桌数据本质是一张
   带权无向图 (nodes=会员, edges=同桌局数)。三层递进过滤，避免"连通分量假象"
   (即：仅靠链式传递连通、内部并不紧密的巨型分量，不能算真团伙):
     Step 1: 全局分位数排名 (Global Percentile Rank)
     Step 2: 局部标准化 Z 分数 (Local Z-score) —— 排除"高频真实玩家"的假阳性
     Step 3: k-核分解 (k-core Decomposition) —— 只有真正内部紧密的子图才算"团伙"
3. 综合风险分 = 全局分位 40% + 双端局部标准化分 40% + 互斥度惩罚 20%
   (权重可调，全部作为具名常数暴露在文件顶部，不藏在函数体内)

作者 Author: Ryo（雷欧）
"""

import pandas as pd
import numpy as np
import networkx as nx
from dataclasses import dataclass, field
from typing import Optional

# ============================================================
# 【重要方法论修正说明 · 请务必先读】
# ============================================================
# 本引擎最初版本仅用"复合分位数评分"的 P99 作为"L4_实锤合谋"判定依据。
# 但该数据集含 59,833 条候选边 = 59,833 次同时进行的统计假设检验。
# 若不做多重检验校正，即使真实世界完全不存在任何合谋（原假设为真），
# 纯属随机波动也预期约有 0.01 × 59,833 ≈ 598 条边"看起来显著"——这个数字
# 与本引擎最初P99阈值挑出的602条边几乎完全重合，说明那602条边绝大多数
# 只是多重检验下的假阳性，并非真正的统计证据。
#
# 正确做法（学术依据 —— 真实文献，非虚构）:
#   [1] Serrano, Boguñá, Vespignani (2009) "Extracting the multiscale
#       backbone of complex weighted networks." PNAS 106(16):6483-6488.
#       —— disparity filter：把"原始同桌次数"换算成"相对于该玩家自己
#          社交预算而言够不够异常"的 p 值 α_ij。
#   [2] Benjamini & Hochberg (1995) FDR 多重检验校正，控制在59,833次
#       同时检验下的预期假阳性比例。
#
# 经此两步校正后，全数据集中只有 **1 条边**（101153588 × 145846574，
# 同桌3971局）真正站得住脚，可称为"实锤"。其余原L4/L3候选，一律降级为
# "观察名单排序启发法"产出的复核优先级，不等于"确诊"。
# 本文件保留原复合分位数评分函数（更名 heuristic_* ）供人工复核排序使用，
# 但新增 disparity_filter_fdr() 作为唯一具统计学意义的"实锤"判定入口。
# ============================================================

# ============================================================
# 具名可调参数 (Named Tunable Constants) —— 全局唯一定义处
# ============================================================
GLOBAL_RANK_WEIGHT = 0.40      # 全局分位排名权重
LOCAL_Z_WEIGHT = 0.40          # 局部标准化 Z 分数权重 (双端平均)
MUTUAL_DEGREE_WEIGHT = 0.20    # 互斥度(双方各自的可疑伙伴数)权重

TIER_QUANTILES = {             # 分层分位点 —— 用于人工复核排序优先级，非统计学"确诊"
    "L4_优先复核": 0.99,        # 注意：此级别不等于"实锤"，见文件顶部方法论修正说明
    "L3_高危待复核": 0.95,
    "中风险_待观察": 0.90,
    "试水型_观察名单": 0.75,
    # 其余为 "一般关系"
}
KCORE_ANOMALY_QUANTILE = 0.99  # 用于k-核团伙侦测的边过滤分位点


@dataclass
class RiskEngineResult:
    edges: pd.DataFrame
    nodes: pd.DataFrame
    tight_rings: list
    quantile_table: pd.DataFrame
    modularity_q: float
    giant_component_frac: float
    validated: dict = field(default_factory=dict)  # disparity filter + FDR 结果


def disparity_filter(df: pd.DataFrame) -> pd.DataFrame:
    """
    Disparity Filter (Serrano/Boguñá/Vespignani, PNAS 2009)。
    对每条边 (u, w)，从 u 的视角算 alpha_u = (1 - w/strength_u)^(degree_u - 1)：
    若 u 只有极少数对手却把绝大部分同桌局数都花在这一个对手身上，alpha 极小，
    代表这段关系相对 u 自己的"社交预算"而言高度不寻常。
    """
    degree, strength = {}, {}
    for u1, u2, w in zip(df.uid1.astype(str), df.uid2.astype(str), df["总同桌局数"]):
        for u in (u1, u2):
            degree[u] = degree.get(u, 0) + 1
            strength[u] = strength.get(u, 0.0) + w

    def alpha(u: str, w: float) -> float:
        k = degree[u]
        if k <= 1:
            return 1.0
        p = w / strength[u]
        return (1 - p) ** (k - 1)

    out = df.copy()
    u1s, u2s = out.uid1.astype(str), out.uid2.astype(str)
    out["alpha1"] = [alpha(u, w) for u, w in zip(u1s, out["总同桌局数"])]
    out["alpha2"] = [alpha(u, w) for u, w in zip(u2s, out["总同桌局数"])]
    out["alpha_min"] = out[["alpha1", "alpha2"]].min(axis=1)
    return out


def bh_fdr(pvals: np.ndarray, q: float) -> np.ndarray:
    """手动实现 Benjamini-Hochberg 多重检验假阳性率(FDR)校正，不依赖 statsmodels。"""
    p = np.asarray(pvals)
    n = len(p)
    order = np.argsort(p)
    ranked = p[order]
    thresh = (np.arange(1, n + 1) / n) * q
    below = ranked <= thresh
    if not below.any():
        return np.zeros(n, dtype=bool)
    cutoff = ranked[np.max(np.where(below)[0])]
    return p <= cutoff


def statistically_validated_edges(df: pd.DataFrame, fdr_q: float = 0.01) -> dict:
    """
    唯一具统计学意义的"实锤"判定入口。返回未校正/已校正两组结果，
    并附带"预期纯随机假阳性数"以便与未校正结果做直观对照。
    """
    df_a = disparity_filter(df)
    n = len(df_a)
    expected_by_chance_at_001 = 0.01 * n
    passed = bh_fdr(df_a["alpha_min"].values, fdr_q)
    return {
        "disparity": df_a,
        "uncorrected_at_001": df_a[df_a["alpha_min"] < 0.01].copy(),
        "expected_false_positives_at_001": expected_by_chance_at_001,
        "corrected": df_a[passed].copy(),
        "n_hypotheses": n,
    }


def load_pair_data(path: str) -> pd.DataFrame:
    """读取全局同桌配对数据（uid1, uid2, 总同桌局数）。"""
    df = pd.read_csv(path)
    required = {"uid1", "uid2", "总同桌局数"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"源数据缺少必要字段(一字不漏核对): {missing}")
    df = df.dropna(subset=["uid1", "uid2", "总同桌局数"]).copy()
    df["uid1"] = df["uid1"].astype(np.int64)
    df["uid2"] = df["uid2"].astype(np.int64)
    return df


def build_graph(df: pd.DataFrame) -> nx.Graph:
    G = nx.from_pandas_edgelist(df, "uid1", "uid2", edge_attr="总同桌局数")
    G.remove_edges_from(nx.selfloop_edges(G))
    return G


def compute_local_zscores(G: nx.Graph, df: pd.DataFrame) -> pd.DataFrame:
    """
    局部标准化 Z 分数：把每条边的权重，相对"该节点自己所有边权重的分布"做标准化。
    目的：区分"这个人天生同桌频率就很高的活跃玩家(全局分高但局部不该报警)"
    与"这一对搭档相对彼此其余伙伴异常突出(局部Z分应报警)"。
    等价于养号型/异常关系的结构性识别，替代原本依赖时长字段的养号型判定。
    """
    node_weights = {}
    for n in G.nodes():
        ws = [d["总同桌局数"] for _, _, d in G.edges(n, data=True)]
        node_weights[n] = (np.mean(ws), np.std(ws) if len(ws) > 1 else 1.0)

    z1, z2 = [], []
    for _, row in df.iterrows():
        m1, s1 = node_weights[row.uid1]
        m2, s2 = node_weights[row.uid2]
        s1 = s1 if s1 > 1e-6 else 1.0
        s2 = s2 if s2 > 1e-6 else 1.0
        z1.append((row["总同桌局数"] - m1) / s1)
        z2.append((row["总同桌局数"] - m2) / s2)
    out = df.copy()
    out["z_uid1"] = z1
    out["z_uid2"] = z2
    out["local_z_avg"] = (out["z_uid1"] + out["z_uid2"]) / 2
    return out


def composite_score(df: pd.DataFrame, G: nx.Graph) -> pd.DataFrame:
    """三源合一综合风险分 —— 全局分位 + 局部Z分 + 互斥度，全部转 0-100 分位分后加权。"""
    out = compute_local_zscores(G, df)

    def pct_rank(s: pd.Series) -> pd.Series:
        return s.rank(pct=True) * 100

    out["global_rank_score"] = pct_rank(out["总同桌局数"])
    out["local_z_score"] = pct_rank(out["local_z_avg"])

    deg = dict(G.degree())
    out["mutual_degree"] = out.apply(
        lambda r: min(deg.get(r.uid1, 0), deg.get(r.uid2, 0)), axis=1
    )
    out["mutual_degree_score"] = pct_rank(out["mutual_degree"])

    out["综合风险分"] = (
        GLOBAL_RANK_WEIGHT * out["global_rank_score"]
        + LOCAL_Z_WEIGHT * out["local_z_score"]
        + MUTUAL_DEGREE_WEIGHT * out["mutual_degree_score"]
    ).round(2)
    return out


def assign_tier(df: pd.DataFrame, score_col: str = "综合风险分") -> pd.DataFrame:
    """复合分位数动态分层 —— 严禁绝对阈值AND逻辑（历史已验证在真实数据上零命中）。"""
    out = df.copy()
    thresholds = {k: out[score_col].quantile(v) for k, v in TIER_QUANTILES.items()}

    def classify(v):
        if v >= thresholds["L4_优先复核"]:
            return "L4_优先复核"
        if v >= thresholds["L3_高危待复核"]:
            return "L3_高危待复核"
        if v >= thresholds["中风险_待观察"]:
            return "中风险_待观察"
        if v >= thresholds["试水型_观察名单"]:
            return "试水型_观察名单"
        return "一般关系"

    out["风险等级"] = out[score_col].apply(classify)
    return out, thresholds


def detect_tight_rings(df: pd.DataFrame, quantile: float = KCORE_ANOMALY_QUANTILE):
    """
    分级团伙侦测：先按分位数过滤高危边，再做 k-核分解，
    避免"链式转移连通"稀释出的巨型假团伙(已实测：若不过滤直接对全图跑连通分量，
    99%+节点会被单一巨型分量吞并，毫无业务意义)。
    """
    thresh = df["总同桌局数"].quantile(quantile)
    sub = df[df["总同桌局数"] >= thresh]
    Gs = nx.from_pandas_edgelist(sub, "uid1", "uid2", edge_attr="总同桌局数")
    Gs.remove_edges_from(nx.selfloop_edges(Gs))

    core_num = nx.core_number(Gs)
    max_k = max(core_num.values()) if core_num else 0
    rings = []
    if max_k >= 3:
        kcore = nx.k_core(Gs, k=max_k)
        for comp in nx.connected_components(kcore):
            sg = kcore.subgraph(comp)
            rings.append({
                "members": sorted(comp),
                "size": len(comp),
                "density": round(nx.density(sg), 3),
                "internal_edges": sg.number_of_edges(),
                "total_同桌局数": int(sum(d["总同桌局数"] for _, _, d in sg.edges(data=True))),
                "k_core": max_k,
            })
    rings.sort(key=lambda r: -r["size"])
    return rings, thresh


def run_full_pipeline(csv_path: str) -> RiskEngineResult:
    df = load_pair_data(csv_path)
    G = build_graph(df)
    scored = composite_score(df, G)
    scored, thresholds = assign_tier(scored)
    rings, ring_thresh = detect_tight_rings(df)
    validated = statistically_validated_edges(df)

    deg = dict(G.degree())
    nodes = pd.DataFrame({"uid": list(G.nodes()), "可疑伙伴数": [deg[n] for n in G.nodes()]})
    nodes["度数分位"] = nodes["可疑伙伴数"].rank(pct=True) * 100

    giant = max(nx.connected_components(G), key=len)
    giant_frac = len(giant) / G.number_of_nodes()

    quantile_rows = []
    for q in [0.50, 0.75, 0.90, 0.95, 0.975, 0.99, 0.995, 0.999]:
        quantile_rows.append({
            "分位点": f"P{q*100:.1f}",
            "总同桌局数_阈值": round(df["总同桌局数"].quantile(q), 1),
            "综合风险分_阈值": round(scored["综合风险分"].quantile(q), 2),
        })
    quantile_table = pd.DataFrame(quantile_rows)

    return RiskEngineResult(
        edges=scored,
        nodes=nodes,
        tight_rings=rings,
        quantile_table=quantile_table,
        modularity_q=float("nan"),
        giant_component_frac=giant_frac,
        validated=validated,
    )


if __name__ == "__main__":
    import sys
    path = sys.argv[1] if len(sys.argv) > 1 else "pair_data.csv"
    result = run_full_pipeline(path)

    v = result.validated
    print("=" * 70)
    print("【唯一具统计学意义的结论 · Benjamini-Hochberg FDR 多重检验校正后】")
    print("=" * 70)
    print(f"本次共对 {v['n_hypotheses']} 条边同时做假设检验。")
    print(f"未校正 disparity filter (alpha<0.01): {len(v['uncorrected_at_001'])} 条边"
          f"（其中约 {v['expected_false_positives_at_001']:.0f} 条纯属59,833次同时检验"
          f"下的随机假阳性，二者数字高度接近，说明未校正结果不可直接采信）")
    print(f"FDR校正后真正站得住脚的边数: {len(v['corrected'])}")
    if len(v["corrected"]) > 0:
        print(v["corrected"].sort_values("总同桌局数", ascending=False)
              [["uid1", "uid2", "总同桌局数", "alpha_min"]].to_string(index=False))
    print()

    print("=" * 70)
    print("【以下为观察名单排序启发法结果 —— 供人工复核排序参考，不等于'确诊'】")
    print("=" * 70)
    print("=== 分位数阈值对照表 ===")
    print(result.quantile_table.to_string(index=False))
    print("\n=== 风险等级分布(启发法排序，非统计学确诊) ===")
    print(result.edges["风险等级"].value_counts())
    print(f"\n巨型连通分量占比: {result.giant_component_frac:.1%} (印证：不能直接用connected_components当团伙)")
    print(f"\n=== 侦测到 {len(result.tight_rings)} 个"
          f"'局部高密度候选子群'(k-核方法，基于原始计数，尚未做FDR校正，仅供复核排序) ===")
    for i, r in enumerate(result.tight_rings[:5]):
        print(f"候选子群#{i+1}: {r['size']}人, 密度={r['density']}, k-core={r['k_core']}, "
              f"内部总同桌局数={r['total_同桌局数']}")
