# Listings Data Model

> **Related Documents:**
> - [Data Models Index](../data-models.md) - Central data model index
> - [User Feedback](user-feedback.md) - User opinions and ratings
> - [Cache Entries](cache-entries.md) - Deduplication metadata
> - [Multi-User Requirements](../../tasking/t5.md) - Multi-user specifications
> - [Back to Documentation Index](../../README.md)

## Overview

The Listings model represents apartment listings from multiple sources. Listings are shared across all users but user-specific data (feedback, progress) is stored separately to maintain data separation and scalability.

## Data Structure

### Listing Model
```go
type Listing struct {
    ID          string    `json:"id" db:"id" validate:"required"`
    Source      string    `json:"source" db:"source" validate:"required,oneof=craigslist zillow apartments rentals"`
    SourceID    string    `json:"source_id" db:"source_id" validate:"required"`
    URL         string    `json:"url" db:"url" validate:"required,url"`
    AlternateURLs []string `json:"alternate_urls,omitempty" db:"alternate_urls" validate:"dive,url"`
    
    // Basic listing information
    Address     string    `json:"address" db:"address" validate:"required,min=5"`
    City        string    `json:"city" db:"city" validate:"required,min=2"`
    State       string    `json:"state" db:"state" validate:"required,len=2"`
    ZipCode     string    `json:"zip_code" db:"zip_code" validate:"required,len=5"`
    
    // Property details
    Price       int       `json:"price" db:"price" validate:"required,min=0"`
    Bedrooms    int       `json:"bedrooms" db:"bedrooms" validate:"required,min=0,max=10"`
    Bathrooms   float64   `json:"bathrooms" db:"bathrooms" validate:"required,min=0,max=20"`
    SquareFeet  *int      `json:"square_feet,omitempty" db:"square_feet" validate:"omitempty,min=100"`
    Description string    `json:"description" db:"description" validate:"required,min=10"`
    
    // Media and assets
    Images      []string  `json:"images,omitempty" db:"images" validate:"dive,url"`
    VirtualTour *string   `json:"virtual_tour,omitempty" db:"virtual_tour" validate:"omitempty,url"`
    FloorPlan   *string   `json:"floor_plan,omitempty" db:"floor_plan" validate:"omitempty,url"`
    
    // Timing information
    DatePosted  time.Time `json:"date_posted" db:"date_posted" validate:"required"`
    DateFound   time.Time `json:"date_found" db:"date_found" validate:"required"`
    LastSeen    time.Time `json:"last_seen" db:"last_seen" validate:"required"`
    
    // Deduplication and integrity
    ContentHash string    `json:"content_hash" db:"content_hash" validate:"required"`
    AddressHash string    `json:"address_hash" db:"address_hash" validate:"required"`
    
    // Availability tracking
    Availability      AvailabilityStatus   `json:"availability" db:"availability" validate:"required"`
    AvailabilityChecks []AvailabilityCheck `json:"availability_checks,omitempty" db:"availability_checks"`
    LastAvailableCheck time.Time           `json:"last_available_check" db:"last_available_check"`
    UnavailableSince   *time.Time          `json:"unavailable_since,omitempty" db:"unavailable_since"`
    
    // Multi-source information
    Sources        []SourceInfo `json:"sources,omitempty" db:"sources"`
    PrimarySource  string       `json:"primary_source" db:"primary_source"`
    DataSource     DataSource   `json:"data_source" db:"data_source"`
    
    // Computed fields
    PricePerSqFt *float64 `json:"price_per_sq_ft,omitempty" db:"price_per_sq_ft"`
    
    // Geographic information (computed)
    Latitude     *float64 `json:"latitude,omitempty" db:"latitude"`
    Longitude    *float64 `json:"longitude,omitempty" db:"longitude"`
    Neighborhood *string  `json:"neighborhood,omitempty" db:"neighborhood"`
    
    // Timestamps
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
    UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
    
    // User-specific data (not stored in this table, joined from other tables)
    UserFeedback []*UserFeedback `json:"user_feedback,omitempty" db:"-"`
    ViewedByUser bool            `json:"viewed_by_user,omitempty" db:"-"`
    SavedByUser  bool            `json:"saved_by_user,omitempty" db:"-"`
}
```

