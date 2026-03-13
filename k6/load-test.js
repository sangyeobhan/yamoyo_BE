import http from 'k6/http';
import { check } from 'k6';
import crypto from 'k6/crypto';
import encoding from 'k6/encoding';

const selectedScenario = __ENV.SCENARIO || 'meeting_list_smoke';
const baseUrl = requiredEnv('BASE_URL');
const targetYear = Number(requiredEnv('TARGET_YEAR'));
const targetMonth = Number(requiredEnv('TARGET_MONTH'));
const compareRate = Number(__ENV.COMPARE_RATE || 0);
const poolSize = Number(__ENV.POOL_SIZE || 100);

const tokenPool = buildTokenPool();

const scenarioMap = {
  meeting_list_smoke: {
    executor: 'shared-iterations',
    vus: Number(__ENV.SMOKE_VUS || 1),
    iterations: Number(__ENV.SMOKE_ITERATIONS || 5),
    maxDuration: __ENV.SMOKE_MAX_DURATION || '30s',
    exec: 'meetingListRead',
  },
  meeting_list_capacity_probe: {
    executor: 'ramping-arrival-rate',
    startRate: Number(__ENV.CAPACITY_START_RATE || 50),
    timeUnit: '1s',
    preAllocatedVUs: Number(__ENV.CAPACITY_PREALLOCATED_VUS || 120),
    maxVUs: Number(__ENV.CAPACITY_MAX_VUS || 500),
    stages: [
      { target: Number(__ENV.CAPACITY_STAGE_1_RATE || 50), duration: __ENV.CAPACITY_STAGE_1_DURATION || '1m' },
      { target: Number(__ENV.CAPACITY_STAGE_2_RATE || 100), duration: __ENV.CAPACITY_STAGE_2_DURATION || '1m' },
      { target: Number(__ENV.CAPACITY_STAGE_3_RATE || 200), duration: __ENV.CAPACITY_STAGE_3_DURATION || '1m' },
      { target: Number(__ENV.CAPACITY_STAGE_4_RATE || 300), duration: __ENV.CAPACITY_STAGE_4_DURATION || '1m' },
      { target: Number(__ENV.CAPACITY_STAGE_5_RATE || 400), duration: __ENV.CAPACITY_STAGE_5_DURATION || '1m' },
    ],
    exec: 'meetingListRead',
  },
  meeting_list_same_load_compare: {
    executor: 'constant-arrival-rate',
    rate: compareRate,
    timeUnit: '1s',
    duration: __ENV.COMPARE_DURATION || '3m',
    preAllocatedVUs: Number(__ENV.COMPARE_PREALLOCATED_VUS || 80),
    maxVUs: Number(__ENV.COMPARE_MAX_VUS || 200),
    exec: 'meetingListRead',
  },
};

if (!scenarioMap[selectedScenario]) {
  throw new Error(`Unsupported SCENARIO: ${selectedScenario}`);
}

if (selectedScenario === 'meeting_list_same_load_compare' && compareRate <= 0) {
  throw new Error('COMPARE_RATE is required for meeting_list_same_load_compare');
}

export const options = {
  scenarios: {
    [selectedScenario]: scenarioMap[selectedScenario],
  },
  thresholds: buildThresholds(selectedScenario),
};

export function meetingListRead() {
  const pick = tokenPool[Math.floor(Math.random() * tokenPool.length)];

  const response = http.get(
    `${baseUrl}/api/team-rooms/${pick.teamRoomId}/meetings?year=${targetYear}&month=${targetMonth}`,
    {
      headers: {
        Authorization: `Bearer ${pick.token}`,
      },
      tags: { name: 'getMeetings' },
    }
  );

  let body = null;
  try {
    body = response.json();
  } catch (_) {
    body = null;
  }

  check(response, {
    'status is 200': (res) => res.status === 200,
    'api success is true': () => body !== null && body.success === true,
    'year/month matched': () =>
      body !== null &&
      body.data !== null &&
      body.data.year === targetYear &&
      body.data.month === targetMonth,
    'meeting list exists': () =>
      body !== null &&
      body.data !== null &&
      Array.isArray(body.data.meetings),
  });
}

function buildTokenPool() {
  const secretBase64 = requiredEnv('JWT_SECRET_BASE64');
  const jwtIssuer = __ENV.JWT_ISSUER || 'yamoyo-application';
  const expirationSeconds = Number(__ENV.JWT_ACCESS_EXPIRATION_SECONDS || 3600);
  const provider = __ENV.FIXTURE_PROVIDER || 'test';
  const onboardingStatus = __ENV.FIXTURE_ONBOARDING_STATUS || 'COMPLETED';

  const pool = [];
  for (let roomId = 1; roomId <= poolSize; roomId++) {
    const userId = (roomId * 2) - 1;
    const email = `perf-user-${String(userId).padStart(5, '0')}@yamoyo.test`;
    const token = signJwt(secretBase64, userId, email, provider, onboardingStatus, jwtIssuer, expirationSeconds);
    pool.push({ teamRoomId: roomId, token });
  }
  return pool;
}

function signJwt(secretBase64, userId, email, provider, onboardingStatus, issuer, expirationSeconds) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    sub: String(userId),
    email,
    provider,
    onboardingStatus,
    iss: issuer,
    iat: now,
    exp: now + expirationSeconds,
  };

  const encodedHeader = encoding.b64encode(JSON.stringify(header), 'rawurl');
  const encodedPayload = encoding.b64encode(JSON.stringify(payload), 'rawurl');
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const secret = decodeBase64Secret(secretBase64);
  const signature = crypto.hmac('sha256', secret, signingInput, 'base64rawurl');

  return `${signingInput}.${signature}`;
}

function buildThresholds(scenarioName) {
  const thresholds = {
    'http_req_failed{name:getMeetings}': ['rate<0.01'],
    checks: ['rate>0.99'],
  };

  if (scenarioName !== 'meeting_list_smoke') {
    thresholds['http_req_duration{name:getMeetings}'] = ['p(95)<200'];
  }

  return thresholds;
}

function requiredEnv(name) {
  const value = __ENV[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function decodeBase64Secret(secretBase64) {
  const formats = ['rawurl', 'url', 'rawstd', 'std'];

  for (const format of formats) {
    try {
      return encoding.b64decode(secretBase64, format);
    } catch (_) {
      // Try the next format. The app uses Base64.getUrlDecoder(), but local envs
      // sometimes keep padding or standard alphabet, so we accept both.
    }
  }

  throw new Error('JWT_SECRET_BASE64 must be a valid base64 or base64url value');
}
