import pandas as pd
from sqlalchemy import create_engine
from datetime import datetime


class DatabaseQuery:
    def __init__(self, host: str, port: int, user: str, password: str,
                 site_id: int = 1000, start_date: str = '2025-01-01', end_date: str = '2025-01-01',
                 start_month: str = '2025-01', end_month: str = '2025-01',
                 agent_names: list = None, filter_by_agent: bool = False,
                 calculate_effective_first_deposit: bool = True):
        connection_string = f"mysql+mysqlconnector://{user}:{password}@{host}:{port}/"
        self.engine = create_engine(connection_string)

        self.site_id = site_id
        self.start_date = start_date
        self.end_date = end_date
        self.start_month = start_month
        self.end_month = end_month
        self.agent_names = agent_names or []
        self.filter_by_agent = filter_by_agent
        self.calculate_effective_first_deposit = calculate_effective_first_deposit

    def close_connections(self):
        if self.engine:
            self.engine.dispose()

    def _get_agent_hierarchy_and_member_mapping(self) -> pd.DataFrame:
        query = f"""
        SELECT DISTINCT
            a1_ad.group_name AS '1级',
            a1_ad_2.group_name AS '2级',
            a1_ad_3.group_name AS '3级',
            a1_ad_4.group_name AS '4级',
            a1_adm.member_id AS '代理ID'
        FROM agent_1000.agent_department a1_ad
        LEFT JOIN agent_1000.agent_department a1_ad_2
            ON a1_ad_2.pid = a1_ad.id
        LEFT JOIN agent_1000.agent_department a1_ad_3
            ON a1_ad_3.pid = a1_ad_2.id
        LEFT JOIN agent_1000.agent_department a1_ad_4
            ON a1_ad_4.pid = a1_ad_3.id
        LEFT JOIN agent_1000.agent_dept_member a1_adm
            ON a1_adm.dept_id = COALESCE(a1_ad_4.id, a1_ad_3.id, a1_ad_2.id, a1_ad.id)
            AND a1_adm.site_id = a1_ad.site_id
        WHERE
            a1_ad.level = 1
            AND a1_ad.site_id = {self.site_id}
            AND a1_adm.site_id = {self.site_id}
        """
        # AND a1_ad.group_name = '推广中心'
        # AND a1_ad_2.group_name IN ('推广部', '招商部')
        # AND a1_ad_3.group_name IN ('推广2部', '推广4部', '推广8部', '推广10部')
        # AND a1_ad_4.group_name IN ('推广1部1组', '推广2部1组', '推广4部1组', '推广4部2组', '推广5部1组')
        return pd.read_sql(query, self.engine)

    def _get_agent_maintain_mapping(self) -> pd.DataFrame:
        query = f"""
        SELECT member_id AS '代理ID', develop_name AS '发展人'
        FROM agent_1000.member_agent
        WHERE site_id = {self.site_id}
        """
        return pd.read_sql(query, self.engine)

    def _get_agent_parent_mapping(self) -> pd.DataFrame:
        query = f"""
        SELECT
            ma1.member_id AS '代理ID',
            ma2.agent_name AS '上级代理名称'
        FROM agent_1000.member_agent ma1
        LEFT JOIN agent_1000.member_agent ma2
            ON ma1.top_id = ma2.member_id
            AND ma2.site_id = {self.site_id}
        WHERE ma1.site_id = {self.site_id}
        """
        return pd.read_sql(query, self.engine)

    def _get_daily_report_stats(self) -> pd.DataFrame:
        query = f"""
        SELECT
            statics_date AS 日期,
            top_id AS 代理ID,
            invite_code AS 代理编号,
            agent_name AS 代理名称,
            CASE sys_type
                WHEN 1 THEN '官方代理'
                WHEN 0 THEN '普通代理'
                ELSE '未知类型'
            END AS 代理类型,
            register_member_count AS 注册人数,
            first_recharge_member_count AS 首存人数,
            first_recharge_amount AS 首存额,
            per_first_recharge AS 人均首存,
            first_recharge_register_ratio AS 转化率,
            first_valid_recharge_member_count AS 有效首存人数,
            first_valid_recharge_amount AS 有效首存金额,
            recharge_member_count AS 存款人数,
            recharge_amount AS 存款额,
            drawing_member_count AS 取款人数,
            drawing_amount AS 取款额,
            bet_member_count_settle AS 投注人数,
            bet_amount_settle AS 投注额,
            valid_bet_amount_settle AS 有效投注额,
            (net_amount_settle - early_settle_net_amount_settle) AS 公司输赢,
            early_settle_net_amount_settle AS 提前结算,
            net_bet_amount_ratio_settle AS 盈余比例,
            dividend_amount AS 红利,
            rebate_amount AS 返水,
            (per_commission_amount + team_commission_amount) AS 代理佣金,
            win_loss_adjust_amount AS 输赢调整,
            system_adjust_amount AS 系统调整,
            score_adjust AS 分数调整,
            repair_net_profit AS 补调金额,
            (net_amount_settle + win_loss_adjust_amount + system_adjust_amount - dividend_amount - rebate_amount - per_commission_amount - team_commission_amount) AS 推广收入,
            company_win_lose_settle AS 公司收入
        FROM
            bigdata.top_daily_report
        WHERE
           statics_date BETWEEN '{self.start_date}' AND '{self.end_date}'
           AND site_id = {self.site_id}
        """
        return pd.read_sql(query, self.engine)

    def _get_monthly_report_stats(self) -> pd.DataFrame:
        query = f"""
        SELECT
            statics_month AS 月份,
            top_id AS 代理ID,
            invite_code AS 代理编号,
            agent_name AS 代理名称,
            CASE sys_type
                WHEN 1 THEN '官方代理'
                WHEN 0 THEN '普通代理'
                ELSE '未知类型'
            END AS 代理类型,
            register_member_count AS 注册人数,
            first_recharge_member_count AS 首存人数,
            first_recharge_amount AS 首存额,
            per_first_recharge AS 人均首存,
            first_recharge_register_ratio AS 转化率,
            first_valid_recharge_member_count AS 有效首存人数,
            first_valid_recharge_amount AS 有效首存金额,
            recharge_member_count AS 存款人数,
            recharge_amount AS 存款额,
            drawing_member_count AS 取款人数,
            drawing_amount AS 取款额,
            bet_member_count_settle AS 投注人数,
            bet_amount_settle AS 投注额,
            valid_bet_amount_settle AS 有效投注额,
            (net_amount_settle - early_settle_net_amount_settle) AS 公司输赢,
            early_settle_net_amount_settle AS 提前结算,
            net_bet_amount_ratio_settle AS 盈余比例,
            dividend_amount AS 红利,
            rebate_amount AS 返水,
            (per_commission_amount + team_commission_amount) AS 代理佣金,
            win_loss_adjust_amount AS 输赢调整,
            system_adjust_amount AS 系统调整,
            score_adjust AS 分数调整,
            repair_net_profit AS 补调金额,
            deposit_fee AS 存款手续费,
            withdraw_fee AS 取款手续费,
            venue_amount_settle AS 场馆费,
            (net_amount_settle + win_loss_adjust_amount + system_adjust_amount - dividend_amount - rebate_amount - per_commission_amount - team_commission_amount) AS 推广收入,
            company_win_lose_settle AS 公司收入,
            (net_amount_settle + win_loss_adjust_amount - dividend_amount - rebate_amount - venue_amount_settle - deposit_fee - withdraw_fee) AS 净输赢
        FROM
            bigdata.top_month_report
        WHERE
           statics_month BETWEEN '{self.start_month}' AND '{self.end_month}'
           AND site_id = {self.site_id}
        """
        return pd.read_sql(query, self.engine)

    def _get_custom_qfd_stats(self, report_type: str) -> pd.DataFrame:
        if report_type == 'daily':
            date_filter = f"DATE(mds.first_deposit_time) BETWEEN '{self.start_date}' AND '{self.end_date}'"
            select_date_col = 'DATE(mds.first_deposit_time) AS stat_date'
        else:
            date_filter = f"DATE_FORMAT(mds.first_deposit_time, '%Y-%m') BETWEEN '{self.start_month}' AND '{self.end_month}'"
            select_date_col = "DATE_FORMAT(mds.first_deposit_time, '%Y-%m') AS stat_date"

        query = f"""
        SELECT
            {select_date_col},
            mds.top_id AS agent_id,
            COUNT(DISTINCT mds.member_id) AS new_first_recharge_member_count,
            SUM(mds.first_deposit_amount) AS new_first_recharge_amount
        FROM bigdata.member_daily_statics mds
        WHERE {date_filter}
          AND mds.first_deposit_amount >= 100
          AND mds.site_id = {self.site_id}
        GROUP BY stat_date, agent_id
        """
        return pd.read_sql(query, self.engine)

    def _get_custom_efd_stats(self, report_type: str) -> pd.DataFrame:
        if report_type == 'daily':
            date_filter = f"fvmd.first_valid_date BETWEEN '{self.start_date}' AND '{self.end_date}'"
            select_date_col = 'fvmd.first_valid_date AS stat_date'
            cumulative_date_filter = f"mds.statics_date <= '{self.end_date}'"
        else:
            date_filter = f"DATE_FORMAT(fvmd.first_valid_date, '%Y-%m') BETWEEN '{self.start_month}' AND '{self.end_month}'"
            select_date_col = "DATE_FORMAT(fvmd.first_valid_date, '%Y-%m') AS stat_date"
            cumulative_date_filter = f"mds.statics_date <= LAST_DAY('{self.end_month}-01')"

        query = f"""
        WITH CumulativeStats AS (
            SELECT
                mds.member_id,
                mds.statics_date,
                mds.top_id,
                SUM(mds.deposit) OVER (PARTITION BY mds.member_id ORDER BY mds.statics_date) AS cumulative_deposit,
                SUM(mds.bets) OVER (PARTITION BY mds.member_id ORDER BY mds.statics_date) AS cumulative_bets
            FROM bigdata.member_daily_statics mds
            WHERE mds.site_id = {self.site_id}
              AND {cumulative_date_filter}
        ),
        FirstValidMemberDate AS (
            SELECT
                member_id,
                top_id,
                MIN(statics_date) AS first_valid_date
            FROM CumulativeStats
            WHERE cumulative_deposit >= 100
              AND cumulative_bets >= 500
            GROUP BY member_id, top_id
        ),
        MemberFirstDepositAmount AS (
            SELECT
                member_id,
                MIN(first_deposit_amount) AS first_deposit_amount
            FROM bigdata.member_daily_statics
            WHERE first_deposit_amount > 0
              AND site_id = {self.site_id}
            GROUP BY member_id
        )
        SELECT
            {select_date_col},
            fvmd.top_id AS agent_id,
            COUNT(DISTINCT fvmd.member_id) AS calculated_valid_first_recharge_member_count,
            COALESCE(SUM(mfda.first_deposit_amount), 0) AS calculated_valid_first_recharge_amount
        FROM FirstValidMemberDate fvmd
        LEFT JOIN MemberFirstDepositAmount mfda ON fvmd.member_id = mfda.member_id
        WHERE {date_filter}
        GROUP BY stat_date, agent_id
        """
        return pd.read_sql(query, self.engine)


