# Cache Entries Data Model

> **Related Documents:**
> - [Data Models Index](../data-models.md) - Central data model index
> - [Listings](listings.md) - Apartment listing data
> - [Caching Strategy](../caching.md) - Deduplication and storage mechanisms
> - [Back to Documentation Index](../../README.md)

## Overview

The Cache Entries model manages metadata for listing deduplication, source tracking, and cache management. This data helps prevent duplicate scraping, tracks listing freshness, and maintains efficient storage operations across multiple data sources.

## Data Structure

### Cache Entry Model
```go
type CacheEntry struct {
    ID          string    `json:"id" db:"id" validate:"required"`
    ListingID   string    `json:"listing_id" db:"listing_id" validate:"required"`
    
    // File and storage information
    FilePath    string    `json:"file_path,omitempty" db:"file_path"`
    FileSize    *int64    `json:"file_size,omitempty" db:"file_size"`
    FileFormat  string    `json:"file_format,omitempty" db:"file_format" validate:"omitempty,oneof=json markdown html"`
    
    // Source tracking
    Source      string    `json:"source" db:"source" validate:"required"`
    SourceURL   string    `json:"source_url" db:"source_url" validate:"required,url"`
    SourceID    string    `json:"source_id" db:"source_id" validate:"required"`
    
    // Deduplication metadata
    ContentHash string    `json:"content_hash" db:"content_hash" validate:"required"`
    URLHash     string    `json:"url_hash" db:"url_hash" validate:"required"`
    AddressHash string    `json:"address_hash" db:"address_hash" validate:"required"`
    
    // Cache management
    LastSeen    time.Time `json:"last_seen" db:"last_seen" validate:"required"`
    DateAdded   time.Time `json:"date_added" db:"date_added" validate:"required"`
    AccessCount int       `json:"access_count" db:"access_count"`
    LastAccess  *time.Time `json:"last_access,omitempty" db:"last_access"`
    
    // Data quality and validation
    DataQuality    float64   `json:"data_quality" db:"data_quality" validate:"min=0,max=1"`
    ValidationHash string    `json:"validation_hash" db:"validation_hash"`
    IsValidated    bool      `json:"is_validated" db:"is_validated"`
    ValidationDate *time.Time `json:"validation_date,omitempty" db:"validation_date"`
    
    // Staleness tracking
    IsStale        bool       `json:"is_stale" db:"is_stale"`
    StalenessScore float64    `json:"staleness_score" db:"staleness_score" validate:"min=0,max=1"`
    NextCheckDue   *time.Time `json:"next_check_due,omitempty" db:"next_check_due"`
    
    // Error tracking
    ErrorCount     int        `json:"error_count" db:"error_count"`
    LastError      *string    `json:"last_error,omitempty" db:"last_error"`
    LastErrorDate  *time.Time `json:"last_error_date,omitempty" db:"last_error_date"`
    
    // Metadata and tags
    Metadata       map[string]interface{} `json:"metadata,omitempty" db:"metadata"`
    Tags           []string              `json:"tags,omitempty" db:"tags"`
    
    // Timestamps
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
    UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
    
    // Soft delete
    DeletedAt   *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
}
```

### Cache Statistics
```go
type CacheStatistics struct {
    TotalEntries      int                    `json:"total_entries"`
    EntriesBySource   map[string]int         `json:"entries_by_source"`
    TotalStorageSize  int64                  `json:"total_storage_size"`
    AverageFileSize   float64                `json:"average_file_size"`
    
    // Freshness metrics
    FreshEntries      int                    `json:"fresh_entries"`      // < 24 hours
    StaleEntries      int                    `json:"stale_entries"`      // > 7 days
    ErrorEntries      int                    `json:"error_entries"`      // Has errors
    
    // Performance metrics
    HitRate           float64                `json:"hit_rate"`           // Cache hits / total requests
    MissRate          float64                `json:"miss_rate"`          // Cache misses / total requests
    AverageAccessTime time.Duration         `json:"average_access_time"`
    
    // Data quality
    HighQualityEntries int                   `json:"high_quality_entries"` // Quality > 0.8
    ValidatedEntries   int                   `json:"validated_entries"`
    DuplicateEntries   int                   `json:"duplicate_entries"`
    
    LastUpdated       time.Time              `json:"last_updated"`
}
```

