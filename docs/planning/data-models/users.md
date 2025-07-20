# User Data Model

> **Related Documents:**
> - [Data Models Index](../data-models.md) - Central data model index
> - [User Preferences](user-preferences.md) - User search criteria  
> - [User Feedback](user-feedback.md) - User opinions and ratings
> - [Multi-User Requirements](../../tasking/t5.md) - Multi-user specifications
> - [Back to Documentation Index](../../README.md)

## Overview

The User model manages individual user accounts, authentication, and profile information. Each user can have multiple preferences and provide feedback on listings independently.

## Data Structure

### User Model
```go
type User struct {
    ID          string    `json:"id" db:"id" validate:"required"`
    Username    string    `json:"username" db:"username" validate:"required,min=3,max=50"`
    Email       string    `json:"email" db:"email" validate:"required,email"`
    DisplayName string    `json:"display_name" db:"display_name" validate:"required,min=1,max=100"`
    
    // Authentication
    PasswordHash string    `json:"-" db:"password_hash" validate:"required"`
    IsActive     bool      `json:"is_active" db:"is_active"`
    EmailVerified bool     `json:"email_verified" db:"email_verified"`
    
    // Profile information
    FirstName   string    `json:"first_name,omitempty" db:"first_name" validate:"omitempty,max=50"`
    LastName    string    `json:"last_name,omitempty" db:"last_name" validate:"omitempty,max=50"`
    TimeZone    string    `json:"time_zone,omitempty" db:"time_zone" validate:"omitempty"`
    
    // Timestamps
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
    UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
    LastLoginAt *time.Time `json:"last_login_at,omitempty" db:"last_login_at"`
    
    // Soft delete
    DeletedAt   *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
}
```

### User Session
```go
type UserSession struct {
    ID        string    `json:"id" db:"id" validate:"required"`
    UserID    string    `json:"user_id" db:"user_id" validate:"required"`
    Token     string    `json:"token" db:"token" validate:"required"`
    ExpiresAt time.Time `json:"expires_at" db:"expires_at" validate:"required"`
    CreatedAt time.Time `json:"created_at" db:"created_at"`
    IPAddress string    `json:"ip_address,omitempty" db:"ip_address"`
    UserAgent string    `json:"user_agent,omitempty" db:"user_agent"`
    IsActive  bool      `json:"is_active" db:"is_active"`
}
```

## Database Schema

### users table
```sql
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

-- Indexes
CREATE INDEX idx_users_username ON users (username) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email ON users (email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_active ON users (is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_created_at ON users (created_at);
CREATE INDEX idx_users_last_login ON users (last_login_at);
```

### user_sessions table
```sql
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

-- Indexes
CREATE INDEX idx_sessions_user_id ON user_sessions (user_id);
CREATE INDEX idx_sessions_token ON user_sessions (token);
CREATE INDEX idx_sessions_expires_at ON user_sessions (expires_at);
CREATE INDEX idx_sessions_active ON user_sessions (is_active, expires_at);
```

## Validation Rules

### Username Requirements
- Minimum 3 characters, maximum 50 characters
- Alphanumeric characters, underscores, and hyphens only
- Must be unique across all users
- Case-insensitive uniqueness

### Email Requirements
- Valid email format (RFC 5322 compliant)
- Must be unique across all users
- Case-insensitive storage and comparison

### Password Requirements
- Minimum 8 characters
- Must contain at least one uppercase letter
- Must contain at least one lowercase letter
- Must contain at least one number
- Must contain at least one special character

## Business Logic

### User Creation
```go
func (u *User) Create() error {
    // Validate input
    if err := u.Validate(); err != nil {
        return err
    }
    
    // Check for existing username/email
    if exists, err := u.UsernameExists(); err != nil || exists {
        return ErrUsernameExists
    }
    
    if exists, err := u.EmailExists(); err != nil || exists {
        return ErrEmailExists
    }
    
    // Hash password
    hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    if err != nil {
        return err
    }
    u.PasswordHash = string(hashedPassword)
    
    // Set default values
    u.ID = uuid.New().String()
    u.IsActive = true
    u.EmailVerified = false
    u.CreatedAt = time.Now()
    u.UpdatedAt = time.Now()
    
    return u.Save()
}
```

### Authentication
```go
func (u *User) Authenticate(password string) error {
    if !u.IsActive {
        return ErrUserInactive
    }
    
    if err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password)); err != nil {
        return ErrInvalidCredentials
    }
    
    // Update last login
    now := time.Now()
    u.LastLoginAt = &now
    u.UpdatedAt = now
    
    return u.Save()
}
```

### Session Management
```go
func (u *User) CreateSession(ipAddress, userAgent string) (*UserSession, error) {
    session := &UserSession{
        ID:        uuid.New().String(),
        UserID:    u.ID,
        Token:     generateSecureToken(),
        ExpiresAt: time.Now().Add(24 * time.Hour), // 24 hour sessions
        CreatedAt: time.Now(),
        IPAddress: ipAddress,
        UserAgent: userAgent,
        IsActive:  true,
    }
    
    return session, session.Save()
}
```

## Relationships

### One-to-Many Relationships
- **User → UserPreferences**: One user can have multiple preference sets
- **User → UserFeedback**: One user can provide feedback on multiple listings
- **User → UserSessions**: One user can have multiple active sessions

### Data Isolation
- Each user's preferences are completely isolated
- User feedback is linked to both user and listing
- Users can only access their own data (enforced at service level)

## Multi-User Considerations

### Data Separation
```go
// All user-specific queries include user_id filter
func (s *UserService) GetUserPreferences(userID string) ([]*UserPreferences, error) {
    return s.repo.FindPreferencesByUserID(userID)
}

func (s *UserService) GetUserFeedback(userID string) ([]*UserFeedback, error) {
    return s.repo.FindFeedbackByUserID(userID)
}
```

### Privacy and Security
- Passwords are never stored in plain text (bcrypt hashing)
- Sessions expire automatically after 24 hours
- Soft delete preserves data integrity while hiding users
- All user operations require valid authentication

### Scalability Features
- User data is partitioned by user_id
- Efficient indexing for common lookup patterns
- Session cleanup removes expired sessions automatically
- Support for horizontal scaling with proper partitioning

## API Operations

### Core Operations
- `CreateUser(user)` - Register new user account
- `AuthenticateUser(username, password)` - Login authentication
- `GetUser(id)` - Retrieve user profile
- `UpdateUser(id, updates)` - Modify user information
- `DeactivateUser(id)` - Soft delete user account
- `CreateSession(userID, ipAddress, userAgent)` - Create login session
- `ValidateSession(token)` - Verify session validity
- `RevokeSession(token)` - Logout/invalidate session

### Query Operations
- `FindUserByUsername(username)` - Lookup by username
- `FindUserByEmail(email)` - Lookup by email address
- `GetActiveUsers()` - List all active users
- `GetUserSessions(userID)` - List user's active sessions