def aggregate_report_data(base_df: pd.DataFrame, group_cols: list, report_type: str) -> pd.DataFrame:
    date_col = '日期' if report_type == 'daily' else '月份'

    sum_cols = [
        '注册人数', '首存人数', '首存额', '有效首存人数', '有效首存金额',
        '存款人数', '取款人数', '存款额', '取款额', '投注人数', '投注额',
        '有效投注额', '公司输赢', '红利', '补调金额', '返水', '代理佣金',
        '提前结算', '输赢调整', '系统调整', '分数调整', '推广收入', '公司收入'
    ]
    if report_type == 'monthly':
        sum_cols.extend(['存款手续费', '取款手续费', '场馆费', '净输赢'])

    for col in sum_cols:
        if col not in base_df.columns:
            base_df[col] = 0.0
        else:
            base_df[col] = pd.to_numeric(base_df[col], errors='coerce').fillna(0.0)

    agg_dict = {col: 'sum' for col in sum_cols}

    agg_df = base_df.groupby(group_cols, observed=True).agg(agg_dict).reset_index()

    is_agent_level_report_final = '代理ID' in group_cols

    if not is_agent_level_report_final:
        agent_counts_df = base_df.groupby(group_cols, observed=True)['代理ID'].nunique().reset_index()
        agent_counts_df.rename(columns={'代理ID': '单元代理人数'}, inplace=True)
        agg_df = agg_df.merge(agent_counts_df, on=group_cols, how='left')
        agg_df['单元代理人数'] = agg_df['单元代理人数'].fillna(0).astype(int)

    agg_df['转化率'] = agg_df.apply(
        lambda row: f"{round(row['首存人数'] * 100.0 / row['注册人数'], 2)}%"
        if row['注册人数'] != 0 else '0.00%', axis=1
    )
    agg_df['人均首存'] = agg_df.apply(
        lambda row: round(row['首存额'] / row['首存人数'], 2)
        if row['首存人数'] != 0 else 0.0, axis=1
    )
    agg_df['盈余比例'] = agg_df.apply(
        lambda row: f"{round(row['公司输赢'] * 100.0 / row['投注额'], 2)}%"
        if row['投注额'] != 0 else '0.00%', axis=1
    )

    final_columns = [date_col]
    hierarchy_levels = ['1级', '2级', '3级', '4级']

    for col in hierarchy_levels:
        if col in group_cols:
            final_columns.append(col)
    if '发展人' in group_cols:
        final_columns.append('发展人')
    if not is_agent_level_report_final:
        final_columns.append('单元代理人数')
    if is_agent_level_report_final:
        if '上级代理名称' in agg_df.columns:
            final_columns.append('上级代理名称')
        final_columns.extend(['代理ID', '代理编号', '代理名称', '代理类型'])

    final_columns.extend([
        '注册人数', '首存人数', '转化率',
        '首存额', '人均首存', '有效首存人数', '有效首存金额', '存款人数', '取款人数',
        '存款额', '取款额', '投注人数', '投注额', '有效投注额', '公司输赢', '红利',
        '补调金额', '返水', '盈余比例', '代理佣金', '提前结算', '输赢调整', '系统调整', '分数调整', '推广收入', '公司收入'
    ])

    if report_type == 'monthly':
        final_columns.extend(['存款手续费', '取款手续费', '场馆费', '净输赢'])

    for col in hierarchy_levels:
        if col not in agg_df.columns:
            agg_df[col] = ''
        agg_df[col] = agg_df[col].fillna('')

    if '发展人' not in agg_df.columns:
        agg_df['发展人'] = ''
    agg_df['发展人'] = agg_df['发展人'].fillna('')

    if is_agent_level_report_final:
        for col in ['上级代理名称', '代理ID', '代理编号', '代理名称', '代理类型']:
            if col not in agg_df.columns:
                agg_df[col] = ''
            agg_df[col] = agg_df[col].fillna('')

    cols_to_select = [col for col in final_columns if col in agg_df.columns]
    agg_df = agg_df[cols_to_select]

    return agg_df


