# Caching & Deduplication Strategy

## Overview
The caching system ensures that each apartment listing is retrieved only once from external sources unless explicitly refreshed by the user. This reduces load on apartment listing websites and improves application performance.

## Core Principles

### 1. Cache-First Approach
- Check local cache before making any external requests
- Only fetch from external sources if listing not found in cache
- Update cache metadata when existing listings are encountered

### 2. Multi-Level Deduplication
- **URL-based**: Exact URL matches for same listing
- **Content-based**: Hash comparison for same listing at different URLs
- **Address-based**: Normalized address matching for cross-platform duplicates

### 3. User-Controlled Refresh
- Normal operation never re-fetches cached listings
- Explicit `--refresh` commands bypass cache
- Granular refresh options (by source, date range, etc.)

## Cache Architecture

### Directory Structure
```
data/
├── cache/
│   ├── index.json              # Master cache index
│   ├── urls.json              # URL -> listing ID mapping
│   ├── hashes.json            # Content hash -> listing ID mapping
│   └── metadata.json          # Cache statistics and settings
├── listings/
│   ├── 2024-01-15/
│   │   ├── abc123.md          # Listing markdown files
│   │   ├── def456.md
│   │   └── raw/
│   │       ├── abc123.html    # Raw HTML for debugging
│   │       └── def456.html
│   └── 2024-01-16/
│       └── ...
└── preferences/
    ├── current.json           # Active user preferences
    └── history/
        └── ...
```

### Cache Index Structure
```go
type CacheIndex struct {
    Version     string                     `json:"version"`
    LastUpdated time.Time                 `json:"last_updated"`
    Listings    map[string]*CacheEntry    `json:"listings"` // listing ID -> cache entry
    Statistics  *CacheStatistics          `json:"statistics"`
}

type CacheEntry struct {
    ID            string    `json:"id"`
    Source        string    `json:"source"`
    SourceID      string    `json:"source_id"`
    URL           string    `json:"url"`
    AlternateURLs []string  `json:"alternate_urls,omitempty"`
    FilePath      string    `json:"file_path"`
    RawFilePath   string    `json:"raw_file_path,omitempty"`
    ContentHash   string    `json:"content_hash"`
    AddressHash   string    `json:"address_hash"`
    DateAdded     time.Time `json:"date_added"`
    LastSeen      time.Time `json:"last_seen"`
    LastUpdated   time.Time `json:"last_updated"`
    SeenCount     int       `json:"seen_count"`
    IsStale       bool      `json:"is_stale"`
}

type CacheStatistics struct {
    TotalListings      int                `json:"total_listings"`
    ListingsBySource   map[string]int     `json:"listings_by_source"`
    DuplicatesFound    int                `json:"duplicates_found"`
    LastRefreshTime    *time.Time         `json:"last_refresh_time,omitempty"`
    CacheHitRate       float64            `json:"cache_hit_rate"`
    AverageListingAge  time.Duration      `json:"average_listing_age"`
}
```

## Cache Manager Interface

### Core Operations
```go
type CacheManager interface {
    // Lookup operations
    ExistsByURL(url string) (*CacheEntry, bool)
    ExistsByContentHash(hash string) (*CacheEntry, bool)
    ExistsByAddressHash(hash string) (*CacheEntry, bool)
    GetListing(listingID string) (*Apartment, error)
    
    // Storage operations
    StoreListing(apartment *Apartment, rawHTML string) error
    UpdateListing(apartment *Apartment) error
    MarkSeen(listingID string) error
    LinkAlternateURL(listingID, url string) error
    
    // Batch operations
    GetListingsBySource(source string) ([]*Apartment, error)
    GetListingsByDateRange(start, end time.Time) ([]*Apartment, error)
    GetStaleListings(threshold time.Duration) ([]*CacheEntry, error)
    
    // Cache management
    RefreshListing(listingID string, force bool) (*Apartment, error)
    InvalidateListing(listingID string) error
    ClearSource(source string) error
    ClearAll() error
    GetStatistics() (*CacheStatistics, error)
    
    // Maintenance
    CompactCache() error
    ValidateCache() error
    BackupCache(backupPath string) error
}
```

### Implementation
```go
type FilesystemCacheManager struct {
    dataDir     string
    index       *CacheIndex
    urlMap      map[string]string    // URL -> listing ID
    hashMap     map[string]string    // content hash -> listing ID
    addressMap  map[string]string    // address hash -> listing ID
    mutex       sync.RWMutex
    logger      *slog.Logger
}

func NewFilesystemCacheManager(dataDir string, logger *slog.Logger) *FilesystemCacheManager {
    return &FilesystemCacheManager{
        dataDir:    dataDir,
        urlMap:     make(map[string]string),
        hashMap:    make(map[string]string),
        addressMap: make(map[string]string),
        logger:     logger,
    }
}

func (fcm *FilesystemCacheManager) ExistsByURL(url string) (*CacheEntry, bool) {
    fcm.mutex.RLock()
    defer fcm.mutex.RUnlock()
    
    if listingID, exists := fcm.urlMap[url]; exists {
        if entry, exists := fcm.index.Listings[listingID]; exists {
            return entry, true
        }
    }
    return nil, false
}
```

