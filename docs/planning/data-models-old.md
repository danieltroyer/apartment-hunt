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
- Session management
- Profile and preferences
- Multi-user data isolation

#### [User Preferences](data-models/user-preferences.md)
Search criteria and filtering preferences for each user.
- Geographic preferences and constraints
- Price, size, and feature requirements
- Notification and alert settings
- Default preference management

#### [Listings](data-models/listings.md)
Apartment listing data from multiple sources.
- Property details and descriptions
- Multi-source information aggregation
- Availability tracking
- Geographic and media data

#### [User Feedback](data-models/user-feedback.md)
User opinions, ratings, and interactions with listings.
- Rating system and comments
- Application tracking
- Follow-up reminders
- Private notes and recommendations

#### [Cache Entries](data-models/cache-entries.md)
Deduplication metadata and cache management.
- Source tracking and validation
- Content and address hashing
- Staleness and data quality metrics
- Performance optimization

## Data Relationships Overview

### Apartment Listing
```go
type Apartment struct {
    ID          string    `json:"id" validate:"required"`
    Source      string    `json:"source" validate:"required,oneof=craigslist zillow apartments rentals"`
    SourceID    string    `json:"source_id" validate:"required"`    // Original ID from source
    URL         string    `json:"url" validate:"required,url"`
    AlternateURLs []string `json:"alternate_urls,omitempty" validate:"dive,url"` // Same listing on multiple sources
    Address     string    `json:"address" validate:"required,min=5"`
    City        string    `json:"city" validate:"required,min=2"`
    State       string    `json:"state" validate:"required,len=2"`
    ZipCode     string    `json:"zip_code" validate:"required,len=5"`
    Price       int       `json:"price" validate:"required,min=0"`
    Bedrooms    int       `json:"bedrooms" validate:"required,min=0,max=10"`
    Bathrooms   float64   `json:"bathrooms" validate:"required,min=0,max=20"`
    SquareFeet  int       `json:"square_feet,omitempty" validate:"omitempty,min=100"`
    Description string    `json:"description" validate:"required,min=10"`
    Images      []string  `json:"images,omitempty" validate:"dive,url"`
    DatePosted  time.Time `json:"date_posted" validate:"required"`
    DateFound   time.Time `json:"date_found" validate:"required"`
    LastSeen    time.Time `json:"last_seen" validate:"required"`    // For tracking listing staleness
    ContentHash string    `json:"content_hash" validate:"required"` // For detecting changes
    AddressHash string    `json:"address_hash" validate:"required"` // For cross-platform deduplication
    
    // Availability tracking
    Availability      AvailabilityStatus `json:"availability" validate:"required"`
    AvailabilityChecks []AvailabilityCheck `json:"availability_checks,omitempty"`
    LastAvailableCheck time.Time          `json:"last_available_check"`
    UnavailableSince   *time.Time         `json:"unavailable_since,omitempty"`
    
    // Multi-source information
    Sources        []SourceInfo `json:"sources,omitempty"`        // All sources for this listing
    PrimarySource  string       `json:"primary_source"`          // Best/preferred source
    DataSource     DataSource   `json:"data_source"`             // API vs scraping
    
    // Computed fields
    PricePerSqFt float64 `json:"price_per_sq_ft,omitempty"`
}

type AvailabilityStatus string

const (
    Available       AvailabilityStatus = "available"
    Unavailable     AvailabilityStatus = "unavailable"
    Unknown         AvailabilityStatus = "unknown"
    CheckFailed     AvailabilityStatus = "check_failed"
)

type AvailabilityCheck struct {
    Timestamp time.Time          `json:"timestamp"`
    Source    string             `json:"source"`
    Status    AvailabilityStatus `json:"status"`
    Method    string             `json:"method"` // "api", "scrape", "http_status"
    Details   string             `json:"details,omitempty"`
    Error     string             `json:"error,omitempty"`
}

type SourceInfo struct {
    Source      string    `json:"source"`
    SourceID    string    `json:"source_id"`
    URL         string    `json:"url"`
    FirstSeen   time.Time `json:"first_seen"`
    LastSeen    time.Time `json:"last_seen"`
    DataQuality float64   `json:"data_quality"` // 0-1 score for data completeness
    IsActive    bool      `json:"is_active"`
}

type DataSource string

const (
    APISource     DataSource = "api"
    ScrapingSource DataSource = "scraping"
    HybridSource   DataSource = "hybrid"
)

// Validation and helper methods
func (a *Apartment) Validate() error {
    validate := validator.New()
    return validate.Struct(a)
}

func (a *Apartment) GenerateID() {
    a.ID = uuid.New().String()
}

func (a *Apartment) GenerateContentHash() {
    hasher := sha256.New()
    content := fmt.Sprintf("%s|%s|%d|%d|%.1f|%s", 
        a.Address, a.City, a.Price, a.Bedrooms, a.Bathrooms, a.Description)
    hasher.Write([]byte(content))
    a.ContentHash = hex.EncodeToString(hasher.Sum(nil))
}

func (a *Apartment) CalculatePricePerSqFt() {
    if a.SquareFeet > 0 {
        a.PricePerSqFt = float64(a.Price) / float64(a.SquareFeet)
    }
}

func (a *Apartment) IsStale(threshold time.Duration) bool {
    return time.Since(a.LastSeen) > threshold
}
```

