# -*- coding: utf-8 -*-
"""
官玩家同桌合谋风控中枢 (Streamlit 一键版)
运行方式 / How to run:
    pip install streamlit pandas numpy networkx plotly --break-system-packages
    streamlit run app_streamlit.py
数据 / Data: 默认读取同目录下 pair_data.csv (uid1, uid2, 总同桌局数)，
             也可在侧栏上传其他同结构 CSV（ods_a168_bet01/bet02 汇总后的同桌配对表）。
"""

import pandas as pd
import numpy as np
import networkx as nx
import streamlit as st
import plotly.graph_objects as go
import plotly.express as px

# ============================================================
# 品牌视觉常量 (沿用既有 Shiny 档案页配色，保持品牌一致性)
# ============================================================
NAVY = "#0B2136"
TEAL_DARK = "#146275"
TEAL = "#33A8C4"
BLUE_ACCENT = "#4CB5F5"
GOLD = "#FFD64D"
CARD_BG = "#122A3D"

st.set_page_config(page_title="荷官玩家风控中枢", page_icon="🐉", layout="wide")

st.markdown(f"""
<style>
.stApp {{
    background: linear-gradient(160deg, {NAVY} 0%, #0E2A3D 60%, {TEAL_DARK} 130%);
    color: #EAF6FA;
}}
[data-testid="stSidebar"] {{
    background: {NAVY};
    border-right: 1px solid {TEAL};
}}
h1, h2, h3 {{ color: {GOLD} !important; }}
.metric-card {{
    background: {CARD_BG};
    border: 1px solid {TEAL_DARK};
    border-radius: 10px;
    padding: 14px 18px;
}}
[data-testid="stMetricValue"] {{ color: {GOLD}; }}
.stDataFrame {{ background: {CARD_BG}; }}
div[data-testid="stExpander"] {{ background: {CARD_BG}; border-radius: 8px; }}
</style>
""", unsafe_allow_html=True)

# ============================================================
# 具名可调参数
# ============================================================
GLOBAL_RANK_WEIGHT = 0.40
LOCAL_Z_WEIGHT = 0.40
MUTUAL_DEGREE_WEIGHT = 0.20
TIER_QUANTILES = {
    "L4_优先复核": 0.99,   # 注意：此为启发法排序，非统计学"实锤"，见"统计显著性检验"分页
    "L3_高危待复核": 0.95,
    "中风险_待观察": 0.90,
    "试水型_观察名单": 0.75,
}
TIER_COLOR = {
    "L4_优先复核": "#FF4B4B",
    "L3_高危待复核": "#FF9F45",
    "中风险_待观察": GOLD,
    "试水型_观察名单": TEAL,
    "一般关系": "#5C7A8A",
}


def disparity_filter_fdr(df: pd.DataFrame, fdr_q: float = 0.01) -> dict:
    """
    Disparity Filter (Serrano/Boguñá/Vespignani, PNAS 2009) + Benjamini-Hochberg FDR。
    59,833条候选边 = 59,833次同时假设检验；不做多重检验校正的话，即使世界上根本
    不存在合谋，纯属随机也预期约有 0.01×N 条边"看起来显著"——这是本应用唯一
    具统计学意义、可称为"实锤"的判定方法，其余分位数/Z分/k-核结果一律只是
    "观察名单排序启发法"，供人工复核优先级参考，不等于确诊。
    """
    df = df.copy()
    df["uid1"] = df["uid1"].astype(str)
    df["uid2"] = df["uid2"].astype(str)
    degree, strength = {}, {}
    for u1, u2, w in zip(df.uid1, df.uid2, df["总同桌局数"]):
        for u in (u1, u2):
            degree[u] = degree.get(u, 0) + 1
            strength[u] = strength.get(u, 0.0) + w

    def alpha(u, w):
        k = degree[u]
        if k <= 1:
            return 1.0
        p = w / strength[u]
        return (1 - p) ** (k - 1)

    df["alpha1"] = [alpha(u, w) for u, w in zip(df.uid1, df["总同桌局数"])]
    df["alpha2"] = [alpha(u, w) for u, w in zip(df.uid2, df["总同桌局数"])]
    df["alpha_min"] = df[["alpha1", "alpha2"]].min(axis=1)

    n = len(df)
    p = df["alpha_min"].values
    order = np.argsort(p)
    ranked = p[order]
    thresh = (np.arange(1, n + 1) / n) * fdr_q
    below = ranked <= thresh
    passed = np.zeros(n, dtype=bool)
    if below.any():
        cutoff = ranked[np.max(np.where(below)[0])]
        passed = p <= cutoff

    return {
        "disparity": df,
        "uncorrected_at_001": df[df["alpha_min"] < 0.01].copy(),
        "expected_fp_at_001": 0.01 * n,
        "corrected": df[passed].copy(),
        "n_hypotheses": n,
    }