## Deduplication Logic

### Content Hash Generation
```go
func GenerateContentHash(apartment *Apartment) string {
    hasher := sha256.New()
    
    // Normalize and combine key identifying fields
    content := strings.Join([]string{
        normalizeAddress(apartment.Address),
        strings.ToLower(apartment.City),
        strings.ToUpper(apartment.State),
        apartment.ZipCode,
        strconv.Itoa(apartment.Price),
        strconv.Itoa(apartment.Bedrooms),
        fmt.Sprintf("%.1f", apartment.Bathrooms),
        normalizeDescription(apartment.Description),
    }, "|")
    
    hasher.Write([]byte(content))
    return hex.EncodeToString(hasher.Sum(nil))
}

func normalizeAddress(address string) string {
    // Remove extra whitespace
    address = strings.TrimSpace(regexp.MustCompile(`\s+`).ReplaceAllString(address, " "))
    
    // Normalize common abbreviations
    replacements := map[string]string{
        " Street":     " St",
        " Avenue":     " Ave",
        " Boulevard":  " Blvd",
        " Drive":      " Dr",
        " Road":       " Rd",
        " Lane":       " Ln",
        " Apartment":  " Apt",
        " Unit":       " #",
    }
    
    for full, abbrev := range replacements {
        address = strings.ReplaceAll(address, full, abbrev)
    }
    
    return strings.ToLower(address)
}
```

### Address Hash Generation
```go
func GenerateAddressHash(apartment *Apartment) string {
    hasher := sha256.New()
    
    // Focus only on location for cross-platform matching
    content := strings.Join([]string{
        normalizeAddress(apartment.Address),
        strings.ToLower(apartment.City),
        strings.ToUpper(apartment.State),
        apartment.ZipCode,
    }, "|")
    
    hasher.Write([]byte(content))
    return hex.EncodeToString(hasher.Sum(nil))[:16] // Shorter hash for addresses
}
```

## Cache Workflow

### New Listing Processing
```go
func (s *ScraperManager) ProcessListing(sourceURL string, rawListing *RawListing) (*Apartment, error) {
    // 1. Check URL cache first
    if entry, exists := s.cache.ExistsByURL(sourceURL); exists {
        s.logger.Debug("Cache hit by URL", "url", sourceURL, "listing_id", entry.ID)
        s.cache.MarkSeen(entry.ID)
        return s.cache.GetListing(entry.ID)
    }
    
    // 2. Parse raw listing into apartment struct
    apartment, err := s.parseRawListing(rawListing)
    if err != nil {
        return nil, fmt.Errorf("failed to parse listing: %w", err)
    }
    
    // 3. Generate hashes for deduplication
    apartment.ContentHash = GenerateContentHash(apartment)
    addressHash := GenerateAddressHash(apartment)
    
    // 4. Check content hash for exact duplicates
    if entry, exists := s.cache.ExistsByContentHash(apartment.ContentHash); exists {
        s.logger.Debug("Cache hit by content hash", "hash", apartment.ContentHash, "listing_id", entry.ID)
        s.cache.LinkAlternateURL(entry.ID, sourceURL)
        s.cache.MarkSeen(entry.ID)
        return s.cache.GetListing(entry.ID)
    }
    
    // 5. Check address hash for potential duplicates (same location, different details)
    if entry, exists := s.cache.ExistsByAddressHash(addressHash); exists {
        s.logger.Info("Potential duplicate by address", 
            "address_hash", addressHash, 
            "existing_id", entry.ID, 
            "new_url", sourceURL)
        
        // Store as new listing but flag for manual review
        apartment.ID = uuid.New().String()
        apartment.PotentialDuplicateOf = entry.ID
    } else {
        apartment.ID = uuid.New().String()
    }
    
    // 6. Store new listing in cache
    apartment.DateFound = time.Now()
    apartment.LastSeen = time.Now()
    
    err = s.cache.StoreListing(apartment, rawListing.HTML)
    if err != nil {
        return nil, fmt.Errorf("failed to store listing in cache: %w", err)
    }
    
    s.logger.Info("New listing cached", "id", apartment.ID, "source", apartment.Source)
    return apartment, nil
}
```

