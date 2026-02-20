-- Migration 004: ETL Performance Optimizations (Expanded)
-- Date: 2026-02-20
-- Issue: Slow ETL due to missing indexes, unconditional address trigger,
--        and missing table statistics
--
-- Evidence:
--   - stage_patron: No indexes on key columns used in ETL joins
--   - address_trigger: Fires on every UPDATE even when addresses unchanged
--   - import_response/import_failed_users: No indexes for reporting queries
--   - ANALYZE: Never run, PostgreSQL lacks statistics for query planning

-- =============================================================================
-- 1. STAGE_PATRON INDEXES (Single-Column)
-- =============================================================================
-- Basic indexes for ETL lookups

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stage_patron_institution_id
    ON patron_import.stage_patron(institution_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stage_patron_esid
    ON patron_import.stage_patron(esid);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stage_patron_fingerprint
    ON patron_import.stage_patron(fingerprint);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stage_patron_patron_type
    ON patron_import.stage_patron(patron_type);

-- =============================================================================
-- 2. STAGE_PATRON COMPOSITE INDEXES (CRITICAL for ETL)
-- =============================================================================
-- Composite indexes outperform separate single-column indexes for multi-column filters

-- Fingerprint + institution for DELETE joins in stage-to-patron.sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stage_patron_fingerprint_institution
    ON patron_import.stage_patron(fingerprint, institution_id);

-- Unique_id + institution for deduplication logic
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stage_patron_unique_id_institution
    ON patron_import.stage_patron(unique_id, institution_id);

-- Patron_type + institution for ptype_mapping JOINs
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stage_patron_patron_type_institution
    ON patron_import.stage_patron(patron_type, institution_id);

-- =============================================================================
-- 3. PATRON TABLE INDEXES
-- =============================================================================

-- Job tracking for UPDATE/JOIN in DAO.pm and FolioService.pm
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_patron_job_id
    ON patron_import.patron(job_id);

-- Partial index for import batch queries (ready=true records only)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_patron_ready_institution
    ON patron_import.patron(institution_id)
    WHERE ready = true;

-- =============================================================================
-- 4. IMPORT RESPONSE/FAILED USERS INDEXES
-- =============================================================================

-- Composite for failed patron report queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_import_response_institution_job
    ON patron_import.import_response(institution_id, job_id);

-- FK index for JOIN in CSV reports
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_import_failed_users_response_id
    ON patron_import.import_failed_users(import_response_id);

-- For JOIN back to patron table
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_import_failed_users_esid
    ON patron_import.import_failed_users(externalsystemid);

-- =============================================================================
-- 5. FILE TRACKER COMPOSITE INDEX
-- =============================================================================

-- Recovery operations with ORDER BY lastModified
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_file_tracker_institution_lastmodified
    ON patron_import.file_tracker(institution_id, lastmodified DESC);

-- =============================================================================
-- 6. LOW-PRIORITY FK INDEXES
-- =============================================================================

-- FK without index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_login_institution_id
    ON patron_import.login(institution_id);

-- FK without index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_institution_folder_map_institution
    ON patron_import.institution_folder_map(institution_id);

-- =============================================================================
-- 7. OPTIMIZED ADDRESS TRIGGER
-- =============================================================================
-- Split into INSERT and UPDATE triggers. UPDATE trigger only fires when
-- address columns actually change, avoiding unnecessary DELETE + INSERT cycles.

-- Drop existing trigger (fires unconditionally on INSERT OR UPDATE)
DROP TRIGGER IF EXISTS address_trigger ON patron_import.patron;

-- INSERT trigger: Always fire on new patrons (no WHEN clause needed)
CREATE TRIGGER address_trigger_insert
    AFTER INSERT ON patron_import.patron
    FOR EACH ROW
    EXECUTE FUNCTION patron_import.address_trigger_function();

-- UPDATE trigger: Only fire when address columns change
CREATE TRIGGER address_trigger_update
    AFTER UPDATE ON patron_import.patron
    FOR EACH ROW
    WHEN (OLD.address1_one_liner IS DISTINCT FROM NEW.address1_one_liner
       OR OLD.address2_one_liner IS DISTINCT FROM NEW.address2_one_liner)
    EXECUTE FUNCTION patron_import.address_trigger_function();

-- =============================================================================
-- 8. TABLE STATISTICS
-- =============================================================================
-- Update PostgreSQL statistics for better query planning

ANALYZE patron_import.patron;
ANALYZE patron_import.address;
ANALYZE patron_import.stage_patron;
ANALYZE patron_import.ptype_mapping;
ANALYZE patron_import.import_response;
ANALYZE patron_import.import_failed_users;
ANALYZE patron_import.file_tracker;
