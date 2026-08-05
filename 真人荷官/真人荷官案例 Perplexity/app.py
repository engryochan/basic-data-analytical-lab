import streamlit as st
import pandas as pd
import plotly.express as px
from pathlib import Path

DATA_PATH = "C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/数据库/dealer_profit_stat_hourly.csv"

@st.cache_data
def load_data():
    df = pd.read_csv(DATA_PATH)
    # 解析时间字段
    for col in ["first_bet_time", "last_bet_time", "created_time", "update_time"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df

def main():
    st.set_page_config(
        page_title="Dealer Profit Risk Dashboard",
        layout="wide"
    )

    st.title("🔮 Dealer Profit Risk Dashboard")
    st.markdown("基于小时快照的荷官–玩家获利风控监控（Streamlit 闪霓应用原型）")

    df = load_data()

    # 侧边筛选
    st.sidebar.header("筛选条件")
    dealer_ids = sorted(df["dealer_id"].unique())
    dealer_selected = st.sidebar.multiselect("荷官 ID", dealer_ids, default=dealer_ids)

    game_ids = sorted(df["game_id"].unique())
    game_selected = st.sidebar.multiselect("游戏 ID", game_ids, default=game_ids)

    risk_levels = sorted(df["risk_level"].dropna().unique())
    risk_selected = st.sidebar.multiselect(
        "风险等级",
        risk_levels,
        default=risk_levels if risk_levels else []
    )

    # 时间范围（按 last_bet_time）
    min_time = df["last_bet_time"].min()
    max_time = df["last_bet_time"].max()
    if pd.notna(min_time) and pd.notna(max_time):
        time_range = st.sidebar.date_input(
            "最近下注时间范围",
            value=[min_time.date(), max_time.date()]
        )
    else:
        time_range = None

    # 应用筛选
    mask = df["dealer_id"].isin(dealer_selected) & df["game_id"].isin(game_selected)
    if risk_selected:
        mask &= df["risk_level"].isin(risk_selected)

    if time_range and len(time_range) == 2:
        start_date, end_date = time_range
        mask &= (df["last_bet_time"].dt.date >= start_date) & (df["last_bet_time"].dt.date <= end_date)

    df_filtered = df[mask].copy()

    st.subheader("数据总览")
    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric("记录数", len(df_filtered))
    with col2:
        st.metric("总下注次数", int(df_filtered["bet_count"].sum()))
    with col3:
        st.metric("总盈利（profit）", f"{df_filtered['profit'].sum():,.2f}")
    with col4:
        avg_roi = df_filtered["player_roi"].mean() if "player_roi" in df_filtered.columns else None
        st.metric("平均玩家 ROI", f"{avg_roi:.4f}" if avg_roi is not None else "N/A")

    st.markdown("---")

    # 1. 时间序列：盈利 / ROI 随时间变化
    st.subheader("📈 盈利与 ROI 时间序列")

    if "last_bet_time" in df_filtered.columns:
        ts_df = df_filtered.sort_values("last_bet_time")
        ts_df["date"] = ts_df["last_bet_time"].dt.date

        # 按日聚合
        agg_ts = ts_df.groupby("date", as_index=False).agg(
            total_profit=("profit", "sum"),
            avg_player_roi=("player_roi", "mean"),
            bet_count=("bet_count", "sum")
        )

        fig_profit = px.line(
            agg_ts,
            x="date",
            y="total_profit",
            title="每日总盈利",
            labels={"date": "日期", "total_profit": "总盈利"}
        )
        fig_roi = px.line(
            agg_ts,
            x="date",
            y="avg_player_roi",
            title="每日平均玩家 ROI",
            labels={"date": "日期", "avg_player_roi": "平均 ROI"}
        )

        col_p1, col_p2 = st.columns(2)
        with col_p1:
            st.plotly_chart(fig_profit, use_container_width=True)
        with col_p2:
            st.plotly_chart(fig_roi, use_container_width=True)
    else:
        st.warning("数据中缺少 last_bet_time 字段，无法绘制时间序列。")

    st.markdown("---")

    # 2. 分布视角：盈利分布 / ROI 分布
    st.subheader("📊 盈利与 ROI 分布视图")

    col_d1, col_d2 = st.columns(2)

    with col_d1:
        fig_hist_profit = px.histogram(
            df_filtered,
            x="profit",
            nbins=50,
            title="盈利分布直方图",
            labels={"profit": "盈利"}
        )
        st.plotly_chart(fig_hist_profit, use_container_width=True)

    with col_d2:
        if "player_roi" in df_filtered.columns:
            fig_hist_roi = px.histogram(
                df_filtered,
                x="player_roi",
                nbins=50,
                title="玩家 ROI 分布直方图",
                labels={"player_roi": "玩家 ROI"}
            )
            st.plotly_chart(fig_hist_roi, use_container_width=True)
        else:
            st.info("数据中缺少 player_roi 字段。")

    st.markdown("---")

    # 3. 风险等级分布
    st.subheader("⚠️ 风险等级分布")

    if "risk_level" in df_filtered.columns:
        risk_df = df_filtered["risk_level"].value_counts().reset_index()
        risk_df.columns = ["risk_level", "count"]

        fig_risk_bar = px.bar(
            risk_df,
            x="risk_level",
            y="count",
            title="风险等级记录数",
            labels={"risk_level": "风险等级", "count": "记录数"}
        )
        st.plotly_chart(fig_risk_bar, use_container_width=True)
    else:
        st.info("数据中缺少 risk_level 字段。")

    st.markdown("---")

    # 4. Top-N 风险玩家列表
    st.subheader("👑 Top 风险玩家")

    if "risk_score" in df_filtered.columns:
        top_n = st.slider("显示前 N 名风险玩家", min_value=10, max_value=200, value=50, step=10)

        top_df = (
            df_filtered
            .sort_values("risk_score", ascending=False)
            .head(top_n)[
                [
                    "dealer_id",
                    "game_id",
                    "player_id",
                    "bet_count",
                    "valid_bet",
                    "turnover",
                    "profit",
                    "profit_per_bet",
                    "win_rate",
                    "player_roi",
                    "risk_score",
                    "risk_level",
                    "first_bet_time",
                    "last_bet_time",
                ]
            ]
        )

        st.dataframe(top_df, use_container_width=True)
    else:
        st.info("数据中缺少 risk_score 字段。")


if __name__ == "__main__":
    main()
    