### User Preferences
```go
type Preferences struct {
    ID          string    `json:"id"`
    Geography   Geography `json:"geography" validate:"required"`
    PriceRange  Range     `json:"price_range" validate:"required"`
    Bedrooms    Range     `json:"bedrooms" validate:"required"`
    Bathrooms   Range     `json:"bathrooms,omitempty"`
    MinSqFt     int       `json:"min_sq_ft,omitempty" validate:"omitempty,min=100"`
    MaxSqFt     int       `json:"max_sq_ft,omitempty" validate:"omitempty,min=100"`
    Keywords    []string  `json:"keywords,omitempty" validate:"dive,min=2"`
    Exclusions  []string  `json:"exclusions,omitempty" validate:"dive,min=2"`
    Sources     []string  `json:"sources" validate:"required,dive,oneof=craigslist zillow apartments"`
    UpdatedAt   time.Time `json:"updated_at"`
    CreatedAt   time.Time `json:"created_at"`
}

type Geography struct {
    Cities      []string `json:"cities" validate:"required,min=1,dive,min=2"`
    ZipCodes    []string `json:"zip_codes,omitempty" validate:"dive,len=5"`
    MaxDistance int      `json:"max_distance,omitempty" validate:"omitempty,min=1,max=100"` // miles from center
    CenterLat   float64  `json:"center_lat,omitempty" validate:"omitempty,latitude"`
    CenterLng   float64  `json:"center_lng,omitempty" validate:"omitempty,longitude"`
}

type Range struct {
    Min int `json:"min" validate:"min=0"`
    Max int `json:"max" validate:"gtefield=Min"`
}

// Validation and helper methods
func (p *Preferences) Validate() error {
    validate := validator.New()
    
    // Custom validation for latitude/longitude
    validate.RegisterValidation("latitude", validateLatitude)
    validate.RegisterValidation("longitude", validateLongitude)
    
    return validate.Struct(p)
}

func (p *Preferences) Matches(apartment *Apartment) bool {
    // Price range check
    if apartment.Price < p.PriceRange.Min || apartment.Price > p.PriceRange.Max {
        return false
    }
    
    // Bedroom range check
    if apartment.Bedrooms < p.Bedrooms.Min || apartment.Bedrooms > p.Bedrooms.Max {
        return false
    }
    
    // Bathroom range check (if specified)
    if p.Bathrooms.Max > 0 {
        if apartment.Bathrooms < float64(p.Bathrooms.Min) || 
           apartment.Bathrooms > float64(p.Bathrooms.Max) {
            return false
        }
    }
    
    // Square footage check
    if p.MinSqFt > 0 && apartment.SquareFeet > 0 && apartment.SquareFeet < p.MinSqFt {
        return false
    }
    if p.MaxSqFt > 0 && apartment.SquareFeet > 0 && apartment.SquareFeet > p.MaxSqFt {
        return false
    }
    
    // Geography check
    if !p.Geography.Contains(apartment) {
        return false
    }
    
    // Keywords check
    if !p.containsKeywords(apartment) {
        return false
    }
    
    // Exclusions check
    if p.containsExclusions(apartment) {
        return false
    }
    
    return true
}

func (g *Geography) Contains(apartment *Apartment) bool {
    // City check
    for _, city := range g.Cities {
        if strings.EqualFold(city, apartment.City) {
            return true
        }
    }
    
    // Zip code check
    for _, zip := range g.ZipCodes {
        if zip == apartment.ZipCode {
            return true
        }
    }
    
    // Distance check (if center coordinates provided)
    if g.CenterLat != 0 && g.CenterLng != 0 && g.MaxDistance > 0 {
        // Would need geocoding for apartment address
        // Implementation depends on geocoding service
        return g.withinDistance(apartment)
    }
    
    return len(g.Cities) == 0 && len(g.ZipCodes) == 0
}
```

