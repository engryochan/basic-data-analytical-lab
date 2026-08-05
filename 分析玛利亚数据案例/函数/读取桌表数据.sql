-- 第一批（前 10 万会员）
SELECT 
  bet05 AS 会员编号, 
  SUM(bet13) AS 下注金额, 
  AVG(bet14) AS `平均返水%数`,  -- 建议改为平均
  SUM(bet30) AS 取消单总数
FROM ods_a168_bet01
GROUP BY bet05
ORDER BY bet05  -- 必须排序保证分页顺序一致
LIMIT 100000 OFFSET 0;

-- 第二批（10万~20万）
-- LIMIT 100000 OFFSET 100000;

-- 第三批
-- LIMIT 100000 OFFSET 200000;

-- 那么可以在Superset上`SQL工具`调用派森与鄀计数编程语言吗？自动下载平台上所有会员的盈亏报告