### Deduplication Index
```go
type DeduplicationIndex struct {
    ContentHashes map[string][]string `json:"content_hashes"` // hash -> listing IDs
    URLHashes     map[string][]string `json:"url_hashes"`     // hash -> listing IDs  
    AddressHashes map[string][]string `json:"address_hashes"` // hash -> listing IDs
    LastUpdated   time.Time           `json:"last_updated"`
}
```

## Database Schema

### cache_entries table
```sql
CREATE TABLE cache_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    
    -- File and storage information
    file_path TEXT,
    file_size BIGINT,
    file_format VARCHAR(20),
    
    -- Source tracking
    source VARCHAR(50) NOT NULL,
    source_url TEXT NOT NULL,
    source_id VARCHAR(255) NOT NULL,
    
    -- Deduplication metadata
    content_hash VARCHAR(64) NOT NULL,
    url_hash VARCHAR(64) NOT NULL,
    address_hash VARCHAR(64) NOT NULL,
    
    -- Cache management
    last_seen TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    date_added TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    access_count INTEGER NOT NULL DEFAULT 0,
    last_access TIMESTAMP WITH TIME ZONE,
    
    -- Data quality and validation
    data_quality DECIMAL(3,2) NOT NULL DEFAULT 0.0,
    validation_hash VARCHAR(64),
    is_validated BOOLEAN NOT NULL DEFAULT false,
    validation_date TIMESTAMP WITH TIME ZONE,
    
    -- Staleness tracking
    is_stale BOOLEAN NOT NULL DEFAULT false,
    staleness_score DECIMAL(3,2) NOT NULL DEFAULT 0.0,
    next_check_due TIMESTAMP WITH TIME ZONE,
    
    -- Error tracking
    error_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    last_error_date TIMESTAMP WITH TIME ZONE,
    
    -- Metadata and tags
    metadata JSONB,
    tags TEXT[],
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT cache_entries_file_format_check CHECK (
        file_format IN ('json', 'markdown', 'html') OR file_format IS NULL
    ),
    CONSTRAINT cache_entries_data_quality_check CHECK (
        data_quality >= 0.0 AND data_quality <= 1.0
    ),
    CONSTRAINT cache_entries_staleness_check CHECK (
        staleness_score >= 0.0 AND staleness_score <= 1.0
    ),
    CONSTRAINT cache_entries_error_count_check CHECK (error_count >= 0)
);

-- Primary indexes for lookups
CREATE INDEX idx_cache_entries_listing_id ON cache_entries (listing_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_cache_entries_source ON cache_entries (source) WHERE deleted_at IS NULL;
CREATE INDEX idx_cache_entries_source_id ON cache_entries (source, source_id) WHERE deleted_at IS NULL;

-- Deduplication indexes
CREATE INDEX idx_cache_entries_content_hash ON cache_entries (content_hash);
CREATE INDEX idx_cache_entries_url_hash ON cache_entries (url_hash);
CREATE INDEX idx_cache_entries_address_hash ON cache_entries (address_hash);

-- Cache management indexes
CREATE INDEX idx_cache_entries_last_seen ON cache_entries (last_seen);
CREATE INDEX idx_cache_entries_staleness ON cache_entries (is_stale, staleness_score, next_check_due);
CREATE INDEX idx_cache_entries_access ON cache_entries (access_count, last_access);

-- Data quality indexes
CREATE INDEX idx_cache_entries_quality ON cache_entries (data_quality, is_validated);
CREATE INDEX idx_cache_entries_errors ON cache_entries (error_count, last_error_date) 
WHERE error_count > 0;

-- Performance indexes
CREATE INDEX idx_cache_entries_file_size ON cache_entries (file_size) WHERE file_size IS NOT NULL;
CREATE INDEX idx_cache_entries_tags ON cache_entries USING GIN (tags);
CREATE INDEX idx_cache_entries_metadata ON cache_entries USING GIN (metadata);

-- Composite indexes for common queries
CREATE INDEX idx_cache_entries_source_quality ON cache_entries (source, data_quality, is_stale);
CREATE INDEX idx_cache_entries_fresh_validated ON cache_entries (is_validated, is_stale, last_seen);
```

## Business Logic

### Cache Entry Management
```go
func (ce *CacheEntry) Create() error {
    // Generate ID and hashes
    ce.ID = uuid.New().String()
    ce.GenerateHashes()
    
    // Set timestamps
    now := time.Now()
    ce.DateAdded = now
    ce.LastSeen = now
    ce.CreatedAt = now
    ce.UpdatedAt = now
    
    // Calculate initial data quality
    ce.CalculateDataQuality()
    
    // Validate
    if err := ce.Validate(); err != nil {
        return err
    }
    
    return ce.Save()
}

func (ce *CacheEntry) UpdateAccess() error {
    now := time.Now()
    ce.AccessCount++
    ce.LastAccess = &now
    ce.UpdatedAt = now
    
    return ce.SaveAccessMetrics()
}
```

