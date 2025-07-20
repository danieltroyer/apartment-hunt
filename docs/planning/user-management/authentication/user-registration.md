# UserStory: User Registration

## Summary
Implement new user account creation with email validation, password security requirements, and duplicate prevention to enable multi-user apartment hunting.

## Acceptance Criteria
- [ ] User can register with username, email, and password
- [ ] Username must be unique across all users
- [ ] Email must be unique and properly formatted
- [ ] Password must meet security requirements (8+ chars, mixed case, numbers)
- [ ] Password is hashed with bcrypt before storage
- [ ] Registration fails gracefully with clear error messages
- [ ] User account is created with default preferences
- [ ] Registration data is validated before database insertion
- [ ] Created user has inactive status until email verification (future)

## Context
This is the foundation for multi-user support. Users need secure accounts to maintain individual preferences, feedback, and activity history. Registration must prevent duplicate accounts and ensure data integrity.

## Unit Tests
- Valid registration with all required fields
- Duplicate username rejection
- Duplicate email rejection  
- Invalid email format rejection
- Weak password rejection
- Password hashing verification
- Database constraint violation handling
- Input sanitization and validation

## Dependencies
- Database migration 003_add_users_and_multiuser.sql must be applied
- bcrypt library for password hashing
- Email validation utility
- User model with validation tags
- Database connection and user repository

## Definition of Done
- [ ] Unit tests written and passing (90%+ coverage)
- [ ] Registration endpoint handles all error cases gracefully
- [ ] Password hashing implemented with bcrypt cost 12
- [ ] Input validation prevents SQL injection and XSS
- [ ] Database constraints properly enforced
- [ ] Error messages are user-friendly and secure (no data leakage)
- [ ] Integration test covers complete registration flow
- [ ] Code review completed
- [ ] Documentation updated

## Implementation Notes
```go
type RegisterRequest struct {
    Username string `json:"username" validate:"required,min=3,max=50,alphanum"`
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"password" validate:"required,min=8,password_strength"`
}

type User struct {
    ID           uuid.UUID `db:"id" json:"id"`
    Username     string    `db:"username" json:"username"`
    Email        string    `db:"email" json:"email"`
    PasswordHash string    `db:"password_hash" json:"-"`
    IsActive     bool      `db:"is_active" json:"is_active"`
    CreatedAt    time.Time `db:"created_at" json:"created_at"`
}
```

## Error Handling
- `400 Bad Request`: Invalid input data or validation errors
- `409 Conflict`: Username or email already exists
- `500 Internal Server Error`: Database or system errors
- All errors logged with context but user sees sanitized messages