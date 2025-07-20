-- +goose Up
-- +goose StatementBegin

-- Primary search indexes for apartments
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_city_state ON apartments (city, state);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_price ON apartments (price);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_bedrooms ON apartments (bedrooms);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_bathrooms ON apartments (bathrooms);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_square_feet ON apartments (square_feet);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_availability ON apartments (availability);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_date_posted ON apartments (date_posted);

-- Deduplication indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_content_hash ON apartments (content_hash);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_address_hash ON apartments (address_hash);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_url ON apartments (url);

-- Source management indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_source ON apartments (source);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_source_id ON apartments (source, source_id);

-- Compound indexes for search optimization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_price_bed_bath ON apartments (price, bedrooms, bathrooms);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_search ON apartments (city, state, price, bedrooms, bathrooms, availability);

-- Timestamp indexes for data management
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_created_at ON apartments (created_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_updated_at ON apartments (updated_at);

-- Preferences indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_preferences_created_at ON user_preferences (created_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_preferences_sources ON user_preferences USING GIN (sources);

-- Feedback indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feedback_apartment_id ON user_feedback (apartment_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feedback_rating ON user_feedback (rating);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feedback_timestamp ON user_feedback (timestamp);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feedback_user_id ON user_feedback (user_id);

-- Cache indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cache_listing_id ON cache_entries (listing_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cache_url ON cache_entries (url);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cache_content_hash ON cache_entries (content_hash);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cache_source ON cache_entries (source);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Drop all indexes created in this migration
DROP INDEX IF EXISTS idx_apartments_city_state;
DROP INDEX IF EXISTS idx_apartments_price;
DROP INDEX IF EXISTS idx_apartments_bedrooms;
DROP INDEX IF EXISTS idx_apartments_bathrooms;
DROP INDEX IF EXISTS idx_apartments_square_feet;
DROP INDEX IF EXISTS idx_apartments_availability;
DROP INDEX IF EXISTS idx_apartments_date_posted;
DROP INDEX IF EXISTS idx_apartments_content_hash;
DROP INDEX IF EXISTS idx_apartments_address_hash;
DROP INDEX IF EXISTS idx_apartments_url;
DROP INDEX IF EXISTS idx_apartments_source;
DROP INDEX IF EXISTS idx_apartments_source_id;
DROP INDEX IF EXISTS idx_apartments_price_bed_bath;
DROP INDEX IF EXISTS idx_apartments_search;
DROP INDEX IF EXISTS idx_apartments_created_at;
DROP INDEX IF EXISTS idx_apartments_updated_at;
DROP INDEX IF EXISTS idx_preferences_created_at;
DROP INDEX IF EXISTS idx_preferences_sources;
DROP INDEX IF EXISTS idx_feedback_apartment_id;
DROP INDEX IF EXISTS idx_feedback_rating;
DROP INDEX IF EXISTS idx_feedback_timestamp;
DROP INDEX IF EXISTS idx_feedback_user_id;
DROP INDEX IF EXISTS idx_cache_listing_id;
DROP INDEX IF EXISTS idx_cache_url;
DROP INDEX IF EXISTS idx_cache_content_hash;
DROP INDEX IF EXISTS idx_cache_source;

-- +goose StatementEnd