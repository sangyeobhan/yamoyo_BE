-- Meeting list performance fixture
-- Run this only after Flyway migrations have created the current schema.
--
-- Deterministic fixture values for k6:
--   TEAM_ROOM_ID=1
--   TARGET_YEAR=2026
--   TARGET_MONTH=3
--   FIXTURE_USER_ID=1
--   FIXTURE_EMAIL=perf-user-00001@yamoyo.test
--   FIXTURE_PROVIDER=test
--   FIXTURE_ONBOARDING_STATUS=COMPLETED
--
-- Seed shape:
--   users                20,000
--   team_rooms           10,000
--   team_members         40,000
--   timepicks            10,000
--   timepick_participants 40,000
--   meeting_series       10,000
--   meetings             150,000
--   meeting_participants 600,000

SET SESSION cte_max_recursion_depth = 20000;
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE banned_team_members;
TRUNCATE TABLE member_rule_votes;
TRUNCATE TABLE member_tool_votes;
TRUNCATE TABLE meeting_participants;
TRUNCATE TABLE meetings;
TRUNCATE TABLE meeting_series;
TRUNCATE TABLE notifications;
TRUNCATE TABLE refresh_tokens;
TRUNCATE TABLE social_accounts;
TRUNCATE TABLE team_members;
TRUNCATE TABLE team_room_setups;
TRUNCATE TABLE team_rules;
TRUNCATE TABLE team_tool_proposals;
TRUNCATE TABLE team_tools;
TRUNCATE TABLE timepick_participants;
TRUNCATE TABLE timepicks;
TRUNCATE TABLE user_agreements;
TRUNCATE TABLE user_devices;
TRUNCATE TABLE user_timepick_defaults;
TRUNCATE TABLE users;
TRUNCATE TABLE team_rooms;
TRUNCATE TABLE terms;
TRUNCATE TABLE rule_templates;

SET FOREIGN_KEY_CHECKS = 1;

DROP TEMPORARY TABLE IF EXISTS tmp_numbers;
DROP TEMPORARY TABLE IF EXISTS tmp_rooms;
DROP TEMPORARY TABLE IF EXISTS tmp_weeks;
DROP TEMPORARY TABLE IF EXISTS tmp_room_members;

CREATE TEMPORARY TABLE tmp_numbers (
    n INT NOT NULL PRIMARY KEY
);

INSERT INTO tmp_numbers (n)
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM seq
    WHERE n < 20000
)
SELECT n
FROM seq;

CREATE TEMPORARY TABLE tmp_rooms (
    room_id INT NOT NULL PRIMARY KEY
);

INSERT INTO tmp_rooms (room_id)
SELECT n
FROM tmp_numbers
WHERE n <= 10000;

CREATE TEMPORARY TABLE tmp_weeks (
    week_offset INT NOT NULL PRIMARY KEY
);

INSERT INTO tmp_weeks (week_offset)
VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12), (13), (14);

CREATE TEMPORARY TABLE tmp_room_members (
    room_id INT NOT NULL,
    slot TINYINT NOT NULL,
    user_id INT NOT NULL,
    team_role VARCHAR(10) NOT NULL,
    PRIMARY KEY (room_id, slot),
    KEY idx_tmp_room_members_user_id (user_id)
);

INSERT INTO tmp_room_members (room_id, slot, user_id, team_role)
SELECT room_id, 1, (room_id * 2) - 1, 'LEADER'
FROM tmp_rooms
UNION ALL
SELECT room_id, 2, room_id * 2, 'MEMBER'
FROM tmp_rooms
UNION ALL
SELECT room_id, 3, (IF(room_id = 10000, 1, room_id + 1) * 2) - 1, 'MEMBER'
FROM tmp_rooms
UNION ALL
SELECT room_id, 4, IF(room_id = 10000, 1, room_id + 1) * 2, 'MEMBER'
FROM tmp_rooms;

INSERT INTO terms (
    terms_id,
    terms_type,
    title,
    content,
    version,
    is_mandatory,
    is_active,
    created_at
)
VALUES
    (
        1,
        'SERVICE',
        '서비스 이용약관',
        'Performance fixture terms for meeting-list load testing.',
        '1.0',
        1,
        1,
        '2026-01-01 00:00:00'
    ),
    (
        2,
        'PRIVACY',
        '개인정보 처리방침',
        'Performance fixture privacy policy for meeting-list load testing.',
        '1.0',
        1,
        1,
        '2026-01-01 00:00:00'
    );

