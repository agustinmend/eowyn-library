function fn() {
  var System = Java.type('java.lang.System');
  var baseUrl = karate.properties['baseUrl'] || System.getenv('BASE_URL') || 'http://localhost:3000';
  var email = karate.properties['test.email'] || System.getenv('TEST_EMAIL');
  var password = karate.properties['test.password'] || System.getenv('TEST_PASSWORD');

  if (!email || !password) {
    karate.fail('Define TEST_EMAIL y TEST_PASSWORD (o -Dtest.email / -Dtest.password) para el usuario local de pruebas.');
  }

  return {
    baseUrl: baseUrl.replace(/\/$/, ''),
    userEmail: email,
    userPassword: password
  };
}
