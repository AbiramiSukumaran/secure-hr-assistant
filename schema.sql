-- 0. Clean Slate (Drop existing to avoid conflicts)
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;

-- 1. Create User Roles (The Identity Provider)
CREATE TABLE user_roles (
    username TEXT PRIMARY KEY,
    role TEXT -- 'employee', 'manager', 'admin'
);

INSERT INTO user_roles (username, role) VALUES
('Alice', 'employee'),
('Bob', 'manager'),
('Charlie', 'employee');

-- 2. Create the Data Table
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name TEXT,
    salary INTEGER,
    performance_review TEXT,
    embedding vector(768)
);

INSERT INTO employees (name, salary, performance_review) VALUES
('Alice', 80000, 'Alice meets expectations but needs to improve punctuality.'),
('Bob', 120000, 'Bob is a strong leader. Team morale is high.'),
('Charlie', 85000, 'Charlie exceeds expectations. Ready for promotion.');

-- 3. Security Setup
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees FORCE ROW LEVEL SECURITY; -- Enforce even for owner

-- 4. Create App User
DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'app_user') THEN
      CREATE ROLE app_user LOGIN PASSWORD 'password';
   END IF;
END
$do$;

GRANT SELECT ON employees TO app_user;
GRANT SELECT ON user_roles TO app_user; -- App needs access to check roles

-- 5. Define Policies

-- Policy 1: Self-View
-- Users can see rows where their name matches the session variable 'app.active_user'
CREATE POLICY "view_own_data" ON employees
FOR SELECT
USING (name = current_setting('app.active_user', true));

-- Policy 2: Manager-View
-- Managers can see ALL rows. We check the 'user_roles' table for the current user's role.
CREATE POLICY "manager_view_all" ON employees
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE username = current_setting('app.active_user', true)
        AND role = 'manager'
    )
);