### Supporting Types
```go
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
```

## Database Schema

### listings table
```sql
CREATE TABLE listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(50) NOT NULL,
    source_id VARCHAR(255) NOT NULL,
    url TEXT NOT NULL,
    alternate_urls JSONB,
    
    -- Basic listing information
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    
    -- Property details
    price INTEGER NOT NULL,
    bedrooms INTEGER NOT NULL,
    bathrooms DECIMAL(3,1) NOT NULL,
    square_feet INTEGER,
    description TEXT NOT NULL,
    
    -- Media and assets
    images JSONB,
    virtual_tour TEXT,
    floor_plan TEXT,
    
    -- Timing information
    date_posted TIMESTAMP WITH TIME ZONE NOT NULL,
    date_found TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Deduplication and integrity
    content_hash VARCHAR(64) NOT NULL,
    address_hash VARCHAR(64) NOT NULL,
    
    -- Availability tracking
    availability availability_status NOT NULL DEFAULT 'unknown',
    availability_checks JSONB,
    last_available_check TIMESTAMP WITH TIME ZONE,
    unavailable_since TIMESTAMP WITH TIME ZONE,
    
    -- Multi-source information
    sources JSONB,
    primary_source VARCHAR(50),
    data_source data_source_type NOT NULL DEFAULT 'scraping',
    
    -- Computed fields
    price_per_sq_ft DECIMAL(8,2),
    
    -- Geographic information
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    neighborhood VARCHAR(100),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT listings_price_check CHECK (price >= 0),
    CONSTRAINT listings_bedrooms_check CHECK (bedrooms >= 0 AND bedrooms <= 10),
    CONSTRAINT listings_bathrooms_check CHECK (bathrooms >= 0 AND bathrooms <= 20),
    CONSTRAINT listings_sqft_check CHECK (square_feet IS NULL OR square_feet >= 100),
    CONSTRAINT listings_coordinates_check CHECK (
        (latitude IS NULL AND longitude IS NULL) OR 
        (latitude IS NOT NULL AND longitude IS NOT NULL AND 
         latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
    )
);

-- Core indexes for search performance
CREATE INDEX idx_listings_city_state ON listings (city, state);
CREATE INDEX idx_listings_price ON listings (price);
CREATE INDEX idx_listings_bedrooms ON listings (bedrooms);
CREATE INDEX idx_listings_bathrooms ON listings (bathrooms);
CREATE INDEX idx_listings_square_feet ON listings (square_feet);
CREATE INDEX idx_listings_availability ON listings (availability);
CREATE INDEX idx_listings_date_posted ON listings (date_posted);

-- Deduplication indexes
CREATE INDEX idx_listings_content_hash ON listings (content_hash);
CREATE INDEX idx_listings_address_hash ON listings (address_hash);
CREATE UNIQUE INDEX idx_listings_url_unique ON listings (url);

-- Source management indexes
CREATE INDEX idx_listings_source ON listings (source);
CREATE UNIQUE INDEX idx_listings_source_id_unique ON listings (source, source_id);

-- Compound indexes for common search patterns
CREATE INDEX idx_listings_price_bed_bath ON listings (price, bedrooms, bathrooms);
CREATE INDEX idx_listings_city_price_bed ON listings (city, price, bedrooms);
CREATE INDEX idx_listings_search_main ON listings (city, state, price, bedrooms, bathrooms, availability);

-- Geographic indexes
CREATE INDEX idx_listings_coordinates ON listings (latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX idx_listings_neighborhood ON listings (neighborhood) WHERE neighborhood IS NOT NULL;

-- Timestamp indexes for data management
CREATE INDEX idx_listings_created_at ON listings (created_at);
CREATE INDEX idx_listings_updated_at ON listings (updated_at);
CREATE INDEX idx_listings_last_seen ON listings (last_seen);

-- JSONB indexes for complex queries
CREATE INDEX idx_listings_images ON listings USING GIN (images);
CREATE INDEX idx_listings_sources ON listings USING GIN (sources);
CREATE INDEX idx_listings_availability_checks ON listings USING GIN (availability_checks);
```

