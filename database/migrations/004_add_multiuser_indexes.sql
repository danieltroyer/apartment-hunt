-- +goose Up
-- +goose StatementBegin

-- User table indexes
CREATE INDEX idx_users_username ON users (username) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email ON users (email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_active ON users (is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_created_at ON users (created_at);
CREATE INDEX idx_users_last_login ON users (last_login_at);

-- User session indexes
CREATE INDEX idx_sessions_user_id ON user_sessions (user_id);
CREATE INDEX idx_sessions_token ON user_sessions (token);
CREATE INDEX idx_sessions_expires_at ON user_sessions (expires_at);
CREATE INDEX idx_sessions_active ON user_sessions (is_active, expires_at);

-- Update user_preferences indexes to include user_id
CREATE INDEX idx_user_preferences_user_id ON user_preferences (user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_preferences_user_default ON user_preferences (user_id, is_default) 
WHERE deleted_at IS NULL AND is_default = true;
CREATE INDEX idx_user_preferences_user_active ON user_preferences (user_id, is_active) 
WHERE deleted_at IS NULL;

-- Ensure unique default preference per user
CREATE UNIQUE INDEX idx_user_preferences_unique_default 
ON user_preferences (user_id) 
WHERE is_default = true AND deleted_at IS NULL;

-- User feedback indexes (ensure user_id filtering)
CREATE INDEX idx_user_feedback_user_id ON user_feedback (user_id) WHERE deleted_at IS NULL;

-- Ensure one feedback per user per listing
CREATE UNIQUE INDEX idx_user_feedback_unique 
ON user_feedback (user_id, apartment_id) 
WHERE deleted_at IS NULL;

-- User activity indexes
CREATE INDEX idx_user_activity_user_listing ON user_listing_activity (user_id, listing_id);
CREATE INDEX idx_user_activity_type ON user_listing_activity (activity_type, timestamp);
CREATE INDEX idx_user_activity_user_type ON user_listing_activity (user_id, activity_type);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Drop user activity indexes
DROP INDEX IF EXISTS idx_user_activity_user_listing;
DROP INDEX IF EXISTS idx_user_activity_type;
DROP INDEX IF EXISTS idx_user_activity_user_type;

-- Drop user feedback unique constraint
DROP INDEX IF EXISTS idx_user_feedback_unique;
DROP INDEX IF EXISTS idx_user_feedback_user_id;

-- Drop user preferences unique default constraint and user indexes
DROP INDEX IF EXISTS idx_user_preferences_unique_default;
DROP INDEX IF EXISTS idx_user_preferences_user_active;
DROP INDEX IF EXISTS idx_user_preferences_user_default;
DROP INDEX IF EXISTS idx_user_preferences_user_id;

-- Drop user session indexes
DROP INDEX IF EXISTS idx_sessions_active;
DROP INDEX IF EXISTS idx_sessions_expires_at;
DROP INDEX IF EXISTS idx_sessions_token;
DROP INDEX IF EXISTS idx_sessions_user_id;

-- Drop user indexes
DROP INDEX IF EXISTS idx_users_last_login;
DROP INDEX IF EXISTS idx_users_created_at;
DROP INDEX IF EXISTS idx_users_active;
DROP INDEX IF EXISTS idx_users_email;
DROP INDEX IF EXISTS idx_users_username;

-- +goose StatementEnd