#!/bin/bash
su postgres
pg_dump --dbname=postgres --schema=patron_import --file patron-import.sql