import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '1_数据'))
from site_venue_config import SITE_MAP, VENUE_MAP
import pandas as pd
import pymongo
from tqdm import tqdm
from multiprocessing import Pool, cpu_count
from datetime import datetime, timedelta
import re
import traceback
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import numpy as np

FINAL_BETTING_DETAILS_COLUMNS = [
    '站点', '结算日期', '会员账号', '场馆名称', '游戏名称', '投注额', '有效投注',
    '会员输赢', '是否提前结算', '投注时间', '赛事时间', '结算时间', '注单号',
    '游戏详情', '游戏详情1', '赛事ID', '欧赔', '联赛名称', '球队', '玩法', '早盘/滚球'
]

FINAL_MEMBER_REPORT_COLUMNS = [
    '代理ID', '代理名称', '会员ID', '会员账号', '状态', 'VIP等级',
    '标签', '备注', '注册时间', '首存确认时间', '首存金额'
]


def execute_mongo_aggregation(collection_name: str, pipeline: list, mongo_uri: str, db_name: str) -> pd.DataFrame:
    try:
        with pymongo.MongoClient(mongo_uri) as _client:
            collection = _client[db_name][collection_name]
            return pd.DataFrame(list(collection.aggregate(pipeline, batchSize=10000)))
    except pymongo.errors.ConnectionFailure as e:
        print(f"MongoDB连接失败: {e}")
    except pymongo.errors.PyMongoError as e:
        print(f"MongoDB查询失败 ({collection_name}): {e}")
    except Exception as e:
        print(f"MongoDB意外错误 ({collection_name}): {e}")
        traceback.print_exc()
    return pd.DataFrame()