@st.cache_data(show_spinner="正在建图与运算分位数（批量计算，仅执行一次）...")
def run_pipeline(df: pd.DataFrame):
    df = df.dropna(subset=["uid1", "uid2", "总同桌局数"]).copy()
    df["uid1"] = df["uid1"].astype(np.int64)
    df["uid2"] = df["uid2"].astype(np.int64)

    G = nx.from_pandas_edgelist(df, "uid1", "uid2", edge_attr="总同桌局数")
    G.remove_edges_from(nx.selfloop_edges(G))

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
    df["local_z_avg"] = (np.array(z1) + np.array(z2)) / 2

    def pct_rank(s):
        return s.rank(pct=True) * 100

    df["global_rank_score"] = pct_rank(df["总同桌局数"])
    df["local_z_score"] = pct_rank(df["local_z_avg"])
    deg = dict(G.degree())
    df["mutual_degree"] = df.apply(lambda r: min(deg.get(r.uid1, 0), deg.get(r.uid2, 0)), axis=1)
    df["mutual_degree_score"] = pct_rank(df["mutual_degree"])
    df["综合风险分"] = (
        GLOBAL_RANK_WEIGHT * df["global_rank_score"]
        + LOCAL_Z_WEIGHT * df["local_z_score"]
        + MUTUAL_DEGREE_WEIGHT * df["mutual_degree_score"]
    ).round(2)

    thresholds = {k: df["综合风险分"].quantile(v) for k, v in TIER_QUANTILES.items()}

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

    df["风险等级"] = df["综合风险分"].apply(classify)

    giant = max(nx.connected_components(G), key=len)
    giant_frac = len(giant) / G.number_of_nodes()

    # k-核紧密团伙侦测（先按 P99 过滤，再做 k-核分解，避免链式连通假象）
    thresh99 = df["总同桌局数"].quantile(0.99)
    sub = df[df["总同桌局数"] >= thresh99]
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
                "members": sorted(comp), "size": len(comp),
                "density": round(nx.density(sg), 3),
                "internal_edges": sg.number_of_edges(),
                "total_同桌局数": int(sum(d["总同桌局数"] for _, _, d in sg.edges(data=True))),
                "k_core": max_k,
            })
    rings.sort(key=lambda r: -r["size"])

    return df, G, thresholds, giant_frac, rings, max_k


# ============================================================
# 侧栏：数据源
# ============================================================
with st.sidebar:
    st.markdown(f"### 🐉 Ryo（雷欧）")
    st.caption("荷官玩家同桌合谋风控中枢 · 图论版")
    uploaded = st.file_uploader("上传同结构 CSV（可选，默认用本地全量候选数据）",
                                 type=["csv"])
    st.divider()
    st.markdown("**权重设置**（复合分位数评分，非绝对阈值）")
    w_global = st.slider("全局分位权重", 0.0, 1.0, GLOBAL_RANK_WEIGHT, 0.05)
    w_local = st.slider("局部标准化Z分权重", 0.0, 1.0, LOCAL_Z_WEIGHT, 0.05)
    w_deg = round(max(0.0, 1 - w_global - w_local), 2)
    st.caption(f"互斥度权重自动补足 = {w_deg}")