## Business Logic

### Listing Creation and Updates
```go
func (l *Listing) Create() error {
    // Generate ID and hashes
    l.ID = uuid.New().String()
    l.GenerateContentHash()
    l.GenerateAddressHash()
    
    // Set timestamps
    now := time.Now()
    l.DateFound = now
    l.LastSeen = now
    l.CreatedAt = now
    l.UpdatedAt = now
    
    // Calculate derived fields
    l.CalculatePricePerSqFt()
    
    // Validate
    if err := l.Validate(); err != nil {
        return err
    }
    
    return l.Save()
}

func (l *Listing) Update(updates *Listing) error {
    // Preserve immutable fields
    updates.ID = l.ID
    updates.DateFound = l.DateFound
    updates.CreatedAt = l.CreatedAt
    
    // Update timestamps
    updates.LastSeen = time.Now()
    updates.UpdatedAt = time.Now()
    
    // Recalculate hashes and derived fields
    updates.GenerateContentHash()
    updates.CalculatePricePerSqFt()
    
    *l = *updates
    return l.Save()
}
```

### Content Hashing for Deduplication
```go
func (l *Listing) GenerateContentHash() {
    hasher := sha256.New()
    content := fmt.Sprintf("%s|%s|%d|%d|%.1f|%s", 
        l.Address, l.City, l.Price, l.Bedrooms, l.Bathrooms, 
        truncateDescription(l.Description, 100))
    hasher.Write([]byte(content))
    l.ContentHash = hex.EncodeToString(hasher.Sum(nil))
}

func (l *Listing) GenerateAddressHash() {
    normalizedAddress := normalizeAddress(l.Address, l.City, l.State, l.ZipCode)
    hasher := sha256.New()
    hasher.Write([]byte(normalizedAddress))
    l.AddressHash = hex.EncodeToString(hasher.Sum(nil))
}
```

### Availability Management
```go
func (l *Listing) UpdateAvailability(status AvailabilityStatus, method, details string) {
    check := AvailabilityCheck{
        Timestamp: time.Now(),
        Source:    l.Source,
        Status:    status,
        Method:    method,
        Details:   details,
    }
    
    l.AvailabilityChecks = append(l.AvailabilityChecks, check)
    l.Availability = status
    l.LastAvailableCheck = check.Timestamp
    
    if status == Unavailable && l.UnavailableSince == nil {
        l.UnavailableSince = &check.Timestamp
    } else if status == Available {
        l.UnavailableSince = nil
    }
    
    l.UpdatedAt = time.Now()
}
```

### Multi-Source Management
```go
func (l *Listing) AddSource(source, sourceID, url string, dataQuality float64) {
    // Check if source already exists
    for i, existing := range l.Sources {
        if existing.Source == source {
            l.Sources[i].LastSeen = time.Now()
            l.Sources[i].IsActive = true
            l.Sources[i].DataQuality = dataQuality
            return
        }
    }
    
    // Add new source
    sourceInfo := SourceInfo{
        Source:      source,
        SourceID:    sourceID,
        URL:         url,
        FirstSeen:   time.Now(),
        LastSeen:    time.Now(),
        DataQuality: dataQuality,
        IsActive:    true,
    }
    
    l.Sources = append(l.Sources, sourceInfo)
    
    // Update primary source if this has better data quality
    if l.PrimarySource == "" || dataQuality > l.GetPrimarySourceQuality() {
        l.PrimarySource = source
    }
}
```

## Multi-User Considerations