def _apply_efd_merge(report_df, db_query, report_type, date_col, merge_left_date):
    custom_qfd_stats_df = db_query._get_custom_qfd_stats(report_type)
    if report_type == 'daily':
        custom_qfd_stats_df['stat_date'] = pd.to_datetime(custom_qfd_stats_df['stat_date']).dt.date
    custom_qfd_stats_df['agent_id'] = pd.to_numeric(custom_qfd_stats_df['agent_id'], errors='coerce').fillna(0).astype(int)

    report_df = report_df.merge(
        custom_qfd_stats_df,
        left_on=[merge_left_date, '代理ID'],
        right_on=['stat_date', 'agent_id'],
        how='left'
    )
    report_df['首存人数'] = report_df['new_first_recharge_member_count'].fillna(report_df['首存人数'])
    report_df['首存额'] = report_df['new_first_recharge_amount'].fillna(report_df['首存额'])
    report_df = report_df.drop(columns=['stat_date', 'agent_id', 'new_first_recharge_member_count', 'new_first_recharge_amount'], errors='ignore')

    custom_efd_stats_df = db_query._get_custom_efd_stats(report_type)
    if report_type == 'daily':
        custom_efd_stats_df['stat_date'] = pd.to_datetime(custom_efd_stats_df['stat_date']).dt.date
    custom_efd_stats_df['agent_id'] = pd.to_numeric(custom_efd_stats_df['agent_id'], errors='coerce').fillna(0).astype(int)

    report_df = report_df.merge(
        custom_efd_stats_df,
        left_on=[merge_left_date, '代理ID'],
        right_on=['stat_date', 'agent_id'],
        how='left'
    )
    report_df['有效首存人数'] = report_df['calculated_valid_first_recharge_member_count'].fillna(report_df['有效首存人数'])
    report_df['有效首存金额'] = report_df['calculated_valid_first_recharge_amount'].fillna(report_df['有效首存金额'])
    report_df = report_df.drop(columns=['stat_date', 'agent_id', 'calculated_valid_first_recharge_member_count', 'calculated_valid_first_recharge_amount'], errors='ignore')

    report_df['首存人数'] = report_df['首存人数'].fillna(0).astype(int)
    report_df['首存额'] = report_df['首存额'].fillna(0.0).astype(float)
    report_df['有效首存人数'] = report_df['有效首存人数'].fillna(0).astype(int)
    report_df['有效首存金额'] = report_df['有效首存金额'].fillna(0.0).astype(float)

    return report_df


