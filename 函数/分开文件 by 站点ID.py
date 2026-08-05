import os
import pandas as pd


def split_excel_by_station(file_path, output_dir="./拆分结果"):
    """根据 '站点' 列的内容，将一个 Excel 文件拆分为多个独立的 Excel 文件。

    :param file_path: 包含原始数据的 Excel 文件路径
    :param output_dir: 拆分后文件的保存目录，默认为当前目录下的 '拆分结果' 文件夹
    """
    # 1. 确保输出目录存在，如果不存在则自动创建
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"创建输出目录: {output_dir}")

    try:
        # 2. 读取原始 Excel 文件
        print(f"正在读取文件: {file_path} ...")
        # 如果你的数据不在第一个工作表，可以通过 sheet_name='工作表名称' 来指定
        df = pd.read_excel(file_path)

        # 检查 '站点' 列是否存在
        if "站点" not in df.columns:
            print("错误：文件中未找到名为 '站点' 的列，请检查列名是否正确！")
            return

        # 3. 获取 '站点' 列所有不重复的内容
        # .dropna() 可以排除掉站点为空的行（如果需要包含空站点，可以去掉它）
        unique_stations = df["站点"].dropna().unique()
        print(f"检测到共有 {len(unique_stations)} 个不同的站点。")

        # 4. 循环遍历每个站点，过滤数据并单独保存
        for station in unique_stations:
            # 过滤出当前站点的数据
            station_df = df[df["站点"] == station]

            # 移除非法字符（Windows文件名不能包含 \ / : * ? " < > |）
            safe_station_name = str(station)
            for char in ["\\", "/", ":", "*", "?", '"', "<", ">", "|"]:
                safe_station_name = safe_station_name.replace(char, "_")

            # 拼接输出文件的完整路径
            output_file_path = os.path.join(
                output_dir, f"{safe_station_name} 2026-07-17 当天充值成功的会员 含所有充值方式及渠道.xlsx"
            )

            # 保存为新的 Excel 文件（index=False 表示不保存行索引）
            station_df.to_excel(output_file_path, index=False)
            print(f"成功保存: {output_file_path} (共 {len(station_df)} 行)")

        print("\n所有站点数据拆分完成！")

    except Exception as e:
        print(f"运行过程中发生错误: {e}")


# ==================== 使用示例 ====================
if __name__ == "__main__":
    # 请将下面的 '原始数据.xlsx' 替换为你实际的 Excel 文件路径
    input_file = r"C:\Users\PCCPPPCCC\PycharmProjects\FastAPIProject\存款单号_全部站点_2026-07-17_2026-07-17.xlsx"

    # 执行拆分函数
    split_excel_by_station(input_file)