### Data Separation Strategy
```go
// Listings are shared across users - user-specific data is in separate tables
type ListingWithUserData struct {
    *Listing
    UserFeedback []*UserFeedback `json:"user_feedback,omitempty"`
    ViewedAt     *time.Time      `json:"viewed_at,omitempty"`
    SavedAt      *time.Time      `json:"saved_at,omitempty"`
    HiddenAt     *time.Time      `json:"hidden_at,omitempty"`
}

// Service layer handles user-specific data joining
func (s *ListingService) GetListingForUser(listingID, userID string) (*ListingWithUserData, error) {
    listing, err := s.repo.GetListing(listingID)
    if err != nil {
        return nil, err
    }
    
    userFeedback, _ := s.feedbackRepo.GetUserFeedbackForListing(userID, listingID)
    viewedAt, _ := s.userActivityRepo.GetLastViewedTime(userID, listingID)
    savedAt, _ := s.userActivityRepo.GetSavedTime(userID, listingID)
    hiddenAt, _ := s.userActivityRepo.GetHiddenTime(userID, listingID)
    
    return &ListingWithUserData{
        Listing:      listing,
        UserFeedback: userFeedback,
        ViewedAt:     viewedAt,
        SavedAt:      savedAt,
        HiddenAt:     hiddenAt,
    }, nil
}
```

### User Activity Tracking
```sql
-- Separate table for user-specific listing interactions
CREATE TABLE user_listing_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    activity_type VARCHAR(20) NOT NULL, -- 'viewed', 'saved', 'hidden', 'contacted'
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    metadata JSONB,
    
    UNIQUE(user_id, listing_id, activity_type)
);

CREATE INDEX idx_user_activity_user_listing ON user_listing_activity (user_id, listing_id);
CREATE INDEX idx_user_activity_type ON user_listing_activity (activity_type, timestamp);
```

## Search and Filtering

### Geographic Search
```go
func (s *ListingService) SearchByRadius(lat, lng float64, radiusMiles int) ([]*Listing, error) {
    // Use PostGIS for geographic queries
    query := `
        SELECT * FROM listings 
        WHERE latitude IS NOT NULL 
        AND longitude IS NOT NULL
        AND ST_DWithin(
            ST_Point(longitude, latitude)::geography,
            ST_Point($1, $2)::geography,
            $3 * 1609.34  -- Convert miles to meters
        )
        ORDER BY ST_Distance(
            ST_Point(longitude, latitude)::geography,
            ST_Point($1, $2)::geography
        )
    `
    return s.repo.Query(query, lng, lat, radiusMiles)
}
```

### Advanced Filtering
```go
func (s *ListingService) SearchWithFilters(filters *SearchFilters, userID string) ([]*Listing, error) {
    query := s.buildSearchQuery(filters)
    listings, err := s.repo.Query(query, filters.ToParams()...)
    if err != nil {
        return nil, err
    }
    
    // Filter out hidden listings for this user
    if userID != "" {
        listings = s.filterHiddenListings(listings, userID)
    }
    
    return listings, nil
}
```

## API Operations

### Core Operations
- `CreateListing(listing)` - Add new listing
- `GetListing(id)` - Retrieve listing by ID
- `UpdateListing(id, updates)` - Modify listing
- `DeleteListing(id)` - Remove listing
- `CheckAvailability(id)` - Verify listing availability
- `AddAlternateURL(id, url)` - Add additional source URL

### Search Operations
- `SearchListings(filters)` - Filter listings by criteria
- `SearchByLocation(lat, lng, radius)` - Geographic search
- `GetSimilarListings(id, limit)` - Find similar properties
- `GetListingsForUser(userID, filters)` - User-specific search with activity data

### Deduplication Operations
- `FindDuplicatesByContent(contentHash)` - Find content duplicates
- `FindDuplicatesByAddress(addressHash)` - Find address duplicates
- `MergeListings(primaryID, duplicateIDs)` - Combine duplicate listings

### Analytics Operations
- `GetPopularNeighborhoods()` - Most searched neighborhoods
- `GetPriceTrends(city, timeframe)` - Price trend analysis
- `GetListingStats()` - Overall listing statistics