WITH member_ip AS (

    SELECT DISTINCT

        CAST(bet05 AS BIGINT) AS member_id,

        ip

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'

    AND ip IS NOT NULL

),

ip_members AS (

    SELECT

        ip,

        COUNT(DISTINCT member_id) AS member_count

    FROM member_ip

    GROUP BY ip

)

SELECT

    m.member_id,

    COUNT(DISTINCT m.ip) AS ip_count,

    SUM(
        CASE
            WHEN i.member_count > 1
            THEN 1
            ELSE 0
        END
    ) AS shared_ip_count,

    MAX(i.member_count) AS max_members_per_ip

FROM member_ip m

LEFT JOIN ip_members i

    ON m.ip = i.ip

GROUP BY

    m.member_id;
    