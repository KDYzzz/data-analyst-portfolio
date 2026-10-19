-- ============================================================
-- 소주제2 : 질문은 어떻게 소진되고 학교 사이에서 확산되는가?
-- ============================================================
-- 분석 목적
-- 1. 신규 질문과 기존 질문의 반응 차이 확인
-- 2. 질문 생애주기에 따른 학교 확산 범위 분석
-- 3. 시간 경과에 따른 질문 반응 소진 분석
-- 4. 확산 속도와 반응 유지력을 기준으로 질문 유형화
-- 5. 특정 학교에서 높은 성과를 보이는 질문 검증
--
-- 분석 기준
-- - 실제 답변(answer_status = 'A')을 질문 소비로 정의
-- - 질문별 최초 실제 답변 시점을 Day 0으로 정의
-- - Day 0 ~ Day 14를 중심으로 질문 생애주기 비교
-- ============================================================

-- ============================================================
-- 1. 분석 베이스 데이터
-- 질문 → 행동 → 사용자 → 그룹 → 학교 연결
-- ============================================================
-- 실제 답변(A)의 answer_updated_at을 질문 소비 시점으로 사용
-- 질문별 최초 실제 답변 시점을 Day 0으로 정의

WITH base AS (
    SELECT
        r.id AS question_record_id,
        r.question_id,
        q.question_text,

        -- 답변 사용자
        r.user_id,

        -- 사용자 / 학교 정보
        u.group_id,
        g.school_id,
        s.school_type,
        s.sido,
        s.sigungu,

        -- 실제 답변 시점
        r.answer_updated_at AS answered_at,

        -- 행동 정보
        r.answer_status,
        r.has_read,
        r.report_count,
        r.opened_times

    FROM `da15-team6.last_pj.accounts_userquestionrecord_processed` AS r

    LEFT JOIN `da15-team6.last_pj.polls_question_processed` AS q
        ON r.question_id = q.id

    LEFT JOIN `da15-team6.last_pj.accounts_user` AS u
        ON r.user_id = u.user_id

    LEFT JOIN `da15-team6.last_pj.accounts_group` AS g
        ON u.group_id = g.group_id

    LEFT JOIN `da15-team6.last_pj.accounts_school` AS s
        ON g.school_id = s.school_id

    WHERE r.answer_status = 'A'
      AND r.answer_updated_at IS NOT NULL
)

SELECT
    COUNT(*) AS answered_rows,
    COUNT(DISTINCT question_id) AS answered_questions,
    COUNT(DISTINCT user_id) AS answered_users,
    COUNT(DISTINCT school_id) AS schools,
    MIN(answered_at) AS first_answered_at,
    MAX(answered_at) AS last_answered_at
FROM base;

-- ============================================================
-- 2. 질문별 최초 실제 답변 시점 확인
-- 최초 실제 답변 = Day 0
-- ============================================================

WITH answered AS (
    SELECT
        question_id,
        answer_updated_at AS answered_at
    FROM `da15-team6.last_pj.accounts_userquestionrecord_processed`
    WHERE answer_status = 'A'
      AND answer_updated_at IS NOT NULL
),

question_start AS (
    SELECT
        question_id,
        MIN(answered_at) AS first_answered_at
    FROM answered
    GROUP BY question_id
)

SELECT
    COUNT(*) AS question_count,
    MIN(first_answered_at) AS earliest_question_start,
    MAX(first_answered_at) AS latest_question_start
FROM question_start;

-- ============================================================
-- 3. 질문 생애주기 Day 0 ~ Day 14 생성
-- 각 질문의 최초 실제 답변일을 Day 0으로 계산
-- ============================================================

WITH answered AS (
    SELECT
        r.question_id,
        r.user_id,
        g.school_id,
        r.answer_updated_at AS answered_at

    FROM `da15-team6.last_pj.accounts_userquestionrecord_processed` AS r

    LEFT JOIN `da15-team6.last_pj.accounts_user` AS u
        ON r.user_id = u.user_id

    LEFT JOIN `da15-team6.last_pj.accounts_group` AS g
        ON u.group_id = g.group_id

    WHERE r.answer_status = 'A'
      AND r.answer_updated_at IS NOT NULL
),

-- 질문별 최초 실제 답변 시점
question_start AS (
    SELECT
        question_id,
        MIN(answered_at) AS first_answered_at
    FROM answered
    GROUP BY question_id
),

-- 각 답변이 최초 답변 이후 몇 일째인지 계산
lifecycle AS (
    SELECT
        a.question_id,
        a.user_id,
        a.school_id,
        a.answered_at,
        qs.first_answered_at,

        DATE_DIFF(
            DATE(a.answered_at),
            DATE(qs.first_answered_at),
            DAY
        ) AS lifecycle_day

    FROM answered AS a

    JOIN question_start AS qs
        ON a.question_id = qs.question_id
)

