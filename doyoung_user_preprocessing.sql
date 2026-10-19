-- =========================================================
-- 유저 기본 특성 및 속성 전처리
-- 대상 테이블
--   1) user_properties
--   2) accounts_user
--
-- 전처리 기준
-- - user_properties를 기준 테이블로 사용
-- - accounts_user는 LEFT JOIN
-- - 전체 230,819명 유지
-- - accounts_user 매칭 226,329명
-- - 미매칭 4,490명은 삭제하지 않고 account_matched = 0으로 관리
-- - gender는 user_properties 기준 사용
--   (매칭 사용자 226,329명에서 accounts_user.gender와 100% 일치)
-- - point는 극단값이 존재하므로 원본값을 그대로 보존
-- - ban_status는 코드 의미가 확인되지 않아 원본값 그대로 보존
-- =========================================================


-- 1. 최종 user_master
SELECT
    up.user_id AS user_id,

    -- 사용자 기본 특성
    up.gender,
    up.grade,
    up.class,
    up.school_id,

    -- 계정 및 소속 정보
    au.group_id,
    au.created_at,

    -- 가입 시점 파생 변수
    DATE(au.created_at) AS signup_date,
    YEAR(au.created_at) AS signup_year,
    MONTH(au.created_at) AS signup_month,

    -- 사용자 상태 및 활동 관련 정보
    au.point,
    au.ban_status,
    au.report_count,

    -- accounts_user 매칭 여부
    CASE
        WHEN au.id IS NOT NULL THEN 1
        ELSE 0
    END AS account_matched

FROM user_properties up

LEFT JOIN accounts_user au
    ON au.id = CAST(up.user_id AS UNSIGNED);

    -- =========================================================
-- 2. 결과 검증
-- 예상 결과
-- total_users      : 230819
-- unique_users     : 230819
-- matched_users    : 226329
-- unmatched_users  : 4490
-- =========================================================

SELECT
    COUNT(*) AS total_users,
    COUNT(DISTINCT up.user_id) AS unique_users,
    SUM(au.id IS NOT NULL) AS matched_users,
    SUM(au.id IS NULL) AS unmatched_users

FROM user_properties up

LEFT JOIN accounts_user au
    ON au.id = CAST(up.user_id AS UNSIGNED);