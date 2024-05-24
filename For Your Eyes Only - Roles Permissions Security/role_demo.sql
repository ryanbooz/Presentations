/**********************************************
 * Roles in PostgreSQL - just the basics
 **********************************************/
/*
 * We'll start by creating a "GROUP", which is
 * just a role without the ability to login
 */
CREATE ROLE developer WITH nologin;

/*
 * Now grant necessary permissions
 */
SET ROLE NONE; -- the original SESSION user
GRANT SELECT, INSERT, UPDATE, DELETE 
	ON ALL TABLES IN SCHEMA public TO developer;

GRANT CREATE ON SCHEMA public TO developer;

/*
 * Now we can create a new user role with INHERIT
 */
CREATE ROLE dev1 WITH login PASSWORD 'abc123' INHERIT;
CREATE ROLE dev2 WITH login PASSWORD 'xyz123' INHERIT;

/*
 * grant permissions to that user through the group
 */
GRANT developer TO dev1;
GRANT developer TO dev2;

/*
 * After loging in as dev1, create a new table
 */
SET ROLE dev1;
CREATE TABLE new_table(col1 text);

/*
 * This could also be done with '\d' in psql
 */
SELECT schemaname, tablename, tableowner 
FROM pg_catalog.pg_tables 
WHERE tablename = 'new_table';

/*
 * Logging in as dev2
 */
SET ROLE dev2;
ALTER TABLE new_table ADD COLUMN col2 int;

/*
 * As a superuser or owner...
 */
SET ROLE NONE;
DROP TABLE new_table;

/*
 * If you don't want to modify table/object ownership always, you
 * can set the role that creates/owns the object before object
 * creation.
 */
SET ROLE developer;

/*
 * Now create the table as dev1
 */
CREATE TABLE new_table(col1 text);

SELECT schemaname, tablename, tableowner 
FROM pg_catalog.pg_tables 
WHERE tablename = 'new_table';

/*
 * Log in as dev2 and try the alter again
 */
SET ROLE dev2;
ALTER TABLE new_table ADD COLUMN col2 text;

SELECT * FROM new_table;



/*
 * Adding a SELECT only user to the cluster
 */
SET ROLE none; --back to superuser

-- create a user that can login
CREATE ROLE rptusr WITH login PASSWORD 'pgdaychicago';

-- test select
SET ROLE rptusr;
SELECT * FROM new_table;

-- as owner or superuser grant permissions
SET ROLE NONE;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rptusr;

-- test it out again
SET ROLE rptusr;
SELECT * FROM new_table;

-- now create a new table for reporting
SET ROLE developer;
CREATE TABLE rpt_table(c1 text);

-- can we select?
SET ROLE rptusr;
SELECT * FROM rpt_table;

-- Let's try again
SET ROLE developer;
DROP TABLE rpt_table;

/*
 * As the user that will create the objects, set the 
 * default privileges
 */
SET ROLE developer;

-- This could also be for PUBLIC, but probably not
ALTER DEFAULT PRIVILEGES
	GRANT SELECT ON TABLES TO rptusr;

CREATE TABLE rpt_table(c1 text);

-- what about now?
SET ROLE rptusr;
SELECT * FROM rpt_table;


/*
 * Reset!
 */
SET ROLE NONE;
DROP TABLE IF exists rpt_table;
DROP TABLE IF EXISTS new_table;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM rptusr;

SET ROLE developer;
ALTER DEFAULT PRIVILEGES REVOKE 
	SELECT ON TABLES FROM rptusr;

SET ROLE NONE;
DROP ROLE rptusr;
DROP ROLE dev1;
DROP ROLE dev2;
REVOKE ALL PRIVILEGES ON SCHEMA public FROM developer;
DROP ROLE developer;