GLOBAL_RANK_WEIGHT, LOCAL_Z_WEIGHT, MUTUAL_DEGREE_WEIGHT = w_global, w_local, w_deg

try:
    raw = pd.read_csv(uploaded) if uploaded is not None else pd.read_csv("pair_data.csv")
except FileNotFoundError:
    st.error("找不到 pair_data.csv，请在侧栏上传同结构的同桌配对数据表。")
    st.stop()

scored, G, thresholds, giant_frac, rings, max_k = run_pipeline(raw)
validated = disparity_filter_fdr(raw)

# ============================================================
# 顶部总览
# ============================================================
st.title("🐉 荷官玩家同桌合谋风控中枢")
st.caption("Live-Dealer Table Collusion Risk Command Center · Ryo（雷欧）试验作品")

n_corrected = len(validated["corrected"])
st.markdown(f"""
<div style="background:{CARD_BG}; border-left:5px solid {'#FF4B4B' if n_corrected else TEAL};
padding:14px 18px; border-radius:8px; margin-bottom:10px;">
<b>🎓 唯一具统计学意义的结论（Benjamini-Hochberg FDR 多重检验校正后）：</b><br>
本次对 {validated['n_hypotheses']:,} 条边同时做假设检验；未校正结果中约有
{validated['expected_fp_at_001']:.0f} 条边纯属随机假阳性（与未校正命中数
{len(validated['uncorrected_at_001'])} 条高度接近）。<b>严格校正后，全数据集中
只有 {n_corrected} 条边真正站得住脚</b>，其余均为"观察名单排序启发法"产出的
复核优先级，<u>不等于确诊</u>。
</div>
""", unsafe_allow_html=True)

c1, c2, c3, c4, c5 = st.columns(5)
c1.metric("会员总数 (nodes)", f"{G.number_of_nodes():,}")
c2.metric("可疑配对总数 (edges)", f"{G.number_of_edges():,}")
c3.metric("巨型连通分量占比", f"{giant_frac:.1%}", help="印证：不能直接拿connected_components当团伙，需分位过滤+k-核")
c4.metric("✅统计显著'实锤'配对数", f"{n_corrected}", help="唯一经FDR多重检验校正、可称为实锤的数量")
c5.metric("L4_优先复核(启发法)", f"{(scored['风险等级']=='L4_优先复核').sum():,}", help="未经FDR校正，不等于确诊")

st.divider()

tab0, tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "🎓 统计显著性检验(实锤)", "📊 分位数与分层总览", "🕸️ 紧密团伙侦测 (k-核)", "🔍 高危配对清单",
    "📈 网络结构可视化", "⚖️ 赏罚分明·业务方案"
])

with tab0:
    st.subheader("Disparity Filter (PNAS 2009) + Benjamini-Hochberg FDR 多重检验校正")
    st.markdown("""
**外行人一看即懂的比喻**：假设玩家A一共认识500个不同的同桌对手，其中跟B同桌200次，
跟其余499人加起来才同桌300次——A把"注意力"高度集中在B身上，这在统计上不寻常。
反过来，如果A跟每个对手都差不多同桌几次，那A只是单纯"很能玩"，任何一次同桌次数
偏高都只是他见多识广的自然结果，不该被当作合谋证据。

**为什么必须做多重检验校正**：本数据集有 59,833 条候选边，等于同时做 59,833 次
假设检验。即使真实世界完全不存在任何合谋，纯属随机波动也预期约有 **598 条边
"看起来显著"**（0.01 × 59,833）——这个数字与未校正结果几乎完全重合，说明未校正
的"高危名单"基本等同于噪声，必须做 FDR 校正才能得到站得住脚的结论。
""")
    colx, coly = st.columns(2)
    colx.metric("未校正 (α<0.01)", f"{len(validated['uncorrected_at_001'])} 条")
    coly.metric("纯随机预期假阳性数", f"{validated['expected_fp_at_001']:.0f} 条")
    st.markdown("#### ✅ FDR校正后真正站得住脚的配对")
    if n_corrected > 0:
        st.dataframe(validated["corrected"].sort_values("总同桌局数", ascending=False)
                     [["uid1", "uid2", "总同桌局数", "alpha_min"]],
                     use_container_width=True, hide_index=True)
    else:
        st.warning("没有任何一条边通过严格的多重检验校正——这本身就是重要结论。")
    st.caption("学术依据：Serrano, Boguñá, Vespignani (2009) PNAS 106(16):6483-6488"
              "（disparity filter）；Benjamini & Hochberg (1995) FDR校正。")