INSERT INTO rule_templates (rule_id, content)
VALUES
    (1, '읽고 씹지 않기'),
    (2, '연락 가능 시간 준수'),
    (3, '회의 불참 사전 공유'),
    (4, '회의 지각 패널티 적용'),
    (5, '질문 사전 전달'),
    (6, '회의 안건 사전 확인'),
    (7, '개인 일정 사전 공유'),
    (8, '업무 요청 시 목적·기한 명시'),
    (9, '업무 마감 책임 준수'),
    (10, '팀 내 존중하는 소통');

INSERT INTO users (
    user_id,
    name,
    email,
    profile_image_id,
    major,
    mbti,
    is_alarm_on,
    user_role,
    onboarding_status,
    created_at,
    updated_at
)
SELECT
    n,
    CONCAT('PerfUser', LPAD(n, 5, '0')),
    CONCAT('perf-user-', LPAD(n, 5, '0'), '@yamoyo.test'),
    ((n - 1) % 5) + 1,
    ELT(
        ((n - 1) % 8) + 1,
        '컴퓨터공학',
        '경영학',
        '전자공학',
        '심리학',
        '디자인학',
        '경제학',
        '수학',
        '물리학'
    ),
    ELT(
        ((n - 1) % 16) + 1,
        'INTJ',
        'INTP',
        'ENTJ',
        'ENTP',
        'INFJ',
        'INFP',
        'ENFJ',
        'ENFP',
        'ISTJ',
        'ISFJ',
        'ESTJ',
        'ESFJ',
        'ISTP',
        'ISFP',
        'ESTP',
        'ESFP'
    ),
    1,
    'USER',
    'COMPLETED',
    '2026-01-01 00:00:00',
    '2026-01-01 00:00:00'
FROM tmp_numbers;

INSERT INTO social_accounts (
    social_account_id,
    user_id,
    provider,
    provider_id,
    email,
    created_at
)
SELECT
    user_id,
    user_id,
    'test',
    CONCAT('perf-provider-', LPAD(user_id, 5, '0')),
    email,
    '2026-01-01 00:00:00'
FROM users;

INSERT INTO user_agreements (
    agreement_id,
    user_id,
    terms_id,
    is_agreed,
    agreed_at
)
SELECT
    ((u.user_id - 1) * 2) + t.terms_id,
    u.user_id,
    t.terms_id,
    1,
    '2026-01-01 00:00:00'
FROM users u
CROSS JOIN terms t;

INSERT INTO user_timepick_defaults (
    user_timepick_default_id,
    user_id,
    preferred_block,
    availability_mon,
    availability_tue,
    availability_wed,
    availability_thu,
    availability_fri,
    availability_sat,
    availability_sun,
    created_at,
    updated_at
)
SELECT
    user_id,
    user_id,
    'BLOCK_16_20',
    281474976710655,
    281474976710655,
    281474976710655,
    281474976710655,
    281474976710655,
    281474976710655,
    281474976710655,
    '2026-01-01 00:00:00',
    '2026-01-01 00:00:00'
FROM users;

INSERT INTO team_rooms (
    team_room_id,
    title,
    description,
    deadline,
    lifecycle,
    workflow,
    banner_image_id,
    created_at,
    updated_at
)
SELECT
    room_id,
    CONCAT('Perf Room ', LPAD(room_id, 5, '0')),
    CONCAT('Meeting load fixture ', LPAD(room_id, 5, '0')),
    '2026-12-31 23:59:59',
    'ACTIVE',
    'COMPLETED',
    ((room_id - 1) % 5) + 1,
    '2026-01-01 00:00:00',
    '2026-01-01 00:00:00'
FROM tmp_rooms;

INSERT INTO team_members (
    member_id,
    user_id,
    team_room_id,
    team_role,
    created_at,
    updated_at
)
SELECT
    ((room_id - 1) * 4) + slot,
    user_id,
    room_id,
    team_role,
    '2026-01-01 00:00:00',
    '2026-01-01 00:00:00'
FROM tmp_room_members
ORDER BY room_id, slot;

