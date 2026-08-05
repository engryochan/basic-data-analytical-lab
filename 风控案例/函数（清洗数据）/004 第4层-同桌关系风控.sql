WITH bet_base AS (

    SELECT DISTINCT

        CAST(bet05 AS BIGINT) AS member_id,

        CAST(bet03 AS BIGINT) AS session_id,

        CAST(bet31 AS BIGINT) AS table_id,

        dt

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'

    AND (
        bet30 IS NULL
        OR bet30 <> 'Y'
    )
),

member_session AS (

    SELECT

        member_id,

        COUNT(DISTINCT session_id) AS total_sessions

    FROM bet_base

    GROUP BY member_id
),

pair_session AS (

    SELECT

        a.member_id AS member_a,

        b.member_id AS member_b,

        COUNT(DISTINCT a.session_id) AS same_session_count,

        COUNT(DISTINCT a.table_id) AS same_table_count,

        MIN(a.dt) AS first_same_date,

        MAX(a.dt) AS last_same_date

    FROM bet_base a

    JOIN bet_base b

        ON a.session_id = b.session_id

       AND a.table_id = b.table_id

       AND a.member_id < b.member_id

    GROUP BY

        a.member_id,

        b.member_id
)

SELECT

    p.member_a,

    p.member_b,

    p.same_session_count,

    p.same_table_count,

    a.total_sessions AS member_a_sessions,

    b.total_sessions AS member_b_sessions,

    CASE

        WHEN a.total_sessions > 0

        THEN p.same_session_count / a.total_sessions

        ELSE 0

    END AS same_rate_a,

    CASE

        WHEN b.total_sessions > 0

        THEN p.same_session_count / b.total_sessions

        ELSE 0

    END AS same_rate_b,

    p.first_same_date,

    p.last_same_date,

    DATEDIFF(
        p.last_same_date,
        p.first_same_date
    ) AS relationship_days

FROM pair_session p

LEFT JOIN member_session a

    ON p.member_a = a.member_id

LEFT JOIN member_session b

    ON p.member_b = b.member_id

WHERE p.same_session_count >= 3

ORDER BY

    same_session_count DESC;