### Hash Generation
```go
func (ce *CacheEntry) GenerateHashes() {
    // Content hash from listing content
    ce.ContentHash = ce.generateContentHash()
    
    // URL hash for deduplication
    ce.URLHash = ce.generateURLHash()
    
    // Address hash for location-based deduplication
    ce.AddressHash = ce.generateAddressHash()
    
    // Validation hash for integrity checking
    ce.ValidationHash = ce.generateValidationHash()
}

func (ce *CacheEntry) generateContentHash() string {
    // Implementation would hash listing content
    hasher := sha256.New()
    hasher.Write([]byte(ce.SourceURL + ce.SourceID))
    return hex.EncodeToString(hasher.Sum(nil))
}
```

### Staleness Management
```go
func (ce *CacheEntry) UpdateStaleness() {
    now := time.Now()
    timeSinceLastSeen := now.Sub(ce.LastSeen)
    
    // Calculate staleness score (0 = fresh, 1 = very stale)
    daysSinceLastSeen := timeSinceLastSeen.Hours() / 24
    ce.StalenessScore = math.Min(daysSinceLastSeen/30.0, 1.0) // Stale after 30 days
    
    // Mark as stale if older than threshold
    ce.IsStale = daysSinceLastSeen > 7.0 // 7 days
    
    // Set next check due date based on staleness
    if ce.IsStale {
        ce.NextCheckDue = &now // Check immediately if stale
    } else {
        nextCheck := now.Add(24 * time.Hour) // Daily checks for fresh content
        ce.NextCheckDue = &nextCheck
    }
    
    ce.UpdatedAt = now
}
```

### Data Quality Calculation
```go
func (ce *CacheEntry) CalculateDataQuality() {
    score := 1.0
    
    // Reduce score for errors
    if ce.ErrorCount > 0 {
        score -= float64(ce.ErrorCount) * 0.1
    }
    
    // Reduce score for staleness
    score -= ce.StalenessScore * 0.3
    
    // Bonus for validation
    if ce.IsValidated {
        score += 0.1
    }
    
    // Bonus for file size (indicates complete data)
    if ce.FileSize != nil && *ce.FileSize > 1024 {
        score += 0.1
    }
    
    // Ensure score is between 0 and 1
    ce.DataQuality = math.Max(0.0, math.Min(1.0, score))
}
```

### Error Tracking
```go
func (ce *CacheEntry) RecordError(err error) {
    ce.ErrorCount++
    errorMsg := err.Error()
    ce.LastError = &errorMsg
    now := time.Now()
    ce.LastErrorDate = &now
    ce.UpdatedAt = now
    
    // Reduce data quality for errors
    ce.CalculateDataQuality()
}

func (ce *CacheEntry) ClearErrors() {
    ce.ErrorCount = 0
    ce.LastError = nil
    ce.LastErrorDate = nil
    ce.UpdatedAt = time.Now()
    
    // Recalculate data quality
    ce.CalculateDataQuality()
}
```

## Deduplication Operations

### Duplicate Detection
```go
func (s *CacheService) FindDuplicatesByContent(contentHash string) ([]*CacheEntry, error) {
    return s.repo.FindByContentHash(contentHash)
}

func (s *CacheService) FindDuplicatesByURL(urlHash string) ([]*CacheEntry, error) {
    return s.repo.FindByURLHash(urlHash)
}

func (s *CacheService) FindDuplicatesByAddress(addressHash string) ([]*CacheEntry, error) {
    return s.repo.FindByAddressHash(addressHash)
}

func (s *CacheService) DetectAllDuplicates(entry *CacheEntry) (*DuplicationReport, error) {
    contentDupes, _ := s.FindDuplicatesByContent(entry.ContentHash)
    urlDupes, _ := s.FindDuplicatesByURL(entry.URLHash)
    addressDupes, _ := s.FindDuplicatesByAddress(entry.AddressHash)
    
    return &DuplicationReport{
        Entry:           entry,
        ContentDupes:    contentDupes,
        URLDupes:        urlDupes,
        AddressDupes:    addressDupes,
        HasDuplicates:   len(contentDupes) > 1 || len(urlDupes) > 1 || len(addressDupes) > 1,
        GeneratedAt:     time.Now(),
    }, nil
}
```

