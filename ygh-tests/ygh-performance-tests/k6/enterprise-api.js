import http from "k6/http";
import { check, fail } from "k6";
import { Rate, Trend } from "k6/metrics";

const queryLatency = new Trend("ygh_query_latency", true);
const writeLatency = new Trend("ygh_write_latency", true);
const searchLatency = new Trend("ygh_search_latency", true);
const errors = new Rate("ygh_api_errors");

export const options = {
  scenarios: {
    ordinary_queries: { executor: "constant-vus", exec: "query", vus: 5, duration: "60s" },
    ordinary_writes: { executor: "constant-arrival-rate", exec: "write", rate: 1, timeUnit: "1s", duration: "60s", preAllocatedVUs: 2 },
    product_search: { executor: "constant-vus", exec: "search", vus: 3, duration: "60s" },
  },
  thresholds: {
    ygh_api_errors: ["rate<0.01"],
    ygh_query_latency: ["p(95)<500"],
    ygh_write_latency: ["p(95)<1000"],
    ygh_search_latency: ["p(95)<1000"],
  },
};

const base = __ENV.YGH_GATEWAY_URL || "http://127.0.0.1:8080";
const token = __ENV.YGH_ACCESS_TOKEN;
const headers = token ? { Authorization: `Bearer ${token}` } : {};

export function setup() {
  if (!token) fail("YGH_ACCESS_TOKEN is required; obtain it from the dedicated performance account");
}

function verify(response, metric) {
  const ok = check(response, { "HTTP 2xx": (result) => result.status >= 200 && result.status < 300 });
  errors.add(!ok);
  metric.add(response.timings.duration);
}

export function query() {
  verify(http.get(`${base}/api/v1/knowledge/documents?limit=20`, { headers }), queryLatency);
}

export function search() {
  verify(http.get(`${base}/api/v1/products?keyword=%E8%8D%94%E6%9E%9D&limit=20`, { headers }), searchLatency);
}

export function write() {
  const requestId = `perf-${__VU}-${__ITER}-${Date.now()}`;
  const response = http.post(
    `${base}/api/v1/wallet/recharges`,
    JSON.stringify({ requestId, referenceId: requestId, amount: 0.01, currency: "CNY" }),
    { headers: { ...headers, "Content-Type": "application/json", "Idempotency-Key": requestId } },
  );
  verify(response, writeLatency);
}