### User Feedback
```go
type Feedback struct {
    ID          string                 `json:"id" validate:"required"`
    ApartmentID string                 `json:"apartment_id" validate:"required"`
    Rating      FeedbackRating         `json:"rating" validate:"required,oneof=0 1 2 3"`
    Comments    string                 `json:"comments,omitempty" validate:"omitempty,max=1000"`
    Attributes  map[string]int         `json:"attributes,omitempty" validate:"dive,min=1,max=5"` // price: 1-5, location: 1-5, etc.
    Timestamp   time.Time             `json:"timestamp" validate:"required"`
    UserID      string                `json:"user_id,omitempty"` // For multi-user support
}

type FeedbackRating int

const (
    Dislike FeedbackRating = iota
    Neutral
    Like
    Love
)

func (f FeedbackRating) String() string {
    switch f {
    case Dislike:
        return "dislike"
    case Neutral:
        return "neutral"
    case Like:
        return "like"
    case Love:
        return "love"
    default:
        return "unknown"
    }
}

// Validation and helper methods
func (f *Feedback) Validate() error {
    validate := validator.New()
    return validate.Struct(f)
}

func (f *Feedback) IsPositive() bool {
    return f.Rating >= Like
}

func (f *Feedback) IsNegative() bool {
    return f.Rating == Dislike
}

// Feedback aggregation for learning
type FeedbackSummary struct {
    ApartmentID    string             `json:"apartment_id"`
    TotalFeedback  int                `json:"total_feedback"`
    PositiveCount  int                `json:"positive_count"`
    NegativeCount  int                `json:"negative_count"`
    AverageRating  float64            `json:"average_rating"`
    AttributeScores map[string]float64 `json:"attribute_scores"`
    LastUpdated    time.Time          `json:"last_updated"`
}
```

## Search and Filtering Models

### Search Filters
```go
type SearchFilters struct {
    Preferences   *Preferences `json:"preferences"`
    SortBy        SortOption   `json:"sort_by"`
    SortOrder     SortOrder    `json:"sort_order"`
    Limit         int          `json:"limit" validate:"min=1,max=1000"`
    Offset        int          `json:"offset" validate:"min=0"`
    IncludeStale  bool         `json:"include_stale"`
    Sources       []string     `json:"sources,omitempty"`
    DateRange     *DateRange   `json:"date_range,omitempty"`
}

type SortOption string

const (
    SortByPrice       SortOption = "price"
    SortByDate        SortOption = "date"
    SortByBedrooms    SortOption = "bedrooms"
    SortBySquareFeet  SortOption = "square_feet"
    SortByPricePerSqFt SortOption = "price_per_sq_ft"
    SortByRelevance   SortOption = "relevance"
)

type SortOrder string

const (
    SortAsc  SortOrder = "asc"
    SortDesc SortOrder = "desc"
)

type DateRange struct {
    Start *time.Time `json:"start,omitempty"`
    End   *time.Time `json:"end,omitempty"`
}
```

### Search Results
```go
type SearchResults struct {
    Apartments    []*Apartment `json:"apartments"`
    Total         int          `json:"total"`
    Limit         int          `json:"limit"`
    Offset        int          `json:"offset"`
    Filters       *SearchFilters `json:"filters"`
    ExecutionTime time.Duration `json:"execution_time"`
    Sources       map[string]int `json:"sources"` // source -> count
}

func (sr *SearchResults) HasMore() bool {
    return sr.Offset + len(sr.Apartments) < sr.Total
}

func (sr *SearchResults) NextOffset() int {
    return sr.Offset + sr.Limit
}
```