SELECT
    lifecycle_day,
    COUNT(*) AS answer_count,
    COUNT(DISTINCT question_id) AS active_questions,
    COUNT(DISTINCT school_id) AS active_schools
FROM lifecycle

WHERE lifecycle_day BETWEEN 0 AND 14

GROUP BY lifecycle_day
ORDER BY lifecycle_day;

-- ============================================================
-- 4. 질문별 14일 핵심 지표 및 생애주기 유형화
-- 확산 속도 / 반응 유지력 / 학교 확산 범위를 한 번에 계산
-- ============================================================

WITH answered AS (
    SELECT
        r.question_id,
        q.question_text,
        r.user_id,
        g.school_id,
        r.answer_updated_at AS answered_at

    FROM `da15-team6.last_pj.accounts_userquestionrecord_processed` AS r

    LEFT JOIN `da15-team6.last_pj.polls_question_processed` AS q
        ON r.question_id = q.id

    LEFT JOIN `da15-team6.last_pj.accounts_user` AS u
        ON r.user_id = u.user_id

    LEFT JOIN `da15-team6.last_pj.accounts_group` AS g
        ON u.group_id = g.group_id

    WHERE r.answer_status = 'A'
      AND r.answer_updated_at IS NOT NULL
),

-- 질문별 최초 실제 답변 시점
question_start AS (
    SELECT
        question_id,
        MIN(answered_at) AS first_answered_at
    FROM answered
    GROUP BY question_id
),

-- 질문별 생애주기 Day 계산
lifecycle AS (
    SELECT
        a.question_id,
        a.question_text,
        a.user_id,
        a.school_id,
        a.answered_at,
        qs.first_answered_at,

        DATE_DIFF(
            DATE(a.answered_at),
            DATE(qs.first_answered_at),
            DAY
        ) AS lifecycle_day

    FROM answered AS a

    JOIN question_start AS qs
        ON a.question_id = qs.question_id
),

-- 질문별 Day 0~14 핵심 지표
question_metrics AS (
    SELECT
        question_id,
        ANY_VALUE(question_text) AS question_text,
        MIN(first_answered_at) AS first_answered_at,

        -- Day 0~14 누적 답변량
        COUNTIF(
            lifecycle_day BETWEEN 0 AND 14
        ) AS answers_14d,

        -- 초기 반응: Day 0~3
        COUNTIF(
            lifecycle_day BETWEEN 0 AND 3
        ) AS early_answers,

        -- 후기 반응: Day 8~14
        COUNTIF(
            lifecycle_day BETWEEN 8 AND 14
        ) AS late_answers,

        -- Day 3까지 도달한 학교 수
        COUNT(
            DISTINCT IF(
                lifecycle_day BETWEEN 0 AND 3,
                school_id,
                NULL
            )
        ) AS schools_day3,

        -- Day 14까지 도달한 학교 수
        COUNT(
            DISTINCT IF(
                lifecycle_day BETWEEN 0 AND 14,
                school_id,
                NULL
            )
        ) AS schools_day14

    FROM lifecycle
    GROUP BY question_id
),

-- 질문별 후기 반응 유지도 계산
metrics_with_retention AS (
    SELECT
        *,

        SAFE_DIVIDE(
            late_answers / 7.0,
            early_answers / 4.0
        ) AS retention_ratio

    FROM question_metrics
),

-- 전체 질문의 후기 반응 유지도 중앙값
retention_threshold AS (
    SELECT
        APPROX_QUANTILES(
            retention_ratio,
            100
        )[OFFSET(50)] AS median_retention

    FROM metrics_with_retention
    WHERE retention_ratio IS NOT NULL
)

SELECT
    m.question_id,
    m.question_text,
    m.first_answered_at,
    m.answers_14d,
    m.early_answers,
    m.late_answers,
    m.schools_day3,
    m.schools_day14,
    m.retention_ratio,

    -- 학교 확산 속도
    CASE
        WHEN m.schools_day3 >= 6
            THEN '빠른 확산'
        ELSE '느린 확산'
    END AS spread_type,

    -- 최종 질문 생애주기 4가지 유형
    CASE
        WHEN m.schools_day3 >= 6
             AND m.retention_ratio >= r.median_retention
            THEN '빠른 확산·장기 유지형'

        WHEN m.schools_day3 >= 6
             AND m.retention_ratio < r.median_retention
            THEN '빠른 확산·소진형'

        WHEN m.schools_day3 < 6
             AND m.retention_ratio >= r.median_retention
            THEN '느린 확산·장기 유지형'

        ELSE '느린 확산·소진형'
    END AS lifecycle_type

FROM metrics_with_retention AS m

CROSS JOIN retention_threshold AS r

ORDER BY m.answers_14d DESC;