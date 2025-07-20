-- +goose Up
-- +goose StatementBegin

-- Create custom types
CREATE TYPE availability_status AS ENUM (
    'available',
    'unavailable', 
    'unknown',
    'check_failed'
);

CREATE TYPE data_source_type AS ENUM (
    'api',
    'scraping',
    'hybrid'
);

CREATE TYPE feedback_rating AS ENUM (
    'dislike',
    'neutral',
    'like',
    'love'
);

-- Main apartments table
CREATE TABLE apartments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(50) NOT NULL,
    source_id VARCHAR(255) NOT NULL,
    url TEXT NOT NULL,
    alternate_urls JSONB,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    price INTEGER NOT NULL,
    bedrooms INTEGER NOT NULL,
    bathrooms DECIMAL(3,1) NOT NULL,
    square_feet INTEGER,
    description TEXT NOT NULL,
    images JSONB,
    date_posted TIMESTAMP WITH TIME ZONE NOT NULL,
    date_found TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    content_hash VARCHAR(64) NOT NULL,
    address_hash VARCHAR(64) NOT NULL,
    availability availability_status NOT NULL DEFAULT 'unknown',
    availability_checks JSONB,
    last_available_check TIMESTAMP WITH TIME ZONE,
    unavailable_since TIMESTAMP WITH TIME ZONE,
    sources JSONB,
    primary_source VARCHAR(50),
    data_source data_source_type NOT NULL DEFAULT 'scraping',
    price_per_sq_ft DECIMAL(8,2),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- User preferences table
CREATE TABLE user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    geography JSONB NOT NULL,
    price_range JSONB NOT NULL,
    bedrooms JSONB NOT NULL,
    bathrooms JSONB,
    min_sq_ft INTEGER,
    max_sq_ft INTEGER,
    keywords TEXT[],
    exclusions TEXT[],
    sources TEXT[] NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- User feedback table
CREATE TABLE user_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    rating feedback_rating NOT NULL,
    comments TEXT,
    attributes JSONB,
    user_id UUID,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Cache entries table
CREATE TABLE cache_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    file_path TEXT,
    source VARCHAR(50) NOT NULL,
    url TEXT NOT NULL,
    content_hash VARCHAR(64) NOT NULL,
    last_seen TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    date_added TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP TABLE IF EXISTS cache_entries;
DROP TABLE IF EXISTS user_feedback;
DROP TABLE IF EXISTS user_preferences;
DROP TABLE IF EXISTS apartments;

DROP TYPE IF EXISTS feedback_rating;
DROP TYPE IF EXISTS data_source_type;
DROP TYPE IF EXISTS availability_status;

-- +goose StatementEnd