## Cache and Storage Models

### Cache Index
```go
type CacheIndex struct {
    Version     string                `json:"version"`
    LastUpdated time.Time            `json:"last_updated"`
    Listings    map[string]*CacheEntry `json:"listings"` // listing ID -> cache entry
    URLs        map[string]string     `json:"urls"`     // URL -> listing ID
    Hashes      map[string]string     `json:"hashes"`   // content hash -> listing ID
    Sources     map[string][]string   `json:"sources"`  // source -> listing IDs
}

type CacheEntry struct {
    ID          string    `json:"id"`
    FilePath    string    `json:"file_path"`
    Source      string    `json:"source"`
    URL         string    `json:"url"`
    ContentHash string    `json:"content_hash"`
    LastSeen    time.Time `json:"last_seen"`
    DateAdded   time.Time `json:"date_added"`
}

func (ci *CacheIndex) AddListing(apartment *Apartment, filePath string) {
    entry := &CacheEntry{
        ID:          apartment.ID,
        FilePath:    filePath,
        Source:      apartment.Source,
        URL:         apartment.URL,
        ContentHash: apartment.ContentHash,
        LastSeen:    apartment.LastSeen,
        DateAdded:   time.Now(),
    }
    
    ci.Listings[apartment.ID] = entry
    ci.URLs[apartment.URL] = apartment.ID
    ci.Hashes[apartment.ContentHash] = apartment.ID
    
    if ci.Sources[apartment.Source] == nil {
        ci.Sources[apartment.Source] = make([]string, 0)
    }
    ci.Sources[apartment.Source] = append(ci.Sources[apartment.Source], apartment.ID)
    
    ci.LastUpdated = time.Now()
}

func (ci *CacheIndex) ExistsByURL(url string) (bool, string) {
    if listingID, exists := ci.URLs[url]; exists {
        return true, listingID
    }
    return false, ""
}

func (ci *CacheIndex) ExistsByHash(hash string) (bool, string) {
    if listingID, exists := ci.Hashes[hash]; exists {
        return true, listingID
    }
    return false, ""
}
```

## Validation Helpers

### Custom Validators
```go
func validateLatitude(fl validator.FieldLevel) bool {
    lat := fl.Field().Float()
    return lat >= -90.0 && lat <= 90.0
}

func validateLongitude(fl validator.FieldLevel) bool {
    lng := fl.Field().Float()
    return lng >= -180.0 && lng <= 180.0
}

func validateZipCode(fl validator.FieldLevel) bool {
    zip := fl.Field().String()
    matched, _ := regexp.MatchString(`^\d{5}(-\d{4})?$`, zip)
    return matched
}
```

## Serialization Formats

### Markdown Output Format
```markdown
# Apartment Listing - {{.ID}}

**Source**: {{.Source}}  
**Address**: {{.Address}}, {{.City}}, {{.State}} {{.ZipCode}}  
**Price**: ${{.Price}}/month  
**Bedrooms**: {{.Bedrooms}} | **Bathrooms**: {{.Bathrooms}}  
{{if .SquareFeet}}**Square Feet**: {{.SquareFeet}} | **Price/SqFt**: ${{printf "%.2f" .PricePerSqFt}}{{end}}

## Description
{{.Description}}

## Details
- **Date Posted**: {{.DatePosted.Format "2006-01-02"}}
- **Date Found**: {{.DateFound.Format "2006-01-02"}}
- **Last Seen**: {{.LastSeen.Format "2006-01-02"}}
- **Source URL**: [View Listing]({{.URL}})

{{if .Images}}
## Images
{{range .Images}}
- ![Image]({{.}})
{{end}}
{{end}}

## User Feedback
{{if .Feedback}}
{{range .Feedback}}
### {{.Timestamp.Format "2006-01-02 15:04"}} - {{.Rating}}
{{.Comments}}
{{end}}
{{else}}
*No feedback yet*
{{end}}
```

## Data Relationships