def _build_base_df(report_df, db_query):
    agent_hierarchy_df = db_query._get_agent_hierarchy_and_member_mapping()
    agent_maintain_df = db_query._get_agent_maintain_mapping()
    agent_parent_df = db_query._get_agent_parent_mapping()

    base_df = report_df.merge(
        agent_hierarchy_df[['代理ID', '1级', '2级', '3级', '4级']],
        on='代理ID',
        how='left'
    ).merge(
        agent_maintain_df,
        on='代理ID',
        how='left'
    ).merge(
        agent_parent_df,
        on='代理ID',
        how='left'
    )

    for col in ['1级', '2级', '3级', '4级', '发展人', '上级代理名称']:
        base_df[col] = base_df[col].fillna('')

    if db_query.filter_by_agent and db_query.agent_names:
        names_set = set(db_query.agent_names)
        base_df = base_df[base_df['上级代理名称'].isin(names_set) | base_df['代理名称'].isin(names_set)]

    return base_df


def _generate_results(base_df, date_col, report_type, filter_by_agent):
    results = {}
    if not filter_by_agent:
        results['1级'] = aggregate_report_data(base_df.copy(), [date_col, '1级'], report_type)
        results['2级'] = aggregate_report_data(base_df.copy(), [date_col, '1级', '2级'], report_type)
        results['3级'] = aggregate_report_data(base_df.copy(), [date_col, '1级', '2级', '3级'], report_type)
        results['4级'] = aggregate_report_data(base_df.copy(), [date_col, '1级', '2级', '3级', '4级'], report_type)
        results['发展人'] = aggregate_report_data(base_df.copy(), [date_col, '1级', '2级', '3级', '4级', '发展人'], report_type)
    results['代理'] = aggregate_report_data(base_df.copy(),
                                            [date_col, '1级', '2级', '3级', '4级', '发展人', '上级代理名称', '代理ID', '代理编号',
                                             '代理名称', '代理类型'], report_type)
    return results