### Refresh Operations
```go
func (s *ScraperManager) RefreshListing(listingID string, force bool) (*Apartment, error) {
    // Get existing cache entry
    entry, exists := s.cache.index.Listings[listingID]
    if !exists {
        return nil, fmt.Errorf("listing not found in cache: %s", listingID)
    }
    
    // Check if refresh is needed
    if !force && !s.shouldRefresh(entry) {
        s.cache.MarkSeen(listingID)
        return s.cache.GetListing(listingID)
    }
    
    // Re-fetch from source
    scraper := s.getScraperForSource(entry.Source)
    rawListing, err := scraper.FetchListing(entry.URL)
    if err != nil {
        return nil, fmt.Errorf("failed to refresh listing: %w", err)
    }
    
    // Parse and compare with cached version
    newApartment, err := s.parseRawListing(rawListing)
    if err != nil {
        return nil, fmt.Errorf("failed to parse refreshed listing: %w", err)
    }
    
    // Preserve ID and metadata
    newApartment.ID = listingID
    newApartment.DateFound = entry.DateAdded
    newApartment.LastSeen = time.Now()
    
    // Check for changes
    newContentHash := GenerateContentHash(newApartment)
    if newContentHash != entry.ContentHash {
        s.logger.Info("Listing content changed", 
            "id", listingID, 
            "old_hash", entry.ContentHash, 
            "new_hash", newContentHash)
        
        // Update with new content
        newApartment.ContentHash = newContentHash
        err = s.cache.UpdateListing(newApartment)
        if err != nil {
            return nil, fmt.Errorf("failed to update cached listing: %w", err)
        }
    } else {
        // Just update last seen time
        s.cache.MarkSeen(listingID)
    }
    
    return newApartment, nil
}

func (s *ScraperManager) shouldRefresh(entry *CacheEntry) bool {
    // Refresh if listing is older than 24 hours
    return time.Since(entry.LastSeen) > 24*time.Hour
}
```

## CLI Cache Commands

### Cache Management Commands
```go
// Command definitions for cobra CLI
var cacheCmd = &cobra.Command{
    Use:   "cache",
    Short: "Cache management operations",
}

var cacheStatsCmd = &cobra.Command{
    Use:   "stats",
    Short: "Show cache statistics",
    Run: func(cmd *cobra.Command, args []string) {
        stats, err := cacheManager.GetStatistics()
        if err != nil {
            log.Fatal(err)
        }
        
        fmt.Printf("Cache Statistics:\n")
        fmt.Printf("  Total Listings: %d\n", stats.TotalListings)
        fmt.Printf("  Cache Hit Rate: %.2f%%\n", stats.CacheHitRate*100)
        fmt.Printf("  Duplicates Found: %d\n", stats.DuplicatesFound)
        fmt.Printf("  Average Age: %s\n", stats.AverageListingAge)
        
        fmt.Printf("\nListings by Source:\n")
        for source, count := range stats.ListingsBySource {
            fmt.Printf("  %s: %d\n", source, count)
        }
    },
}

var cacheClearCmd = &cobra.Command{
    Use:   "clear",
    Short: "Clear cache",
    Run: func(cmd *cobra.Command, args []string) {
        source, _ := cmd.Flags().GetString("source")
        
        if source != "" {
            err := cacheManager.ClearSource(source)
            if err != nil {
                log.Fatal(err)
            }
            fmt.Printf("Cleared cache for source: %s\n", source)
        } else {
            err := cacheManager.ClearAll()
            if err != nil {
                log.Fatal(err)
            }
            fmt.Printf("Cleared all cache\n")
        }
    },
}
```

### Search with Cache Options
```bash
# Normal search (uses cache)
apartment-hunt search

# Force refresh all sources
apartment-hunt search --refresh

# Refresh specific source
apartment-hunt search --refresh-source craigslist

# Refresh listings older than X hours
apartment-hunt search --refresh-older-than 24h

# Show cache statistics
apartment-hunt cache stats

# Clear cache for specific source
apartment-hunt cache clear --source craigslist

# Clear all cache
apartment-hunt cache clear

# Validate cache integrity
apartment-hunt cache validate

# Compact cache (remove stale entries)
apartment-hunt cache compact
```

## Performance Considerations

### Memory Management
- Load cache index into memory at startup
- Lazy load individual listings when needed
- Periodic cache compaction to remove stale entries
- Configurable cache size limits

### Disk I/O Optimization
- Batch write operations where possible
- Use temporary files for atomic updates
- Compress old cache entries
- Implement cache warming strategies

### Concurrency Safety
- Read-write locks for cache access
- Atomic file operations for consistency
- Proper error handling for concurrent access
- Graceful degradation under load

## Error Handling

### Cache Corruption Recovery
```go
func (fcm *FilesystemCacheManager) ValidateCache() error {
    errors := make([]error, 0)
    
    // Validate index structure
    if fcm.index == nil {
        return fmt.Errorf("cache index is nil")
    }
    
    // Check file existence
    for listingID, entry := range fcm.index.Listings {
        if _, err := os.Stat(entry.FilePath); os.IsNotExist(err) {
            errors = append(errors, fmt.Errorf("missing file for listing %s: %s", listingID, entry.FilePath))
        }
    }
    
    // Validate hash mappings
    for url, listingID := range fcm.urlMap {
        if _, exists := fcm.index.Listings[listingID]; !exists {
            errors = append(errors, fmt.Errorf("orphaned URL mapping: %s -> %s", url, listingID))
        }
    }
    
    if len(errors) > 0 {
        return fmt.Errorf("cache validation failed with %d errors: %v", len(errors), errors)
    }
    
    return nil
}

func (fcm *FilesystemCacheManager) RepairCache() error {
    // Remove orphaned entries
    // Rebuild index from existing files
    // Fix inconsistent mappings
    // Return summary of repairs made
}
```