### Entity Relationship Diagram
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Apartment  │────▶│  Feedback   │────▶│ Preferences │
│             │     │             │     │             │
│ - ID        │     │ - ID        │     │ - ID        │
│ - Source    │     │ - ApartmentID│     │ - Geography │
│ - Address   │     │ - Rating    │     │ - PriceRange│
│ - Price     │     │ - Comments  │     │ - Bedrooms  │
│ - ...       │     │ - Timestamp │     │ - ...       │
└─────────────┘     └─────────────┘     └─────────────┘
        │                                       │
        │           ┌─────────────┐             │
        └──────────▶│ CacheIndex  │◀────────────┘
                    │             │
                    │ - Listings  │
                    │ - URLs      │
                    │ - Hashes    │
                    └─────────────┘
```

## Database Schema Design

### PostgreSQL Tables

#### apartments
```sql
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

-- Indexes for efficient querying
CREATE INDEX idx_apartments_city_state ON apartments (city, state);
CREATE INDEX idx_apartments_price ON apartments (price);
CREATE INDEX idx_apartments_bedrooms ON apartments (bedrooms);
CREATE INDEX idx_apartments_bathrooms ON apartments (bathrooms);
CREATE INDEX idx_apartments_square_feet ON apartments (square_feet);
CREATE INDEX idx_apartments_availability ON apartments (availability);
CREATE INDEX idx_apartments_date_posted ON apartments (date_posted);
CREATE INDEX idx_apartments_content_hash ON apartments (content_hash);
CREATE INDEX idx_apartments_address_hash ON apartments (address_hash);
CREATE INDEX idx_apartments_url ON apartments (url);
CREATE INDEX idx_apartments_source ON apartments (source);
CREATE INDEX idx_apartments_price_bed_bath ON apartments (price, bedrooms, bathrooms);

-- Compound index for search optimization
CREATE INDEX idx_apartments_search ON apartments (city, state, price, bedrooms, bathrooms, availability);
```

#### user_preferences
```sql
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

-- Indexes for preferences
CREATE INDEX idx_preferences_created_at ON user_preferences (created_at);
CREATE INDEX idx_preferences_sources ON user_preferences USING GIN (sources);
```

#### user_feedback
```sql
CREATE TABLE user_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    rating feedback_rating NOT NULL,
    comments TEXT,
    attributes JSONB,
    user_id UUID,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for feedback
CREATE INDEX idx_feedback_apartment_id ON user_feedback (apartment_id);
CREATE INDEX idx_feedback_rating ON user_feedback (rating);
CREATE INDEX idx_feedback_timestamp ON user_feedback (timestamp);
CREATE INDEX idx_feedback_user_id ON user_feedback (user_id);
```

#### cache_entries
```sql
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

-- Indexes for cache
CREATE INDEX idx_cache_listing_id ON cache_entries (listing_id);
CREATE INDEX idx_cache_url ON cache_entries (url);
CREATE INDEX idx_cache_content_hash ON cache_entries (content_hash);
CREATE INDEX idx_cache_source ON cache_entries (source);
```

### Enums and Custom Types

```sql
-- Availability status enum
CREATE TYPE availability_status AS ENUM (
    'available',
    'unavailable', 
    'unknown',
    'check_failed'
);

-- Data source type enum
CREATE TYPE data_source_type AS ENUM (
    'api',
    'scraping',
    'hybrid'
);

-- Feedback rating enum
CREATE TYPE feedback_rating AS ENUM (
    'dislike',
    'neutral',
    'like',
    'love'
);
```

### Database Optimization Features

#### Indexing Strategy
- **Primary searches**: City, state, price, bedrooms, bathrooms
- **Deduplication**: Content hash and address hash indexes
- **Availability tracking**: Availability status and check timestamps
- **Source management**: Source-based filtering and URL lookups
- **Compound indexes**: Multi-column indexes for common query patterns

#### Query Optimization
- **JSONB storage**: Efficient storage and querying of semi-structured data
- **Partial indexes**: Indexes on filtered subsets for specific use cases
- **GIN indexes**: Efficient array and JSONB operations
- **Timestamp indexing**: Optimized time-based queries and filtering

#### Data Integrity
- **Foreign key constraints**: Referential integrity between tables
- **Check constraints**: Data validation at database level
- **NOT NULL constraints**: Required field enforcement
- **Unique constraints**: Prevent duplicate data entry