### Cache Cleanup Operations
```go
func (s *CacheService) CleanupStaleEntries(maxAge time.Duration) (int, error) {
    cutoff := time.Now().Add(-maxAge)
    staleEntries, err := s.repo.FindStaleEntries(cutoff)
    if err != nil {
        return 0, err
    }
    
    deleted := 0
    for _, entry := range staleEntries {
        if err := s.DeleteCacheEntry(entry.ID); err == nil {
            deleted++
        }
    }
    
    return deleted, nil
}

func (s *CacheService) CleanupErrorEntries(maxErrors int) (int, error) {
    errorEntries, err := s.repo.FindEntriesWithErrors(maxErrors)
    if err != nil {
        return 0, err
    }
    
    deleted := 0
    for _, entry := range errorEntries {
        if err := s.DeleteCacheEntry(entry.ID); err == nil {
            deleted++
        }
    }
    
    return deleted, nil
}
```

## Cache Statistics and Analytics

### Performance Metrics
```go
func (s *CacheService) GetCacheStatistics() (*CacheStatistics, error) {
    stats := &CacheStatistics{
        LastUpdated: time.Now(),
    }
    
    // Basic counts
    stats.TotalEntries = s.repo.CountAll()
    stats.EntriesBySource = s.repo.CountBySource()
    
    // Storage metrics
    stats.TotalStorageSize = s.repo.SumFileSize()
    if stats.TotalEntries > 0 {
        stats.AverageFileSize = float64(stats.TotalStorageSize) / float64(stats.TotalEntries)
    }
    
    // Freshness metrics
    oneDayAgo := time.Now().Add(-24 * time.Hour)
    sevenDaysAgo := time.Now().Add(-7 * 24 * time.Hour)
    
    stats.FreshEntries = s.repo.CountNewerThan(oneDayAgo)
    stats.StaleEntries = s.repo.CountOlderThan(sevenDaysAgo)
    stats.ErrorEntries = s.repo.CountWithErrors()
    
    // Data quality metrics
    stats.HighQualityEntries = s.repo.CountByQuality(0.8)
    stats.ValidatedEntries = s.repo.CountValidated()
    stats.DuplicateEntries = s.repo.CountDuplicates()
    
    return stats, nil
}
```

### Cache Optimization
```go
func (s *CacheService) OptimizeCache() (*OptimizationReport, error) {
    report := &OptimizationReport{
        StartTime: time.Now(),
    }
    
    // Remove duplicates
    duplicates := s.findAndRemoveDuplicates()
    report.DuplicatesRemoved = len(duplicates)
    
    // Cleanup stale entries
    staleRemoved, _ := s.CleanupStaleEntries(30 * 24 * time.Hour)
    report.StaleEntriesRemoved = staleRemoved
    
    // Cleanup error entries
    errorRemoved, _ := s.CleanupErrorEntries(5)
    report.ErrorEntriesRemoved = errorRemoved
    
    // Recalculate data quality scores
    s.recalculateDataQuality()
    
    report.EndTime = time.Now()
    report.Duration = report.EndTime.Sub(report.StartTime)
    
    return report, nil
}
```

## API Operations

### Core Operations
- `CreateCacheEntry(listingID, entry)` - Add new cache entry
- `GetCacheEntry(id)` - Retrieve cache entry by ID
- `UpdateCacheEntry(id, updates)` - Modify cache entry
- `DeleteCacheEntry(id)` - Remove cache entry
- `UpdateLastSeen(id)` - Mark entry as recently seen
- `IncrementAccess(id)` - Track access for usage stats

### Deduplication Operations
- `FindDuplicates(hash, hashType)` - Find entries with matching hash
- `DetectDuplicates(entry)` - Comprehensive duplicate detection
- `MergeCacheEntries(primaryID, duplicateIDs)` - Merge duplicate entries
- `GetDeduplicationIndex()` - Get current deduplication mappings

### Cache Management Operations
- `GetCacheStatistics()` - Cache performance and usage stats
- `CleanupStaleEntries(maxAge)` - Remove old entries
- `CleanupErrorEntries(maxErrors)` - Remove problematic entries
- `OptimizeCache()` - Comprehensive cache optimization
- `ValidateCache()` - Check cache integrity

### Monitoring Operations
- `GetHealthMetrics()` - Cache health indicators
- `GetStorageUsage()` - Disk space and file metrics
- `GetAccessPatterns()` - Usage pattern analysis
- `GetErrorAnalysis()` - Error frequency and types