def work_daily(db_query: DatabaseQuery) -> dict[str, pd.DataFrame]:
    daily_report_df = db_query._get_daily_report_stats()
    daily_report_df['日期'] = pd.to_datetime(daily_report_df['日期']).dt.date

    numeric_cols_from_report = [
        '注册人数', '首存人数', '首存额', '人均首存', '转化率', '有效首存人数', '有效首存金额',
        '存款人数', '取款人数', '存款额', '取款额', '投注人数', '投注额', '有效投注额',
        '公司输赢', '提前结算', '盈余比例', '红利', '返水', '代理佣金', '输赢调整',
        '系统调整', '分数调整', '补调金额', '推广收入', '公司收入'
    ]
    for col in numeric_cols_from_report:
        if col in daily_report_df.columns:
            daily_report_df[col] = pd.to_numeric(daily_report_df[col], errors='coerce').fillna(0.0)

    if db_query.calculate_effective_first_deposit:
        daily_report_df = _apply_efd_merge(daily_report_df, db_query, 'daily', '日期', '日期')

    base_daily_df = _build_base_df(daily_report_df, db_query)
    return _generate_results(base_daily_df, '日期', 'daily', db_query.filter_by_agent)


def work_monthly(db_query: DatabaseQuery) -> dict[str, pd.DataFrame]:
    monthly_report_df = db_query._get_monthly_report_stats()
    monthly_report_df['月份'] = pd.to_datetime(monthly_report_df['月份']).dt.strftime('%Y-%m')

    numeric_cols_from_report = [
        '注册人数', '首存人数', '首存额', '人均首存', '转化率', '有效首存人数', '有效首存金额',
        '存款人数', '取款人数', '存款额', '取款额', '投注人数', '投注额', '有效投注额',
        '公司输赢', '提前结算', '盈余比例', '红利', '返水', '存款手续费', '取款手续费',
        '代理佣金', '输赢调整', '系统调整', '分数调整', '补调金额', '场馆费', '净输赢',
        '推广收入', '公司收入'
    ]
    for col in numeric_cols_from_report:
        if col in monthly_report_df.columns:
            monthly_report_df[col] = pd.to_numeric(monthly_report_df[col], errors='coerce').fillna(0.0)

    if db_query.calculate_effective_first_deposit:
        monthly_report_df = _apply_efd_merge(monthly_report_df, db_query, 'monthly', '月份', '月份')

    base_monthly_df = _build_base_df(monthly_report_df, db_query)
    return _generate_results(base_monthly_df, '月份', 'monthly', db_query.filter_by_agent)


