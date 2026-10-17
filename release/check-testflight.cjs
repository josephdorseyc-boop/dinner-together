'use strict';

// Read-only Apple processing check. Credentials stay in this process; only
// the requested build's status is written. No app, build or tester is changed.
// https://developer.apple.com/documentation/appstoreconnectapi/get-v1-builds
const { createPrivateKey, sign } = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const API = 'https://api.appstoreconnect.apple.com';
class CheckError extends Error {
  constructor(message, retryable = false) { super(message); this.retryable = retryable; }
}
function token({ keyId, issuerId, privateKey }, seconds = Math.floor(Date.now() / 1000)) {
  const enc = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const input = `${enc({ alg: 'ES256', kid: keyId, typ: 'JWT' })}.${enc({ iss: issuerId, iat: seconds - 20, exp: seconds + 600, aud: 'appstoreconnect-v1' })}`;
  return `${input}.${sign('sha256', Buffer.from(input), { key: privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}
function createClient(credentials, fetchImpl = fetch) {
  let privateKey;
  try { privateKey = createPrivateKey(credentials.key); }
  catch { throw new CheckError('The configured Apple API key could not be loaded'); }
  if (privateKey.asymmetricKeyType !== 'ec' || privateKey.asymmetricKeyDetails?.namedCurve !== 'prime256v1') {
    throw new CheckError('The configured Apple API key must support ES256');
  }
  return {
    async get(route, parameters = {}) {
      const url = new URL(route, API);
      if (url.origin !== API || !/^\/v1\/(apps|builds)$/.test(url.pathname)) {
        throw new CheckError('Only the Apple app and build status endpoints are allowed');
      }
      url.search = new URLSearchParams(parameters).toString();
      let response;
      try {
        response = await fetchImpl(url, {
          method: 'GET', redirect: 'error', signal: AbortSignal.timeout(20000),
          headers: { Authorization: `Bearer ${token({ keyId: credentials.keyId, issuerId: credentials.issuerId, privateKey })}`, Accept: 'application/json' }
        });
      } catch { throw new CheckError('Apple status request was unavailable', true); }
      if (!response.ok) {
        const status = Number(response.status) || 0;
        // Do not print a response body, headers, JWT or key, even on failure.
        throw new CheckError(`Apple status request returned HTTP ${status}`, status === 429 || status >= 500);
      }
      try { return await response.json(); }
      catch { throw new CheckError('Apple returned an unreadable status response'); }
    }
  };
}
function snapshot(document, config) {
  if (!Array.isArray(document.data)) throw new CheckError('Apple build response is missing its build list');
  const included = new Map((document.included || []).map(item => [`${item.type}/${item.id}`, item]));
  const candidates = document.data.filter(build => {
    const version = build.relationships?.preReleaseVersion?.data;
    const train = included.get(`preReleaseVersions/${version?.id}`);
    return build.type === 'builds' && build.relationships?.app?.data?.id === config.appId && build.attributes?.version === config.buildVersion &&
      train?.attributes?.version === config.appVersion && train.attributes.platform === 'IOS';
  });
  if (candidates.length > 1) throw new CheckError('Apple returned more than one matching iOS build');
  const result = { appVersion: config.appVersion, buildVersion: config.buildVersion, ready: false, processingState: 'NOT_VISIBLE' };
  if (!candidates.length) return result;
  const build = candidates[0], attributes = build.attributes;
  if (!/^[A-Za-z0-9-]{1,64}$/.test(build.id)) throw new CheckError('Apple returned an invalid build identifier');
  const betaRef = build.relationships?.buildBetaDetail?.data;
  const beta = included.get(`buildBetaDetails/${betaRef?.id}`)?.attributes;
  const state = value => typeof value === 'string' && /^[A-Z_]{1,64}$/.test(value) ? value : 'UNKNOWN';
  Object.assign(result, {
    buildId: build.id, processingState: state(attributes.processingState),
    expired: typeof attributes.expired === 'boolean' ? attributes.expired : null,
    uploadedDate: Number.isFinite(Date.parse(attributes.uploadedDate)) ? attributes.uploadedDate : null,
    internalBuildState: state(beta?.internalBuildState), externalBuildState: state(beta?.externalBuildState)
  });
  result.ready = result.processingState === 'VALID' && result.expired === false &&
    ['READY_FOR_BETA_TESTING', 'IN_BETA_TESTING'].includes(result.internalBuildState);
  if (['FAILED', 'INVALID'].includes(result.processingState) || result.expired === true ||
      ['MISSING_EXPORT_COMPLIANCE', 'PROCESSING_EXCEPTION', 'EXPIRED'].includes(result.internalBuildState)) {
    result.blocker = ['FAILED', 'INVALID'].includes(result.processingState) ? result.processingState : result.expired ? 'EXPIRED' : result.internalBuildState;
  }
  return result;
}
async function monitor({ api, config, report, now = Date.now, sleep = ms => new Promise(resolve => setTimeout(resolve, ms)) }) {
  const apps = await api.get('/v1/apps', { 'filter[bundleId]': config.bundleId, limit: '2' });
  if (!Array.isArray(apps.data) || apps.data.length !== 1 ||
      apps.data[0].attributes?.bundleId !== config.bundleId || !/^\d+$/.test(apps.data[0].id)) {
    throw new CheckError('The configured bundle must resolve to exactly one Apple app');
  }
  const appId = apps.data[0].id, deadline = now() + config.waitSeconds * 1000;
  do {
    let result;
    try {
      const document = await api.get('/v1/builds', {
        'filter[app]': appId, 'filter[version]': config.buildVersion,
        include: 'app,preReleaseVersion,buildBetaDetail', limit: '200'
      });
      result = { appId, ...snapshot(document, { ...config, appId }) };
    } catch (error) {
      if (!(error instanceof CheckError) || !error.retryable) throw error;
      result = { appId, appVersion: config.appVersion, buildVersion: config.buildVersion, ready: false, processingState: 'API_UNAVAILABLE' };
    }
    report({ ...result, checkedAt: new Date().toISOString() });
    if (result.ready) return result;
    if (result.blocker) throw new CheckError(`Apple reports a build blocker: ${result.blocker}`);
    if (now() >= deadline) break;
    await sleep(Math.min(30000, deadline - now()));
  } while (now() <= deadline);
  throw new CheckError('Apple has not reported internal TestFlight readiness within the check window');
}
async function main() {
  const out = path.resolve(process.argv[2] || 'release/testflight-status');
  fs.mkdirSync(out, { recursive: true, mode: 0o700 });
  let latest = { ready: false, processingState: 'NOT_CHECKED' };
  const report = value => {
    latest = value;
    fs.writeFileSync(path.join(out, 'status.json'), JSON.stringify(value, null, 2) + '\n', { mode: 0o600 });
    const summary = `# TestFlight processing check\n\nVersion ${value.appVersion || '?'} (${value.buildVersion || '?'})\n\nProcessing: ${value.processingState}\n\nInternal testing: ${value.internalBuildState || 'UNKNOWN'}\n\nReady for internal TestFlight: ${value.ready === true}\n`;
    fs.writeFileSync(path.join(out, 'SUMMARY.md'), summary, { mode: 0o600 });
    console.log(`Build ${value.appVersion || '?'} (${value.buildVersion || '?'}): ${value.processingState}; internal=${value.internalBuildState || 'UNKNOWN'}; ready=${value.ready === true}`);
  };
  report(latest);
  try {
    for (const name of ['ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_KEY_P8', 'DT_BUNDLE_ID', 'DT_APP_VERSION', 'DT_BUILD']) {
      if (!process.env[name]) throw new CheckError(`Missing required setting: ${name}`);
    }
    const config = { bundleId: process.env.DT_BUNDLE_ID, appVersion: process.env.DT_APP_VERSION, buildVersion: process.env.DT_BUILD, waitSeconds: Number(process.env.DT_STATUS_WAIT_SECONDS || 1800) };
    if (!/^\d+\.\d+(\.\d+)?$/.test(config.appVersion) || !/^\d+$/.test(config.buildVersion) ||
        !Number.isInteger(config.waitSeconds) || config.waitSeconds < 0 || config.waitSeconds > 3600) {
      throw new CheckError('Invalid requested version, build or check duration');
    }
    const api = createClient({ keyId: process.env.ASC_KEY_ID, issuerId: process.env.ASC_ISSUER_ID, key: process.env.ASC_KEY_P8 });
    await monitor({ api, config, report });
  } catch (error) {
    const message = error instanceof CheckError ? error.message : 'TestFlight status check could not be completed';
    report({ ...latest, ready: false, error: message });
    console.error(message);
    process.exitCode = 1;
  }
}
module.exports = { CheckError, token, createClient, snapshot, monitor };
if (require.main === module) main();
