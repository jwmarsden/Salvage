-- Runs once, when the database volume is first created. The schema uses
-- geometry columns, and the migrations don't create the extension.
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;