def save_to_excel(dataframes_dict: dict[str, pd.DataFrame], filename: str):
    max_rows_per_sheet = 1000000
    sheet_order = ['1级', '2级', '3级', '4级', '发展人', '代理']

    with pd.ExcelWriter(filename, engine='xlsxwriter') as writer:
        for sheet_name in sheet_order:
            if sheet_name in dataframes_dict:
                df_to_save = dataframes_dict[sheet_name]
                if len(df_to_save) <= max_rows_per_sheet:
                    df_to_save.to_excel(writer, sheet_name=sheet_name, index=False)
                    worksheet = writer.sheets[sheet_name]
                    if not df_to_save.empty:
                        worksheet.freeze_panes(1, 0)
                        worksheet.autofilter(0, 0, 0, len(df_to_save.columns) - 1)
                else:
                    num_chunks = (len(df_to_save) + max_rows_per_sheet - 1) // max_rows_per_sheet
                    for i in range(num_chunks):
                        start_row = i * max_rows_per_sheet
                        end_row = min((i + 1) * max_rows_per_sheet, len(df_to_save))
                        chunk_df = df_to_save.iloc[start_row:end_row]
                        sub_sheet_name = f'{sheet_name}_{i + 1}'
                        chunk_df.to_excel(writer, sheet_name=sub_sheet_name, index=False)

                        worksheet = writer.sheets[sub_sheet_name]
                        if not chunk_df.empty:
                            worksheet.freeze_panes(1, 0)
                            worksheet.autofilter(0, 0, 0, len(chunk_df.columns) - 1)


def main():
    start_time = datetime.now()
    print(f"运行开始时间: {start_time.strftime('%Y-%m-%d %H:%M')}")

    AGENTS = """
    hm1001    hm1002
    hm1003
    """

    db_query = None
    try:
        db_query = DatabaseQuery(
            host='18.178.159.230',
            port=3366,
            user='bigdata',
            password='uvb5SOSmLH8sCoSU',
            site_id=9001,
            start_date='2026-06-01',
            end_date='2026-06-30',
            start_month='2026-06',
            end_month='2026-06',
            agent_names=AGENTS.split(),
            filter_by_agent=False,
            calculate_effective_first_deposit=False  # True: 自定义计算有效首存; False: 提取数据库有效首存
        )

        daily_results_dict = work_daily(db_query)

        site_id_str = str(db_query.site_id) if db_query.site_id is not None else 'ALL'
        start_date_fmt = datetime.strptime(db_query.start_date, '%Y-%m-%d').strftime('%#m-%#d')
        end_date_fmt = datetime.strptime(db_query.end_date, '%Y-%m-%d').strftime('%#m-%#d')

        if db_query.start_date == db_query.end_date:
            daily_date_range_str = start_date_fmt
        else:
            daily_date_range_str = f"{start_date_fmt}-{end_date_fmt}"

        daily_excel_filename = f"【{site_id_str}_{daily_date_range_str}】代理数据_每日_{start_time.strftime('%#m-%#d_%H.%M')}.xlsx"

        save_to_excel(daily_results_dict, daily_excel_filename)
        print(f"每日报告已保存到: {daily_excel_filename}")

        monthly_results_dict = work_monthly(db_query)

        start_month_fmt = datetime.strptime(db_query.start_month, '%Y-%m').strftime('%#m')
        end_month_fmt = datetime.strptime(db_query.end_month, '%Y-%m').strftime('%#m')

        if db_query.start_month == db_query.end_month:
            monthly_date_range_str = f"{start_month_fmt}月"
        else:
            monthly_date_range_str = f"{start_month_fmt}月-{end_month_fmt}月"

        monthly_excel_filename = f"【{site_id_str}_{monthly_date_range_str}】代理数据_月度_{start_time.strftime('%#m-%#d_%H.%M')}.xlsx"

        save_to_excel(monthly_results_dict, monthly_excel_filename)
        print(f"月度报告已保存到: {monthly_excel_filename}")

    except Exception as e:
        print(f"运行失败: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if db_query:
            db_query.close_connections()
        end_time = datetime.now()
        print(f"运行结束时间: {end_time.strftime('%Y-%m-%d %H:%M')}")
        print(f"总运行时间: {str(end_time - start_time).split('.')[0]}")


if __name__ == "__main__":
    main()