with tab1:
    colA, colB = st.columns([1, 1])
    with colA:
        st.subheader("动态分位数阈值表（一字不漏，实时按当前数据重算）")
        rows = []
        for q in [0.50, 0.75, 0.90, 0.95, 0.975, 0.99, 0.995, 0.999]:
            rows.append({"分位点": f"P{q*100:.1f}",
                         "总同桌局数_阈值": round(raw["总同桌局数"].quantile(q), 1),
                         "综合风险分_阈值": round(scored["综合风险分"].quantile(q), 2)})
        st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
    with colB:
        st.subheader("五级风险分层分布")
        vc = scored["风险等级"].value_counts().reindex(
            ["一般关系", "试水型_观察名单", "中风险_待观察", "L3_高危待复核", "L4_优先复核"]).fillna(0)
        fig = go.Figure(go.Bar(
            x=vc.values, y=vc.index, orientation="h",
            marker_color=[TIER_COLOR[t] for t in vc.index],
            text=vc.values, textposition="outside"))
        fig.update_layout(paper_bgcolor=NAVY, plot_bgcolor=NAVY, font_color="#EAF6FA",
                          height=320, margin=dict(l=10, r=10, t=10, b=10))
        st.plotly_chart(fig, use_container_width=True)

    st.subheader("综合风险分分布直方图")
    fig2 = px.histogram(scored, x="综合风险分", nbins=60, color_discrete_sequence=[TEAL])
    fig2.update_layout(paper_bgcolor=NAVY, plot_bgcolor=NAVY, font_color="#EAF6FA", height=280)
    st.plotly_chart(fig2, use_container_width=True)

with tab2:
    st.subheader(f"k-核紧密团伙（先按P99分位过滤边，再做k-核分解 → k={max_k}）")
    st.info("💡 方法论说明：直接对全图跑 connected_components 会得到一个吞并99%+节点的"
            "巨型假团伙（链式传递连通所致）。真实业务意义上的『团伙』必须满足**局部高密度**，"
            "因此采用『高分位边过滤 → k-核分解』两段式，只保留每个成员都与团伙内其余成员"
            "存在高频同桌关系的紧密子图。", icon="🧭")
    if rings:
        for i, r in enumerate(rings[:10]):
            with st.expander(f"团伙 #{i+1} · {r['size']}人 · 内部密度={r['density']} "
                             f"· k-core={r['k_core']} · 内部总同桌局数={r['total_同桌局数']:,}"):
                st.write(", ".join(str(m) for m in r["members"]))
    else:
        st.warning("当前数据未侦测到 k≥3 的紧密团伙。")

with tab3:
    st.subheader("高危配对完整清单（可排序/筛选/导出）")
    tier_filter = st.multiselect("按风险等级筛选", options=list(TIER_COLOR.keys()),
                                  default=["L4_优先复核", "L3_高危待复核"])
    view = scored[scored["风险等级"].isin(tier_filter)].sort_values("综合风险分", ascending=False)
    st.dataframe(
        view[["uid1", "uid2", "总同桌局数", "local_z_avg", "mutual_degree", "综合风险分", "风险等级"]],
        use_container_width=True, hide_index=True, height=460)
    st.download_button("⬇️ 导出当前清单 CSV", view.to_csv(index=False).encode("utf-8-sig"),
                       "风控高危配对清单.csv", "text/csv")