class DatabaseQuery:
    def __init__(self,
                 mongo_host: str, mongo_port: int, mongo_user: str, mongo_password: str,
                 mysql_host: str = None, mysql_port: int = None, mysql_user: str = None, mysql_password: str = None,
                 site_id: int = None, start_date: str = '2025-06-01', end_date: str = '2025-06-01',
                 mongo_collection_prefix: str = 'pull_order_game_', venue: str | list = '',
                 filter_type: str = '',
                 main_date_filter_field_name: str = 'settle_time',
                 report_type: str = 'betting_details',
                 early_inplay_filter_choice: str = 'all'):

        self.mongo_uri = f"mongodb://{mongo_user}:{mongo_password}@{mongo_host}:{mongo_port}/"
        self.mongo_db_name = "update_records"
        self.mongo_collection_prefix = mongo_collection_prefix
        self.venue = venue
        self.flag_value = 1

        self.mysql_engine = None
        self.MySQLSession = None
        if mysql_host and mysql_user and mysql_password:
            mysql_connection_string = f"mysql+mysqlconnector://{mysql_user}:{mysql_password}@{mysql_host}:{mysql_port}/"
            self.mysql_engine = create_engine(mysql_connection_string)
            self.MySQLSession = sessionmaker(bind=self.mysql_engine)

        self.site_id = site_id
        self.start_date = start_date
        self.end_date = end_date
        self.start_time = f"{start_date} 00:00:00"
        self.end_time = f"{end_date} 23:59:59"

        self.filter_type = filter_type
        self.main_date_filter_field_name = main_date_filter_field_name
        self.report_type = report_type
        self.early_inplay_filter_choice = early_inplay_filter_choice

        self.u1_db = "u1_1000"
        self.bigdata_db = "bigdata"
        self.control_db = "control_1000"

    def close_connections(self):
        if self.mysql_engine:
            self.mysql_engine.dispose()

    def mongo_betting_details(self) -> pd.DataFrame:
        collections = []
        try:
            with pymongo.MongoClient(self.mongo_uri) as temp_client:
                temp_db = temp_client[self.mongo_db_name]
                all_collection_names = temp_db.list_collection_names()

            venues = [self.venue] if not isinstance(self.venue, list) else self.venue
            collections = [
                col for col in all_collection_names
                if col.startswith(self.mongo_collection_prefix) and any(col.endswith(v) for v in venues)
            ]
        except pymongo.errors.PyMongoError as e:
            print(f"列出MongoDB**失败 ({self.venue}): {e}")
            return pd.DataFrame(columns=FINAL_BETTING_DETAILS_COLUMNS)
        except Exception as e:
            print(f"列出MongoDB**意外错误 ({self.venue}): {e}")
            traceback.print_exc()
            return pd.DataFrame(columns=FINAL_BETTING_DETAILS_COLUMNS)

        if not collections:
            return pd.DataFrame(columns=FINAL_BETTING_DETAILS_COLUMNS)

        pipeline = [
            {"$match": {
                "flag": self.flag_value,
                self.main_date_filter_field_name: {"$gte": self.start_time, "$lte": self.end_time}
            }},
            {"$project": {
                "_id": 0,
                "站点": "$site_id",
                "会员账号": "$member_name",
                "结算日期": "$settle_time",
                "场馆名称": "$venue_name",
                "游戏名称": "$game_name",
                "赛事ID": {"$toString": "$match_id"},
                "注单号": {
                    "$reduce": {
                        "input": {"$slice": [{"$split": [{"$toString": "$id"}, "_"]}, 1, 999]},
                        "initialValue": "",
                        "in": {"$concat": ["$$value", {"$cond": [{"$eq": ["$$value", ""]}, "", "_"]}, "$$this"]}
                    }
                },
                "欧赔": {
                    "$cond": [
                        {
                            "$or": [
                                {"$eq": ["$odds_type", "EURO"]},
                                {"$regexMatch": {"input": "$play_info", "regex": "欧洲盘"}},
                                {"$regexMatch": {"input": "$game_play_info", "regex": "欧洲盘"}}
                            ]
                        },
                        "$odds",
                        {"$add": ["$odds", 1]}
                    ]
                },
                "投注额": "$bet_amount",
                "有效投注": "$valid_bet_amount",
                "会员输赢": "$net_amount",
                "是否提前结算": {"$toString": "$early_settle_flag"},
                "投注时间": "$bet_time",
                "赛事时间": "$start_time",
                "结算时间": "$settle_time",
                "游戏详情": "$play_info",
                "游戏详情1": "$game_play_info",
            }}
        ]
        if self.site_id is not None:
            pipeline[0]["$match"]["site_id"] = self.site_id

        all_results = []
        for collection_name in tqdm(collections, desc=f"处理 {self.venue} 场馆"):
            df_part = execute_mongo_aggregation(
                collection_name=collection_name,
                pipeline=pipeline,
                mongo_uri=self.mongo_uri,
                db_name=self.mongo_db_name
            )
            if not df_part.empty:
                all_results.append(df_part)

        df = pd.concat(all_results, ignore_index=True) if all_results else pd.DataFrame(
            columns=FINAL_BETTING_DETAILS_COLUMNS)
        if df.empty:
            return df

        df['站点'] = df['站点'].map(SITE_MAP).fillna(df['站点'].astype(str))
        df['场馆名称'] = df['场馆名称'].map(VENUE_MAP).fillna(df['场馆名称'])

        time_cols = ['结算时间', '投注时间', '赛事时间']
        for col in time_cols:
            if col in df.columns:
                df[col] = pd.to_datetime(df[col], errors='coerce', format='mixed')

        if '投注时间' in df.columns and '赛事时间' in df.columns:
            df['早盘/滚球'] = '滚球'
            mask_early_bet = (df['投注时间'].notna()) & (df['赛事时间'].notna()) & (df['投注时间'] < df['赛事时间'])
            df.loc[mask_early_bet, '早盘/滚球'] = '早盘'
        else:
            df['早盘/滚球'] = None

        if self.early_inplay_filter_choice != 'all' and '早盘/滚球' in df.columns:
            if self.early_inplay_filter_choice == 'early_bet':
                df = df[df['早盘/滚球'] == '早盘']
            elif self.early_inplay_filter_choice == 'in_play':
                df = df[df['早盘/滚球'] == '滚球']

        if df.empty:
            return df

        df = df.sort_values(by='投注时间').reset_index(drop=True)

        string_cols_to_clean = ['游戏详情', '游戏详情1']
        for col in string_cols_to_clean:
            if col in df.columns:
                df[col] = df[col].astype(str).str.replace('&nbsp;', ' ').str.strip()

        df['_temp_details_str'] = df['游戏详情']
        lh_dj_mask = (df['场馆名称'] == '雷火电竞')
        df.loc[lh_dj_mask, '_temp_details_str'] = df.loc[lh_dj_mask, '游戏详情1']

        df['_temp_details_str'] = df['_temp_details_str'].astype(str).str.strip()
        df['_parsed_details_list'] = df['_temp_details_str'].str.split('\n')

        df['联赛名称'] = ''
        df['球队'] = ''
        df['玩法'] = ''

        ty_mask = df['场馆名称'].str.contains('体育', na=False)
        df.loc[ty_mask, '联赛名称'] = df.loc[ty_mask, '_parsed_details_list'].str[1].fillna('').str.strip()
        df.loc[ty_mask, '球队'] = df.loc[ty_mask, '_parsed_details_list'].str[2].fillna('').str.strip()
        df.loc[ty_mask, '玩法'] = df.loc[ty_mask, '_parsed_details_list'].str[3].fillna('').str.strip()

        lh_dj_mask = (df['场馆名称'] == '雷火电竞')
        df.loc[lh_dj_mask, '联赛名称'] = df.loc[lh_dj_mask, '_parsed_details_list'].str[0].fillna('').str.strip()
        df.loc[lh_dj_mask, '球队'] = df.loc[lh_dj_mask, '_parsed_details_list'].str[2].fillna('').str.strip()
        df.loc[lh_dj_mask, '玩法'] = df.loc[lh_dj_mask, '_parsed_details_list'].str[4].fillna('').str.strip()

        other_dj_mask = (df['场馆名称'].str.contains('电竞', na=False)) & (~lh_dj_mask)
        df.loc[other_dj_mask, '联赛名称'] = df.loc[other_dj_mask, '_parsed_details_list'].str[1].fillna('').str.strip()
        df.loc[other_dj_mask, '球队'] = df.loc[other_dj_mask, '_parsed_details_list'].str[2].fillna('').str.strip()
        df.loc[other_dj_mask, '玩法'] = df.loc[other_dj_mask, '_parsed_details_list'].str[3].fillna('').str.strip()

        df = df.drop(columns=['_temp_details_str', '_parsed_details_list'])

        target_leagues = []
        game_name_contains = None
        game_details_excludes = None

        if self.filter_type == 'five_leagues':
            league_names_raw = """
            德国甲级联赛
            德国甲组联赛
            法国甲级联赛
            法国甲组联赛
            意大利甲级联赛
            意大利甲组联赛
            英格兰超级联赛
            西班牙甲级联赛
            西班牙甲组联赛
            """
            target_leagues = [name.strip() for name in league_names_raw.strip().split('\n') if name.strip()]
            game_name_contains = '足球'
            game_details_excludes = '独家|虚拟|VR'
        elif self.filter_type == 'nbacba':
            league_names_raw = """
            中国男子篮球职业联赛
            NBA
            CBA
            """
            target_leagues = [name.strip() for name in league_names_raw.strip().split('\n') if name.strip()]
            game_details_excludes = '独家|虚拟|VR'
        elif self.filter_type == 'custom_leagues':
            league_names_raw_custom = """
            欧 冠
            欧 联
            欧 协 联
            """
            target_leagues = [name.strip() for name in league_names_raw_custom.strip().split('\n') if name.strip()]
            game_name_contains = '足球'
            game_details_excludes = '独家|虚拟|VR'

        if target_leagues:
            combined_league_mask = pd.Series(False, index=df.index)
            for league_spec in target_leagues:
                keywords = league_spec.split()
                current_spec_mask = pd.Series(True, index=df.index)
                for kw in keywords:
                    current_spec_mask &= df['联赛名称'].str.contains(re.escape(kw), na=False, regex=True)
                combined_league_mask |= current_spec_mask
            df = df[combined_league_mask]

        if game_name_contains:
            df = df[df['游戏名称'].str.contains(game_name_contains, na=False)]
        if game_details_excludes:
            df = df[~df['游戏详情'].str.contains(game_details_excludes, na=False)]

        if '结算时间' in df.columns:
            df['结算日期'] = df['结算时间'].dt.date
        else:
            df['结算日期'] = None

        dtype_mapping = {
            '站点': 'string', '结算日期': 'object', '会员账号': 'string',
            '场馆名称': 'string', '游戏名称': 'string', '赛事ID': 'string', '注单号': 'string',
            '欧赔': 'float64', '投注额': 'float64', '有效投注': 'float64', '会员输赢': 'float64',
            '是否提前结算': 'string', '投注时间': 'datetime64[ns]', '赛事时间': 'datetime64[ns]',
            '结算时间': 'datetime64[ns]', '游戏详情': 'string', '游戏详情1': 'string',
            '联赛名称': 'string', '球队': 'string', '玩法': 'string', '早盘/滚球': 'string'
        }
        for col, dtype in dtype_mapping.items():
            if col in df.columns:
                try:
                    if dtype in ['float64']:
                        df[col] = pd.to_numeric(df[col], errors='coerce')
                    elif dtype == 'datetime64[ns]':
                        df[col] = pd.to_datetime(df[col], errors='coerce', format='mixed')
                    else:
                        df[col] = df[col].astype(dtype)
                except Exception as e:
                    print(f"警告: 无法转换列 '{col}' 到 {dtype}: {e}")

        return df[FINAL_BETTING_DETAILS_COLUMNS]

    def _get_member_basic_info(self) -> pd.DataFrame:
        if not self.mysql_engine:
            print("MySQL连接未初始化。")
            return pd.DataFrame()

        remark_subquery_parts = ["remark_type = 1"]
        if self.site_id is not None:
            remark_subquery_parts.append(f"site_id = {self.site_id}")
        remark_subquery_where_clause = " AND ".join(remark_subquery_parts)

        remark_subquery = f"""
        SELECT member_id, remark
        FROM (
            SELECT member_id, remark, ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY updated_at DESC) AS rn
            FROM {self.u1_db}.member_open_forbid_record
            WHERE {remark_subquery_where_clause}
        ) t
        WHERE t.rn = 1
        """
        remark_join_clause = f"LEFT JOIN ({remark_subquery}) u1_mofr ON u1_mi.id = u1_mofr.member_id"

        select_fields = [
            "u1_mi.top_id AS '代理ID'",
            "u1_mi.top_name AS '代理名称'",
            "u1_mi.id AS '会员ID'",
            "u1_mi.name AS '会员账号'",
            "CASE u1_mi.status WHEN 1 THEN '启用' WHEN 0 THEN '禁用' ELSE CAST(u1_mi.status AS CHAR) END AS '状态'",
            "CAST(u1_mi.vip_grade AS UNSIGNED) AS 'VIP等级'",
            "(SELECT GROUP_CONCAT(DISTINCT c1_sv.dict_value ORDER BY c1_sv.code SEPARATOR ',') "
            f"FROM {self.control_db}.sys_dict_value c1_sv "
            f"WHERE FIND_IN_SET(c1_sv.code, u1_mi.tag_id) "
            "AND (c1_sv.initial_flag IS NULL OR c1_sv.initial_flag <> 1)) AS '标签'",
            "u1_mofr.remark AS '备注'",
            "u1_mi.created_at AS '注册时间'"
        ]

        where_conditions = []
        if self.site_id is not None:
            where_conditions.append(f"u1_mi.site_id = {self.site_id}")

        where_conditions.append(f"u1_mi.created_at BETWEEN '{self.start_time}' AND '{self.end_time}'")

        query = f"""
        SELECT
            {', '.join(select_fields)}
        FROM {self.u1_db}.member_info u1_mi
        {remark_join_clause}
        WHERE {" AND ".join(where_conditions)}
        """

        df = pd.concat(pd.read_sql(query, self.mysql_engine, chunksize=5000), ignore_index=True)
        return df

    def _get_first_deposit_info(self) -> pd.DataFrame:
        if not self.mysql_engine:
            print("MySQL连接未初始化。")
            return pd.DataFrame()

        query = f"""
        SELECT DISTINCT
            member_id AS '会员ID',
            first_deposit_time AS '首存确认时间',
            first_deposit_amount AS '首存金额'
        FROM {self.bigdata_db}.member_daily_statics
        WHERE first_deposit_amount > 0
        """
        if self.site_id is not None:
            query += f" AND site_id = {self.site_id}"

        df = pd.concat(pd.read_sql(query, self.mysql_engine, chunksize=5000), ignore_index=True)
        df['首存确认时间'] = pd.to_datetime(df['首存确认时间'], errors='coerce', format='mixed')
        return df

    def get_registered_first_depositors(self) -> pd.DataFrame:
        member_df = self._get_member_basic_info()
        if member_df.empty:
            return pd.DataFrame(columns=FINAL_MEMBER_REPORT_COLUMNS)

        first_deposit_df = self._get_first_deposit_info()
        if first_deposit_df.empty:
            return pd.DataFrame(columns=FINAL_MEMBER_REPORT_COLUMNS)

        result_df = member_df.merge(first_deposit_df, on='会员ID', how='inner')

        result_df = result_df[result_df['首存金额'].notna() & (result_df['首存金额'] > 0)]

        if '代理ID' in result_df.columns:
            result_df['代理ID'] = pd.to_numeric(result_df['代理ID'], errors='coerce')
            result_df['代理ID'] = result_df['代理ID'].replace(0, np.nan)

        result_df['注册时间'] = pd.to_datetime(result_df['注册时间'], errors='coerce')
        result_df = result_df.sort_values(by='注册时间').reset_index(drop=True)

        return result_df[FINAL_MEMBER_REPORT_COLUMNS]


