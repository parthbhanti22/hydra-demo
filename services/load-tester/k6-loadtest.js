import http from 'k6/http';
import { sleep } from 'k6';

export let options = {
  vus: __ENV.K6_VUS ? parseInt(__ENV.K6_VUS) : 20,
  duration: __ENV.K6_DURATION ? __ENV.K6_DURATION : '60s',
};

export default function () {
  const base = __ENV.TARGET_URL || 'http://app:5000';
  // hit compute with variable work to generate CPU on target
  http.get(`${base}/compute?work=2000000`);
  sleep(0.5);
}