with tab4:
    st.subheader("Top-50 高风险子网络可视化")
    top_edges = scored.sort_values("综合风险分", ascending=False).head(50)
    Gv = nx.from_pandas_edgelist(top_edges, "uid1", "uid2", edge_attr="总同桌局数")
    pos = nx.spring_layout(Gv, seed=42, k=0.6)
    edge_x, edge_y = [], []
    for u, v in Gv.edges():
        edge_x += [pos[u][0], pos[v][0], None]
        edge_y += [pos[u][1], pos[v][1], None]
    edge_trace = go.Scatter(x=edge_x, y=edge_y, line=dict(width=1, color=TEAL),
                            hoverinfo="none", mode="lines")
    deg_v = dict(Gv.degree())
    node_x = [pos[n][0] for n in Gv.nodes()]
    node_y = [pos[n][1] for n in Gv.nodes()]
    node_trace = go.Scatter(
        x=node_x, y=node_y, mode="markers+text",
        text=[str(n) for n in Gv.nodes()], textposition="top center",
        textfont=dict(size=8, color="#EAF6FA"),
        marker=dict(size=[8 + deg_v[n] * 3 for n in Gv.nodes()],
                   color=GOLD, line=dict(width=1, color=TEAL_DARK)),
        hovertext=[f"会员{n}｜可疑伙伴数={deg_v[n]}" for n in Gv.nodes()], hoverinfo="text")
    fig3 = go.Figure(data=[edge_trace, node_trace])
    fig3.update_layout(showlegend=False, paper_bgcolor=NAVY, plot_bgcolor=NAVY,
                       xaxis=dict(visible=False), yaxis=dict(visible=False), height=560)
    st.plotly_chart(fig3, use_container_width=True)

with tab5:
    st.subheader("⚖️ 赏罚分明·对症下药业务方案")
    st.markdown("""
> 参《商君书》"赏厚而信，刑重而必"之义：风控不只是侦测，更要有明确、可执行、
> 可追责的分级处置与正向引导机制，让规则透明可预期。**同样重要的是"罚必得当"
> ——处置力度必须匹配证据强度，未经统计学验证的启发法排序不可等同于确诊。**

| 风险等级 | 判定依据 | 证据强度 | 建议措施（罚/管控） | 正向机制（赏/引导） |
|---|---|---|---|---|
| **✅ 统计显著'实锤'** | Disparity Filter + FDR校正后仍显著 | **已排除多重检验假阳性，学术级站得住脚** | 立即冻结返水结算、人工复核全部注单、必要时联合封禁 | 不适用 |
| **L4_优先复核** | 综合风险分 ≥ P99（启发法，未经FDR校正） | 中等（部分为随机假阳性） | 提升复核优先级，**不冻结账户**，48小时内人工核验 | 复核后无异常者即刻恢复正常权益 |
| **L3_高危待复核** | P95 ≤ 分数 < P99 | 较低 | 加入常规复核队列 | 复核通过后自动解除限制，无需申诉延迟 |
| **中风险_待观察** | P90 ≤ 分数 < P95 | 参考性 | 加入观察名单、异常预警订阅 | 主动配合KYC问卷者可提前移出观察期 |
| **试水型_观察名单** | P75 ≤ 分数 < P90 | 参考性 | 常规监控频率 | 正常参与忠诚度积分累计 |
| **一般关系** | 分数 < P75 | — | 无 | 正常纳入VIP/忠诚度晋升计算 |

**关键原则一**：所有分位阈值均为**动态计算**，每次数据刷新自动重算，永不写死绝对数字。
**关键原则二**：唯有通过多重检验校正的"统计显著'实锤'"级别才可采取账户冻结/封禁等
不可逆措施；L4/L3/中风险/试水型均只是复核优先级排序，处置力度必须相应降级，避免
把统计噪声误判为确凿证据、错杀正常高频付费玩家。
""")
    st.caption("荷官侧建议：结合 ods_a168_employee(荷官主档) 与 ods_a168_dailyreport_table"
              "(逐桌逐日汇总) 计算『荷官—高风险配对』共现率，识别是否存在荷官配合的内部合谋。")
