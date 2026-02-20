-- Migration 003: Add missing performance indexes
-- Date: 2026-02-20
-- Issue: Sequential scans causing slow queries (14+ min DELETEs)
--
-- Evidence:
--   - address table: 10.9M seq scans, 5.1T tuples read, 0 index scans
--   - patron.institution_id: not indexed (DELETE took 14+ min)
--   - file_tracker: 4.9M seq scans

-- Critical: patron.institution_id (fixes slow DELETE and all institution queries)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_patron_institution_id
ON patron_import.patron(institution_id);

-- Critical: address.patron_id (fixes trigger performance)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_address_patron_id
ON patron_import.address(patron_id);

-- Important: file_tracker indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_file_tracker_institution_id
ON patron_import.file_tracker(institution_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_file_tracker_job_id
ON patron_import.file_tracker(job_id);
