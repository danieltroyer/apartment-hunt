# Data Models Index

> **Related Documents:**
> - [Caching Strategy](caching.md) - Deduplication implementation
> - [Architecture](architecture.md) - System structure and interfaces
> - [Technical Validation](../technical/technical.md) - Validation dependencies
> - [Multi-User Requirements](../tasking/t5.md) - Multi-user specifications
> - [Back to Documentation Index](../README.md)

## Overview

This index provides links to all data models in the apartment hunting system. Each data concept has its own dedicated file with comprehensive documentation including data structures, database schemas, business logic, and API operations.

## Data Model Documentation

### Core Entity Models

#### [Users](data-models/users.md)
User accounts, authentication, and profile management.
- User registration and authentication
- Session management and security
- Profile information and preferences
- Multi-user data isolation

#### [User Preferences](data-models/user-preferences.md)
Search criteria and filtering preferences for each user.
- Geographic preferences and constraints
- Price, size, and feature requirements
- Notification and alert settings
- Default and template preference management

#### [Listings](data-models/listings.md)
Apartment listing data from multiple sources.
- Property details and descriptions
- Multi-source information aggregation
- Availability tracking and verification
- Geographic and media data

#### [User Feedback](data-models/user-feedback.md)
User opinions, ratings, and interactions with listings.
- Rating system and detailed comments
- Application and contact tracking
- Follow-up reminders and notes
- Private notes and recommendations

#### [Cache Entries](data-models/cache-entries.md)
Deduplication metadata and cache management.
- Source tracking and validation
- Content and address hashing for deduplication
- Staleness and data quality metrics
- Performance optimization and cleanup

## Multi-User Architecture

### Data Separation Strategy

The system implements strict data separation between users while sharing common listing data:

```
┌─────────────────────────────────────────────────────────┐
│                    Shared Data                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Listings   │    │Cache Entries│    │   Sources   │  │
│  │             │    │             │    │             │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                  User-Specific Data                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │    Users    │    │ Preferences │    │  Feedback   │  │
│  │             │    │             │    │             │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Listings are Shared**: All users see the same listing data
2. **Opinions are Private**: User feedback and preferences are completely isolated
3. **Progress is Individual**: Each user's application history and notes are separate
4. **Preferences are Personal**: Multiple preference sets per user for different scenarios

## Entity Relationships

### Primary Relationships
```
User (1) ──── (M) UserPreferences
User (1) ──── (M) UserFeedback ──── (1) Listing
User (1) ──── (M) UserSessions

Listing (1) ──── (M) CacheEntries
Listing (1) ──── (M) UserFeedback
```

### Cross-References and Lookups
- **Content Deduplication**: `content_hash` links listings across sources
- **Address Deduplication**: `address_hash` identifies same properties
- **URL Tracking**: `url_hash` prevents duplicate scraping
- **User Isolation**: All user operations filtered by `user_id`

## Database Schema Overview

### Core Tables
- `users` - User accounts and authentication
- `user_sessions` - Login session management
- `user_preferences` - Search criteria per user
- `user_feedback` - User opinions and ratings
- `listings` - Apartment data (shared across users)
- `cache_entries` - Deduplication and source tracking

### Supporting Tables
- `user_listing_activity` - View/save/hide tracking
- `feedback_attributes` - Structured attribute ratings
- `preference_templates` - Common preference patterns

## Common Operations

### User-Scoped Operations
All user-specific operations include user authentication and data filtering:

```sql
-- Example: Get user's feedback
SELECT * FROM user_feedback 
WHERE user_id = $1 AND deleted_at IS NULL;

-- Example: Get user's preferred listings
SELECT l.* FROM listings l
JOIN user_preferences up ON (l.city = ANY(up.geography->'cities'))
WHERE up.user_id = $1 AND up.is_active = true;
```

### Cross-User Operations
Only aggregate data is shared across users (no individual user data):

```sql
-- Example: Listing popularity (aggregate only)
SELECT listing_id, COUNT(*) as feedback_count
FROM user_feedback 
WHERE rating IN ('like', 'love')
GROUP BY listing_id;
```

## Data Privacy and Security

### Privacy Protections
- User feedback is never shared between users
- Preference data is completely isolated
- Search history is user-specific
- Application tracking is private

### Security Measures
- All user operations require valid authentication
- Database queries are parameterized to prevent injection
- User data access is logged for audit trails
- Soft deletes preserve data integrity

## Development Guidelines

### When Adding New Data Models
1. Create dedicated file in `data-models/` directory
2. Include comprehensive documentation sections:
   - Data structures with validation
   - Database schema with indexes
   - Business logic and operations
   - Multi-user considerations
   - API operations
3. Update this index file with links and descriptions
4. Consider user isolation requirements
5. Add appropriate cross-references

### Best Practices
- Always include user_id in user-specific tables
- Use UUIDs for all primary keys
- Include created_at/updated_at timestamps
- Implement soft deletes for audit trails
- Add appropriate database indexes
- Document all validation rules
- Consider data quality and integrity

## Migration and Evolution

As new data concepts are added to the system, follow the established pattern:
1. Create new dedicated model file
2. Design with multi-user isolation in mind
3. Consider relationships to existing models
4. Update this index with appropriate links
5. Document migration strategy if needed

This modular approach ensures maintainable, scalable data architecture that supports the multi-user requirements while maintaining clear separation of concerns.