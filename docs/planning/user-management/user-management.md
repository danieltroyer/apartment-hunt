# Epic: User Management

## Purpose
Complete user authentication, session management, and multi-user support system that enables multiple users to have individual preferences, feedback, and activity tracking while sharing a common apartment listing database.

## Business Value
- **Multi-tenant Architecture**: Support multiple users with isolated preferences and feedback
- **Secure Authentication**: Protect user data with bcrypt password hashing and session management
- **Personalized Experience**: Each user maintains their own search preferences and listing feedback
- **Activity Tracking**: Monitor user interactions for improved recommendations and analytics

## Features

### [Authentication](authentication/)
User registration, login, logout, and session management with secure password handling and token-based sessions.

### [User Preferences](user-preferences/) 
Multiple preference sets per user with geographic filters, price ranges, and amenity requirements for flexible search scenarios.

### [User Activity](user-activity/)
Comprehensive activity tracking including listing views, applications, and feedback for analytics and recommendation improvement.

## Success Criteria
- [ ] Users can register new accounts with email verification
- [ ] Secure login/logout with session management
- [ ] Multiple preference sets per user with easy switching
- [ ] Complete activity history tracking per user
- [ ] Data isolation between users (no cross-user data leakage)
- [ ] Password security with bcrypt hashing
- [ ] Session expiration and cleanup

## Dependencies
- PostgreSQL database with CNPG support
- Database migration system (Goose)
- gRPC communication between services
- bcrypt library for password hashing

## Database Schema Impact
- `users` table for account management
- `user_sessions` table for session tracking  
- `user_preferences` table linked to users
- `user_feedback` table linked to users and listings
- `user_listing_activity` table for interaction tracking

## Security Considerations
- Password hashing with bcrypt (cost factor 12)
- Session token generation and validation
- User data isolation at database level
- Input validation and sanitization
- Rate limiting for authentication endpoints