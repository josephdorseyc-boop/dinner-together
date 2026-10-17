'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { generateKeyPairSync, verify } = require('node:crypto');
const { CheckError, token, createClient, snapshot, monitor } = require('./check-testflight.cjs');
const config = { bundleId: 'com.example.verification', appId: '12345', appVersion: '1.0', buildVersion: '22', waitSeconds: 60 };
function document(processing = 'VALID', internal = 'IN_BETA_TESTING', extra = {}) {
  return {
    data: [{ type: 'builds', id: 'build-22', attributes: { version: '22', processingState: processing, expired: false, uploadedDate: '2026-10-17T03:00:00Z', ...extra }, relationships: { app: { data: { id: '12345' } }, preReleaseVersion: { data: { id: 'train-1' } }, buildBetaDetail: { data: { id: 'beta-22' } } } }],
    included: [{ type: 'preReleaseVersions', id: 'train-1', attributes: { version: '1.0', platform: 'IOS' } }, { type: 'buildBetaDetails', id: 'beta-22', attributes: { internalBuildState: internal, externalBuildState: 'WAITING_FOR_BETA_REVIEW' } }]
  };
}
test('Apple JWT uses a verifiable ES256 signature and bounded audience/lifetime', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const jwt = token({ keyId: 'test-key', issuerId: 'test-issuer', privateKey }, 1000);
  const [header, payload, signature] = jwt.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(header, 'base64url')), { alg: 'ES256', kid: 'test-key', typ: 'JWT' });
  const claims = JSON.parse(Buffer.from(payload, 'base64url'));
  assert.equal(claims.aud, 'appstoreconnect-v1');
  assert.equal(claims.iss, 'test-issuer');
  assert.ok(claims.exp - claims.iat <= 1200);
  assert.equal(Buffer.from(signature, 'base64url').length, 64);
  assert.ok(verify('sha256', Buffer.from(`${header}.${payload}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(signature, 'base64url')));
});
test('client is GET-only, fixed to Apple, and refuses redirects/other endpoints', async () => {
  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  let calls = 0;
  const api = createClient({ keyId: 'test-key', issuerId: 'test-issuer', key: privateKey.export({ type: 'pkcs8', format: 'pem' }) }, async (url, options) => {
    calls++;
    assert.equal(url.origin, 'https://api.appstoreconnect.apple.com');
    assert.equal(options.method, 'GET'); assert.equal(options.redirect, 'error');
    assert.match(options.headers.Authorization, /^Bearer /);
    return { ok: true, json: async () => ({ data: [] }) };
  });
  await api.get('/v1/apps');
  await assert.rejects(api.get('https://example.invalid/v1/apps'), /Only the Apple/);
  await assert.rejects(api.get('/v1/betaGroups'), /Only the Apple/);
  assert.equal(calls, 1);
});
test('HTTP authentication failures never echo server bodies or credentials', async () => {
  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const api = createClient({ keyId: 'secret-key-id', issuerId: 'secret-issuer', key: privateKey.export({ type: 'pkcs8', format: 'pem' }) }, async () => ({ ok: false, status: 401, json: async () => { throw Error('secret response'); } }));
  await assert.rejects(api.get('/v1/apps'), error => error instanceof CheckError && error.message === 'Apple status request returned HTTP 401' && !error.retryable);
});
test('readiness requires valid, unexpired, correct train/platform and beta state', () => {
  assert.equal(snapshot(document(), config).ready, true);
  assert.equal(snapshot(document('VALID', 'READY_FOR_BETA_TESTING'), config).ready, true);
  assert.equal(snapshot(document('PROCESSING'), config).ready, false);
  assert.equal(snapshot(document('VALID', 'PROCESSING'), config).ready, false);
  assert.equal(snapshot(document('VALID', 'IN_BETA_TESTING', { expired: true }), config).ready, false);
  assert.equal(snapshot(document('VALID', 'IN_BETA_TESTING', { expired: undefined }), config).ready, false);
  for (const key of ['version', 'platform']) {
    const wrong = document(); wrong.included[0].attributes[key] = 'wrong';
    assert.equal(snapshot(wrong, config).processingState, 'NOT_VISIBLE');
  }
  assert.equal(snapshot(document('VALID', 'IN_BETA_TESTING', { version: '21' }), config).processingState, 'NOT_VISIBLE');
  const foreign = document(); foreign.data[0].relationships.app.data.id = '99999';
  assert.equal(snapshot(foreign, config).processingState, 'NOT_VISIBLE');
  assert.equal(snapshot(document('INVALID'), config).blocker, 'INVALID');
});
test('missing relationships and ambiguous builds cannot report readiness', () => {
  const missing = document(); missing.included = [];
  assert.equal(snapshot(missing, config).ready, false);
  const ambiguous = document(); ambiguous.data.push({ ...ambiguous.data[0], id: 'second-build' });
  assert.throws(() => snapshot(ambiguous, config), /more than one/);
});
test('polling observes processing transition and returns only on actual readiness', async () => {
  let tick = 0, call = 0; const records = [];
  const api = { get: async route => route === '/v1/apps' ? { data: [{ id: '12345', attributes: { bundleId: config.bundleId } }] } : ++call === 1 ? document('PROCESSING', 'PROCESSING') : document() };
  const result = await monitor({ api, config, report: x => records.push(x), now: () => tick, sleep: async ms => { tick += ms; } });
  assert.equal(result.ready, true); assert.deepEqual(records.map(x => x.ready), [false, true]);
});
test('processing timeout and compliance blockers stay failures', async () => {
  for (const doc of [document('PROCESSING', 'PROCESSING'), document('VALID', 'MISSING_EXPORT_COMPLIANCE')]) {
    let tick = 0; const records = [];
    const api = { get: async route => route === '/v1/apps' ? { data: [{ id: '12345', attributes: { bundleId: config.bundleId } }] } : doc };
    await assert.rejects(monitor({ api, config, report: x => records.push(x), now: () => tick, sleep: async ms => { tick += ms; } }), CheckError);
    assert.ok(records.length); assert.ok(records.every(x => !x.ready));
  }
});