INSERT INTO team_room_setups (
    setup_id,
    team_room_id,
    tool_completed,
    rule_completed,
    meeting_completed,
    created_at,
    deadline
)
SELECT
    room_id,
    room_id,
    1,
    1,
    1,
    '2026-01-01 00:00:00',
    '2026-01-01 06:00:00'
FROM tmp_rooms;

INSERT INTO timepicks (
    timepick_id,
    team_room_id,
    status,
    deadline,
    created_at,
    finalized_at
)
SELECT
    room_id,
    room_id,
    'FINALIZED',
    '2026-01-02 00:00:00',
    '2026-01-01 00:00:00',
    '2026-01-02 00:00:00'
FROM tmp_rooms;

INSERT INTO timepick_participants (
    timepick_participant_id,
    timepick_id,
    user_id,
    preferred_block,
    availability_status,
    preferred_block_status,
    availability_mon,
    availability_tue,
    availability_wed,
    availability_thu,
    availability_fri,
    availability_sat,
    availability_sun,
    submitted_at,
    created_at,
    updated_at
)
SELECT
    ((room_id - 1) * 4) + slot,
    room_id,
    user_id,
    'BLOCK_16_20',
    'SUBMITTED',
    'SUBMITTED',
    281474976710655,
    281474976710655,
    281474976710655,
    281474976710655,
    281474976710655,
    281474976710655,
    281474976710655,
    '2026-01-01 00:00:00',
    '2026-01-01 00:00:00',
    '2026-01-01 00:00:00'
FROM tmp_room_members
ORDER BY room_id, slot;

INSERT INTO meeting_series (
    meeting_series_id,
    team_room_id,
    meeting_type,
    day_of_week,
    default_start_time,
    default_duration_minutes,
    creator_name,
    created_at,
    updated_at
)
SELECT
    room_id,
    room_id,
    'INITIAL_REGULAR',
    ELT(((room_id - 1) % 5) + 1, 'MON', 'TUE', 'WED', 'THU', 'FRI'),
    '19:00:00',
    60,
    CONCAT('PerfUser', LPAD((room_id * 2) - 1, 5, '0')),
    '2026-01-01 00:00:00',
    '2026-01-01 00:00:00'
FROM tmp_rooms;

INSERT INTO meetings (
    meeting_id,
    meeting_series_id,
    title,
    location,
    start_time,
    duration_minutes,
    color,
    description,
    is_individually_modified,
    created_at,
    updated_at
)
SELECT
    ((r.room_id - 1) * 15) + w.week_offset + 1,
    r.room_id,
    CONCAT('Weekly Meeting ', LPAD(r.room_id, 5, '0')),
    CONCAT('Room ', ((r.room_id - 1) % 20) + 1),
    DATE_ADD(
        '2026-01-05 19:00:00',
        INTERVAL (((r.room_id - 1) % 5) + (w.week_offset * 7)) DAY
    ),
    60,
    'PURPLE',
    NULL,
    0,
    '2026-01-01 00:00:00',
    '2026-01-01 00:00:00'
FROM tmp_rooms r
CROSS JOIN tmp_weeks w
ORDER BY r.room_id, w.week_offset;

INSERT INTO meeting_participants (
    meeting_participant_id,
    meeting_id,
    user_id,
    created_at
)
SELECT
    (((((r.room_id - 1) * 15) + w.week_offset + 1) - 1) * 4) + rm.slot,
    ((r.room_id - 1) * 15) + w.week_offset + 1,
    rm.user_id,
    '2026-01-01 00:00:00'
FROM tmp_rooms r
CROSS JOIN tmp_weeks w
JOIN tmp_room_members rm
    ON rm.room_id = r.room_id
ORDER BY r.room_id, w.week_offset, rm.slot;

DROP TEMPORARY TABLE IF EXISTS tmp_room_members;
DROP TEMPORARY TABLE IF EXISTS tmp_weeks;
DROP TEMPORARY TABLE IF EXISTS tmp_rooms;
DROP TEMPORARY TABLE IF EXISTS tmp_numbers;

-- Expected quick sanity checks after the seed:
--   SELECT COUNT(*) FROM users;                 -- 20000
--   SELECT COUNT(*) FROM team_rooms;            -- 10000
--   SELECT COUNT(*) FROM meetings;              -- 150000
--   SELECT COUNT(*) FROM meeting_participants;  -- 600000
--   SELECT COUNT(*) FROM team_members;          -- 40000
