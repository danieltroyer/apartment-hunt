-- +goose Up
-- +goose StatementBegin

-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    email_verified BOOLEAN NOT NULL DEFAULT false,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    time_zone VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT users_username_check CHECK (char_length(username) >= 3),
    CONSTRAINT users_email_check CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Create user sessions table
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- Update user_preferences to link to users table
ALTER TABLE user_preferences 
ADD COLUMN user_id UUID REFERENCES users(id) ON DELETE CASCADE;

-- Update user_feedback to ensure proper user linkage
-- (user_feedback already had user_id but ensure proper constraint)
ALTER TABLE user_feedback 
ADD CONSTRAINT user_feedback_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Create user listing activity table
CREATE TABLE user_listing_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    activity_type VARCHAR(20) NOT NULL, -- 'viewed', 'saved', 'hidden', 'contacted'
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    metadata JSONB,
    
    UNIQUE(user_id, listing_id, activity_type)
);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Remove user listing activity table
DROP TABLE IF EXISTS user_listing_activity;

-- Remove foreign key constraint from user_feedback
ALTER TABLE user_feedback 
DROP CONSTRAINT IF EXISTS user_feedback_user_id_fkey;

-- Remove user_id column from user_preferences
ALTER TABLE user_preferences 
DROP COLUMN IF EXISTS user_id;

-- Drop user sessions table
DROP TABLE IF EXISTS user_sessions;

-- Drop users table
DROP TABLE IF EXISTS users;

-- +goose StatementEnd