# Database Migration Strategy

> **Related Documents:**
> - [Data Models](../planning/data-models.md) - Database schema definitions
> - [Technical Requirements](../tasking/t4.md) - Database persistence requirements
> - [Docker Orchestration](../planning/docker-orchestration.md) - PostgreSQL container setup
> - [Back to Documentation Index](../README.md)

## Migration Philosophy

Database migrations follow a **backward-compatible** approach ensuring zero-downtime deployments and safe rollback capabilities as specified in the requirements.

### Key Principles

1. **Backward Compatibility**: All migrations must be compatible with the previous application version
2. **Version Control**: All migrations are version-controlled and tracked in Git
3. **Rollback Support**: Every migration must include a rollback strategy
4. **Incremental Changes**: Prefer small, incremental changes over large schema overhauls
5. **Data Preservation**: Never destructive - always preserve existing data

## Migration Tools

### Primary Tool: Goose
We use [Goose](https://github.com/pressly/goose) for database migrations:

```bash
# Install goose
go install github.com/pressly/goose/v3/cmd/goose@latest

# Run migrations
goose -dir database/migrations postgres "user=apartment_user dbname=apartment_hunt sslmode=disable" up

# Rollback last migration
goose -dir database/migrations postgres "user=apartment_user dbname=apartment_hunt sslmode=disable" down

# Check migration status
goose -dir database/migrations postgres "user=apartment_user dbname=apartment_hunt sslmode=disable" status
```

## Migration Structure

### Directory Layout
```
database/
├── migrations/
│   ├── 001_initial_schema.sql
│   ├── 002_add_availability_tracking.sql
│   ├── 003_add_source_metadata.sql
│   └── ...
├── schema/
│   ├── apartments.sql
│   ├── user_preferences.sql
│   ├── user_feedback.sql
│   └── indexes.sql
└── cnpg/
    ├── cluster.yaml
    └── backup-config.yaml
```

### Migration Naming Convention
```
{version}_{description}.sql

Examples:
001_initial_schema.sql
002_add_availability_tracking.sql
003_add_apartment_source_metadata.sql
004_create_feedback_indexes.sql
```

## Migration File Format

### Template Structure
```sql
-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS example_table (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS example_table;
-- +goose StatementEnd
```

### Migration Categories

#### 1. Schema Changes
```sql
-- +goose Up
-- Add new column (backward compatible)
ALTER TABLE apartments ADD COLUMN IF NOT EXISTS price_per_sq_ft DECIMAL(8,2);

-- +goose Down
ALTER TABLE apartments DROP COLUMN IF EXISTS price_per_sq_ft;
```

#### 2. Index Management
```sql
-- +goose Up
-- Create index for performance optimization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_apartments_city_price 
ON apartments (city, price) WHERE availability = 'available';

-- +goose Down
DROP INDEX IF EXISTS idx_apartments_city_price;
```

#### 3. Data Transformations
```sql
-- +goose Up
-- +goose StatementBegin
-- Update existing data (ensure idempotency)
UPDATE apartments 
SET price_per_sq_ft = CASE 
    WHEN square_feet > 0 THEN price::DECIMAL / square_feet 
    ELSE NULL 
END
WHERE price_per_sq_ft IS NULL AND square_feet > 0;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
UPDATE apartments SET price_per_sq_ft = NULL;
-- +goose StatementEnd
```

## Backward Compatibility Strategies

### 1. Additive Changes (Safe)
- Adding new tables
- Adding new columns (with defaults)
- Adding new indexes
- Adding new enums values
- Creating new functions/procedures

### 2. Column Modifications (Requires Strategy)

#### Renaming Columns
```sql
-- Step 1: Add new column
ALTER TABLE apartments ADD COLUMN new_column_name TEXT;

-- Step 2: Populate new column
UPDATE apartments SET new_column_name = old_column_name;

-- Step 3: (In next deployment) Drop old column
-- ALTER TABLE apartments DROP COLUMN old_column_name;
```

#### Changing Data Types
```sql
-- Step 1: Add new column with new type
ALTER TABLE apartments ADD COLUMN price_new INTEGER;

-- Step 2: Populate with converted data
UPDATE apartments SET price_new = price::INTEGER WHERE price_new IS NULL;

-- Step 3: (In next deployment) Rename columns
-- ALTER TABLE apartments RENAME COLUMN price TO price_old;
-- ALTER TABLE apartments RENAME COLUMN price_new TO price;
```

### 3. Destructive Changes (Multi-Step Process)

#### Dropping Tables
```sql
-- Migration 1: Rename table
ALTER TABLE old_table RENAME TO old_table_deprecated;

-- Migration 2: (After deployment verification) Drop table
-- DROP TABLE old_table_deprecated;
```

## Environment-Specific Migrations

### Development Environment
```bash
# Reset database (development only)
goose -dir database/migrations postgres "user=apartment_user dbname=apartment_hunt sslmode=disable" reset

# Fresh database setup
goose -dir database/migrations postgres "user=apartment_user dbname=apartment_hunt sslmode=disable" up
```

### Production Environment
```bash
# Always backup before migrations
pg_dump apartment_hunt > backup_$(date +%Y%m%d_%H%M%S).sql

# Run migrations with careful monitoring
goose -dir database/migrations postgres "user=apartment_user dbname=apartment_hunt sslmode=disable" up

# Verify migration success
goose -dir database/migrations postgres "user=apartment_user dbname=apartment_hunt sslmode=disable" status
```

## Testing Migrations

### Unit Tests for Migrations
```go
func TestMigration001_InitialSchema(t *testing.T) {
    db, err := sql.Open("postgres", testDSN)
    require.NoError(t, err)
    defer db.Close()
    
    // Run migration
    err = goose.UpTo(db, "migrations", 1)
    require.NoError(t, err)
    
    // Verify tables exist
    var exists bool
    err = db.QueryRow("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'apartments')").Scan(&exists)
    require.NoError(t, err)
    require.True(t, exists)
    
    // Test rollback
    err = goose.DownTo(db, "migrations", 0)
    require.NoError(t, err)
}
```

### Integration Tests
```go
func TestMigrationSequence(t *testing.T) {
    // Test full migration sequence
    // Verify data integrity
    // Test rollback capabilities
}
```

## Migration Deployment Process

### Pre-Deployment Checklist
1. **Review Migration**: Ensure backward compatibility
2. **Test Locally**: Run migration on development database
3. **Performance Check**: Estimate migration time for large tables
4. **Rollback Plan**: Verify rollback commands work
5. **Backup Strategy**: Ensure automated backups are current

### Deployment Steps
1. **Backup Database**: Create point-in-time backup
2. **Deploy Application**: Deploy new version alongside old version
3. **Run Migrations**: Execute database migrations
4. **Verify Health**: Check application health and data integrity
5. **Complete Deployment**: Switch traffic to new version
6. **Monitor**: Watch for errors and performance issues

### Emergency Rollback
```bash
# Rollback application
kubectl rollout undo deployment/apartment-hunt

# Rollback database (if necessary)
goose -dir database/migrations postgres "connection_string" down

# Restore from backup (last resort)
pg_restore backup_file.sql
```

## Monitoring and Maintenance

### Migration Monitoring
- Track migration execution time
- Monitor database performance during migrations
- Alert on migration failures
- Log all migration activities

### Maintenance Tasks
```sql
-- Regular maintenance queries
SELECT schemaname, tablename, attname, n_distinct, correlation 
FROM pg_stats 
WHERE tablename IN ('apartments', 'user_feedback');

-- Index usage monitoring
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

## Best Practices

### DO
- ✅ Always include rollback commands
- ✅ Test migrations on staging environment
- ✅ Use transactions for atomic operations
- ✅ Make migrations idempotent
- ✅ Document complex migrations thoroughly
- ✅ Use `IF NOT EXISTS` and `IF EXISTS` clauses

### DON'T
- ❌ Make destructive changes without multi-step process
- ❌ Run untested migrations in production
- ❌ Skip rollback testing
- ❌ Ignore migration performance impact
- ❌ Modify existing migration files
- ❌ Deploy large schema changes during peak hours