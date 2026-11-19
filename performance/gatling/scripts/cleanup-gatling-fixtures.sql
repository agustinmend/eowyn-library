-- Only removes fixtures created by full-api-lifecycle.feature.
-- Run against the disposable/local Eowyn test database after a run.
BEGIN;

CREATE TEMP TABLE gatling_fixture_users ON COMMIT DROP AS
SELECT id
FROM users
WHERE email LIKE 'gatling-e2e-%@example.com';

CREATE TEMP TABLE gatling_fixture_books ON COMMIT DROP AS
SELECT id
FROM books
WHERE user_id IN (SELECT id FROM gatling_fixture_users);

-- Loans are removed first to satisfy foreign keys. This scenario uses only books
-- owned by its generated fixture users.
DELETE FROM loans
WHERE user_id IN (SELECT id FROM gatling_fixture_users)
   OR book_id IN (SELECT id FROM gatling_fixture_books);

DELETE FROM books
WHERE id IN (SELECT id FROM gatling_fixture_books);

DELETE FROM categories
WHERE user_id IN (SELECT id FROM gatling_fixture_users)
  AND name LIKE 'Gatling %';

DELETE FROM users
WHERE id IN (SELECT id FROM gatling_fixture_users);

COMMIT;
