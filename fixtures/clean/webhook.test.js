// Test files are skipped by the pattern check: fake secrets are normal here.
const SECRET = 'whsec_test_secret';

test('rejects a bad signature', () => {
  expect(verify({ idToken: 'admin-token' }, 'bad-signature', SECRET)).toBe(false);
});