def save_to_excel(df: pd.DataFrame, filename: str):
    if df.empty:
        print(f"DataFrame 为空，不保存文件: {filename}")
        return

    max_rows_per_sheet = 1000000
    cols_to_save = df.columns.tolist()

    total_rows = len(df)
    num_sheets = (total_rows // max_rows_per_sheet) + (1 if total_rows % max_rows_per_sheet else 0)

    try:
        with pd.ExcelWriter(filename, engine='xlsxwriter') as writer:
            for sheet_num in range(num_sheets):
                start_row = sheet_num * max_rows_per_sheet
                end_row = min((sheet_num + 1) * max_rows_per_sheet, total_rows)
                df_sheet = df.iloc[start_row:end_row][cols_to_save]

                sheet_name = "数据" if num_sheets == 1 else f"Sheet{sheet_num + 1}"

                df_sheet.to_excel(writer, sheet_name=sheet_name, index=False)

                workbook = writer.book
                worksheet = writer.sheets[sheet_name]

                header_format = workbook.add_format({
                    'bold': True, 'text_wrap': True, 'valign': 'top', 'fg_color': '#D7E4BC', 'border': 1})

                for col_num, value in enumerate(df_sheet.columns.values):
                    worksheet.write(0, col_num, value, header_format)

                worksheet.freeze_panes(1, 0)
                worksheet.autofilter(0, 0, 0, len(cols_to_save) - 1)

        print(f"成功保存文件: {filename} (共 {num_sheets} 个 Sheet)")

    except Exception as e:
        print(f"保存Excel失败 ({filename}): {e}")
        traceback.print_exc()


def process_single_task(task_params):
    site_id, site_name, chinese_report_name, actual_venue_codes_for_details, common_params, report_type = task_params

    formatted_date_str = common_params['formatted_date_str']
    excel_filename_prefix = f"【{site_name}_{chinese_report_name}】"

    db_query = DatabaseQuery(
        mongo_host=common_params['mongo_host'],
        mongo_port=common_params['mongo_port'],
        mongo_user=common_params['mongo_user'],
        mongo_password=common_params['mongo_password'],
        mysql_host=common_params['mysql_host'],
        mysql_port=common_params['mysql_port'],
        mysql_user=common_params['mysql_user'],
        mysql_password=common_params['mysql_password'],
        site_id=site_id,
        venue=actual_venue_codes_for_details,
        start_date=common_params['start_date'],
        end_date=common_params['end_date'],
        filter_type=common_params.get('filter_type'),
        main_date_filter_field_name=common_params['main_date_filter_field_name'],
        report_type=report_type,
        early_inplay_filter_choice=common_params['early_inplay_filter_choice']
    )

    result_df = pd.DataFrame()
    try:
        if report_type == 'registered_first_deposit':
            result_df = db_query.get_registered_first_depositors()
            excel_filename = f"{excel_filename_prefix}{formatted_date_str}.xlsx"
        else:
            all_dfs_for_group = []
            for current_venue_code in actual_venue_codes_for_details:
                venue_specific_db_query = DatabaseQuery(
                    mongo_host=common_params['mongo_host'],
                    mongo_port=common_params['mongo_port'],
                    mongo_user=common_params['mongo_user'],
                    mongo_password=common_params['mongo_password'],
                    site_id=site_id,
                    venue=current_venue_code,
                    start_date=common_params['start_date'],
                    end_date=common_params['end_date'],
                    filter_type=common_params.get('filter_type'),
                    main_date_filter_field_name=common_params['main_date_filter_field_name'],
                    report_type=report_type,
                    early_inplay_filter_choice=common_params['early_inplay_filter_choice']
                )
                df_part = venue_specific_db_query.mongo_betting_details()
                if not df_part.empty:
                    all_dfs_for_group.append(df_part)
                venue_specific_db_query.close_connections()
            result_df = pd.concat(all_dfs_for_group, ignore_index=True) if all_dfs_for_group else pd.DataFrame()
            excel_filename = f"{excel_filename_prefix}{formatted_date_str}.xlsx"
    except Exception as e:
        print(f"处理任务失败: {site_name} ({chinese_report_name}) - 错误: {type(e).__name__}")
        traceback.print_exc()
    finally:
        db_query.close_connections()

    if not result_df.empty:
        save_to_excel(result_df, excel_filename)
        return f"成功: {site_name} {chinese_report_name} ({len(result_df)}条)"
    else:
        return f"无数据: {site_name} {chinese_report_name}"


def get_date_range_from_input():
    while True:
        choice = input("选择日期范围：1. 昨日 2. 手动指定 (1/2): ")
        if choice == '1':
            yesterday = datetime.now() - timedelta(days=1)
            start_date = end_date = yesterday.strftime('%Y-%m-%d')
            formatted_date_str = f"{yesterday.month}-{yesterday.day}"
            print(f"已选昨日: {start_date}")
            return start_date, end_date, formatted_date_str
        elif choice == '2':
            while True:
                start_date_str = input("开始日期 (YYYY-MM-DD): ")
                end_date_str = input("结束日期 (YYYY-MM-DD): ")
                try:
                    start_date_obj = datetime.strptime(start_date_str, '%Y-%m-%d')
                    end_date_obj = datetime.strptime(end_date_str, '%Y-%m-%d')
                    if start_date_obj > end_date_obj:
                        print("错误：开始日期不能晚于结束日期。")
                        continue
                    formatted_date_str = (
                        f"{start_date_obj.month}-{start_date_obj.day}" if start_date_str == end_date_str
                        else f"{start_date_obj.month}-{start_date_obj.day}-{end_date_obj.month}-{end_date_obj.day}")
                    print(f"已选日期范围: {start_date_str} 至 {end_date_str}")
                    return start_date_str, end_date_str, formatted_date_str
                except ValueError:
                    print("日期格式错误。")
        else:
            print("无效选择。")


def main():
    start_run_time = datetime.now()
    print(f"脚本开始: {start_run_time.strftime('%H:%M:%S')}")

    base_venue_chinese_map = {
        'TY': '体育', 'DJ': '电竞', 'ZR': '真人', 'QP': '棋牌', 'DZ': '电子', 'HX': '电子',
        'CP': '彩票', 'GGL': '彩票', 'BY': '捕鱼',
    }

    grouped_venue_codes = {}
    for code, chinese_name in base_venue_chinese_map.items():
        grouped_venue_codes.setdefault(chinese_name, []).append(code)

    selected_site_map = {}
    while True:
        site_choice = input("选择站点：1. 全部 2. 手动输入 (1/2): ")
        if site_choice == '1':
            selected_site_map = SITE_MAP
            print("已选：全部站点")
            break
        elif site_choice == '2':
            site_ids_input = input("请输入站点ID，多个ID用逗号分隔 (例如: 1000,2000): ")
            try:
                input_ids = [int(s.strip()) for s in site_ids_input.split(',') if s.strip().isdigit()]
                valid_selected_ids = [sid for sid in input_ids if sid in SITE_MAP]

                if not valid_selected_ids:
                    print("未找到有效站点ID，请重新输入。")
                    continue

                selected_site_map = {sid: SITE_MAP[sid] for sid in valid_selected_ids}
                print(f"已选站点: {', '.join(SITE_MAP[sid] for sid in selected_site_map.keys())}")
                break
            except ValueError:
                print("输入格式错误，请确保只输入数字和逗号。")
            except Exception as e:
                print(f"处理站点输入时发生错误: {e}")
        else:
            print("无效选择。")

    start_date, end_date, formatted_date_str = get_date_range_from_input()

    main_date_filter_field_name = 'settle_time'
    while True:
        date_filter_choice = input("选择主日期筛选依据：1. 结算时间 2. 开赛时间 (1/2): ")
        if date_filter_choice == '1':
            main_date_filter_field_name = 'settle_time'
            print("已选：主日期筛选依据【结算时间】")
            break
        elif date_filter_choice == '2':
            main_date_filter_field_name = 'start_time'
            print("已选：主日期筛选依据【开赛时间】")
            break
        else:
            print("无效选择。")

    early_inplay_filter_choice = 'all'
    while True:
        early_inplay_choice = input("选择早盘/滚球筛选：1. 全阶段 2. 早盘 3. 滚球 (1/2/3): ")
        if early_inplay_choice == '1':
            early_inplay_filter_choice = 'all'
            print("已选：早盘/滚球筛选【全阶段】")
            break
        elif early_inplay_choice == '2':
            early_inplay_filter_choice = 'early_bet'
            print("已选：早盘/滚球筛选【早盘】")
            break
        elif early_inplay_choice == '3':
            early_inplay_filter_choice = 'in_play'
            print("已选：早盘/滚球筛选【滚球】")
            break
        else:
            print("无效选择。")

    choice_map = {
        '1': (['体育', '电竞', '真人', '棋牌', '电子', '彩票', '捕鱼'], '', 'betting_details'),
        '2': (['真人', '棋牌', '电子', '彩票', '捕鱼'], '', 'betting_details'),
        '3': (['体育', '电竞'], '', 'betting_details'),
        '21': (['体育'], 'custom_leagues', 'betting_details'),
        '22': (['体育'], 'five_leagues', 'betting_details'),
        '23': (['体育'], 'nbacba', 'betting_details'),
        '81': (['体育'], '', 'betting_details'),
        '82': (['电竞'], '', 'betting_details'),
        '83': (['真人'], '', 'betting_details'),
        '84': (['棋牌'], '', 'betting_details'),
        '85': (['电子'], '', 'betting_details'),
        '86': (['彩票'], '', 'betting_details'),
        '87': (['捕鱼'], '', 'betting_details'),
        '101': ([], '', 'registered_first_deposit'),
    }

    while True:
        print("\n选择类型：")
        print("1. 投注明细 - 全游戏")
        print("2. 投注明细 - 真人、棋牌、电子、彩票、捕鱼")
        print("3. 投注明细 - 体育、电竞")
        print("21. 投注明细 - 自定义联赛 (仅体育，自动过滤)")
        print("22. 投注明细 - 5大联赛 (仅体育，自动过滤)")
        print("23. 投注明细 - NBA/CBA (仅体育，自动过滤)")
        print("81. 投注明细 - 体育")
        print("82. 投注明细 - 电竞")
        print("83. 投注明细 - 真人")
        print("84. 投注明细 - 棋牌")
        print("85. 投注明细 - 电子")
        print("86. 投注明细 - 彩票")
        print("87. 投注明细 - 捕鱼")
        print("101. 注册-（已首存）")
        venue_choice_input = input("输入数字，多个用逗号分隔 (例如: 1,23,101): ")

        input_choices = [c.strip() for c in venue_choice_input.split(',') if c.strip()]
        valid_choices = [c for c in input_choices if c in choice_map]

        if not valid_choices:
            print("无效选择。")
            continue

        print(f"已选: {', '.join(valid_choices)}")
        break

    common_params = {
        'mongo_host': '18.178.159.230',
        'mongo_port': 27217,
        'mongo_user': 'biddata',
        'mongo_password': 'uvb5SOSmLH8sCoSU',
        'mysql_host': '18.178.159.230',
        'mysql_port': 3366,
        'mysql_user': 'bigdata',
        'mysql_password': 'uvb5SOSmLH8sCoSU',
        'start_date': start_date,
        'end_date': end_date,
        'formatted_date_str': formatted_date_str,
        'main_date_filter_field_name': main_date_filter_field_name,
        'early_inplay_filter_choice': early_inplay_filter_choice,
    }

    tasks = []
    added_tasks = set()
    for site_id, site_name in selected_site_map.items():
        for vc in valid_choices:
            venues, filter_type, report_type = choice_map[vc]
            if report_type == 'registered_first_deposit':
                task_key = (site_id, '注册-已首存', 'registered_first_deposit')
                if task_key not in added_tasks:
                    added_tasks.add(task_key)
                    tasks.append((site_id, site_name, "注册-已首存", [], common_params, 'registered_first_deposit'))
            else:
                for chinese_name in venues:
                    actual_codes = grouped_venue_codes.get(chinese_name, [])
                    if not actual_codes:
                        continue
                    final_name = chinese_name
                    if filter_type == 'custom_leagues' and chinese_name == '体育':
                        final_name = "自定义联赛"
                    elif filter_type == 'five_leagues' and chinese_name == '体育':
                        final_name = "5大联赛"
                    elif filter_type == 'nbacba' and chinese_name == '体育':
                        final_name = "NBA-CBA"
                    task_key = (site_id, final_name, filter_type)
                    if task_key not in added_tasks:
                        added_tasks.add(task_key)
                        cp = common_params.copy()
                        cp['filter_type'] = filter_type
                        tasks.append((site_id, site_name, final_name, actual_codes, cp, 'betting_details'))

    if not tasks:
        print("无任务生成。")
        return

    num_outer_processes = cpu_count() or 1
    print(f"\n使用 {num_outer_processes} 进程处理 {len(tasks)} 任务...")

    results = []
    with Pool(processes=num_outer_processes) as pool:
        for result_msg in tqdm(pool.imap_unordered(process_single_task, tasks), total=len(tasks), desc="总进度"):
            results.append(result_msg)

    print("\n--- 任务结果 ---")
    for msg in results:
        print(msg)
    print("----------------")

    end_run_time = datetime.now()
    print(f"\n脚本结束: {end_run_time.strftime('%H:%M:%S')}")
    print(f"总耗时: {str(end_run_time - start_run_time).split('.')[0]}")


if __name__ == "__main__":
    from multiprocessing import freeze_support

    freeze_support()
    main()