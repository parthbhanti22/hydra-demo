import http from 'k6/http';
import { sleep } from 'k6';

export let options = {
  vus: __ENV.K6_VUS ? parseInt(__ENV.K6_VUS) : 50,
  duration: __ENV.K6_DURATION ? __ENV.K6_DURATION : '30s',
  thresholds: {
    http_req_failed: ['rate<0.05']
  }
};

export default function () {
  let url = __ENV.TARGET_URL || 'http://static-site:80/';
  http.get(url);
  sleep(1);
}
