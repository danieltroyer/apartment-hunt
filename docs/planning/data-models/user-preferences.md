# User Preferences Data Model

> **Related Documents:**
> - [Data Models Index](../data-models.md) - Central data model index
> - [Users](users.md) - User accounts and authentication
> - [Listings](listings.md) - Apartment listing data
> - [Multi-User Requirements](../../tasking/t5.md) - Multi-user specifications
> - [Back to Documentation Index](../../README.md)

## Overview

The User Preferences model manages individual user search criteria and filtering preferences. Each user can have multiple preference sets for different search scenarios (e.g., "Work Location", "Family Home", "Investment Property").

## Data Structure

### User Preferences Model
```go
type UserPreferences struct {
    ID          string    `json:"id" db:"id" validate:"required"`
    UserID      string    `json:"user_id" db:"user_id" validate:"required"`
    Name        string    `json:"name" db:"name" validate:"required,min=1,max=100"`
    Description string    `json:"description,omitempty" db:"description" validate:"omitempty,max=500"`
    IsDefault   bool      `json:"is_default" db:"is_default"`
    IsActive    bool      `json:"is_active" db:"is_active"`
    
    // Geographic preferences
    Geography   Geography `json:"geography" db:"geography" validate:"required"`
    
    // Price and size constraints
    PriceRange  Range     `json:"price_range" db:"price_range" validate:"required"`
    Bedrooms    Range     `json:"bedrooms" db:"bedrooms" validate:"required"`
    Bathrooms   *Range    `json:"bathrooms,omitempty" db:"bathrooms"`
    MinSqFt     *int      `json:"min_sq_ft,omitempty" db:"min_sq_ft" validate:"omitempty,min=100"`
    MaxSqFt     *int      `json:"max_sq_ft,omitempty" db:"max_sq_ft" validate:"omitempty,min=100"`
    
    // Search criteria
    Keywords    []string  `json:"keywords,omitempty" db:"keywords" validate:"dive,min=2"`
    Exclusions  []string  `json:"exclusions,omitempty" db:"exclusions" validate:"dive,min=2"`
    Sources     []string  `json:"sources" db:"sources" validate:"required,dive,oneof=craigslist zillow apartments"`
    
    // Notification preferences
    EmailAlerts      bool   `json:"email_alerts" db:"email_alerts"`
    AlertFrequency   string `json:"alert_frequency,omitempty" db:"alert_frequency" validate:"omitempty,oneof=immediate hourly daily weekly"`
    MaxResultsPerDay *int   `json:"max_results_per_day,omitempty" db:"max_results_per_day" validate:"omitempty,min=1,max=100"`
    
    // Timestamps
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
    UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
    LastUsedAt  *time.Time `json:"last_used_at,omitempty" db:"last_used_at"`
    
    // Soft delete
    DeletedAt   *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`
}
```

### Geography Model
```go
type Geography struct {
    Cities      []string `json:"cities" validate:"required,min=1,dive,min=2"`
    ZipCodes    []string `json:"zip_codes,omitempty" validate:"dive,len=5"`
    MaxDistance *int     `json:"max_distance,omitempty" validate:"omitempty,min=1,max=100"` // miles from center
    CenterLat   *float64 `json:"center_lat,omitempty" validate:"omitempty,latitude"`
    CenterLng   *float64 `json:"center_lng,omitempty" validate:"omitempty,longitude"`
    Regions     []string `json:"regions,omitempty"` // e.g., "Downtown", "Suburbs", "University District"
}
```

### Range Model
```go
type Range struct {
    Min int `json:"min" validate:"min=0"`
    Max int `json:"max" validate:"gtefield=Min"`
}
```

## Database Schema

### user_preferences table
```sql
CREATE TABLE user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_default BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Geographic preferences (stored as JSONB)
    geography JSONB NOT NULL,
    
    -- Price and size constraints (stored as JSONB for flexibility)
    price_range JSONB NOT NULL,
    bedrooms JSONB NOT NULL,
    bathrooms JSONB,
    min_sq_ft INTEGER,
    max_sq_ft INTEGER,
    
    -- Search criteria
    keywords TEXT[],
    exclusions TEXT[],
    sources TEXT[] NOT NULL,
    
    -- Notification preferences
    email_alerts BOOLEAN NOT NULL DEFAULT false,
    alert_frequency VARCHAR(20),
    max_results_per_day INTEGER,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT user_preferences_name_check CHECK (char_length(name) >= 1),
    CONSTRAINT user_preferences_sqft_check CHECK (max_sq_ft IS NULL OR min_sq_ft IS NULL OR max_sq_ft >= min_sq_ft),
    CONSTRAINT user_preferences_alert_freq_check CHECK (
        alert_frequency IN ('immediate', 'hourly', 'daily', 'weekly') OR alert_frequency IS NULL
    ),
    CONSTRAINT user_preferences_max_results_check CHECK (
        max_results_per_day IS NULL OR (max_results_per_day >= 1 AND max_results_per_day <= 100)
    )
);

-- Indexes
CREATE INDEX idx_user_preferences_user_id ON user_preferences (user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_preferences_default ON user_preferences (user_id, is_default) WHERE deleted_at IS NULL AND is_default = true;
CREATE INDEX idx_user_preferences_active ON user_preferences (user_id, is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_preferences_last_used ON user_preferences (last_used_at);
CREATE INDEX idx_user_preferences_sources ON user_preferences USING GIN (sources);
CREATE INDEX idx_user_preferences_keywords ON user_preferences USING GIN (keywords);
CREATE INDEX idx_user_preferences_geography ON user_preferences USING GIN (geography);

-- Ensure only one default preference per user
CREATE UNIQUE INDEX idx_user_preferences_unique_default 
ON user_preferences (user_id) 
WHERE is_default = true AND deleted_at IS NULL;
```

## Validation Rules

### Geographic Validation
```go
func (g *Geography) Validate() error {
    if len(g.Cities) == 0 && len(g.ZipCodes) == 0 && g.CenterLat == nil {
        return errors.New("at least one geographic constraint must be specified")
    }
    
    if (g.CenterLat != nil || g.CenterLng != nil) && g.MaxDistance == nil {
        return errors.New("max_distance required when using center coordinates")
    }
    
    if g.CenterLat != nil && (*g.CenterLat < -90 || *g.CenterLat > 90) {
        return errors.New("latitude must be between -90 and 90")
    }
    
    if g.CenterLng != nil && (*g.CenterLng < -180 || *g.CenterLng > 180) {
        return errors.New("longitude must be between -180 and 180")
    }
    
    return nil
}
```

### Range Validation
```go
func (r *Range) Validate() error {
    if r.Min < 0 {
        return errors.New("minimum value cannot be negative")
    }
    
    if r.Max < r.Min {
        return errors.New("maximum value must be greater than or equal to minimum value")
    }
    
    return nil
}
```

## Business Logic

### Preference Management
```go
func (up *UserPreferences) SetAsDefault() error {
    // Ensure only one default preference per user
    if err := up.repo.ClearDefaultForUser(up.UserID); err != nil {
        return err
    }
    
    up.IsDefault = true
    up.UpdatedAt = time.Now()
    
    return up.Save()
}

func (up *UserPreferences) UpdateLastUsed() error {
    now := time.Now()
    up.LastUsedAt = &now
    up.UpdatedAt = now
    
    return up.SaveTimestamps()
}
```

### Matching Logic
```go
func (up *UserPreferences) MatchesListing(listing *Listing) bool {
    // Price range check
    if listing.Price < up.PriceRange.Min || listing.Price > up.PriceRange.Max {
        return false
    }
    
    // Bedroom range check
    if listing.Bedrooms < up.Bedrooms.Min || listing.Bedrooms > up.Bedrooms.Max {
        return false
    }
    
    // Bathroom range check (if specified)
    if up.Bathrooms != nil {
        if float64(up.Bathrooms.Min) > listing.Bathrooms || 
           float64(up.Bathrooms.Max) < listing.Bathrooms {
            return false
        }
    }
    
    // Square footage check
    if up.MinSqFt != nil && listing.SquareFeet > 0 && listing.SquareFeet < *up.MinSqFt {
        return false
    }
    if up.MaxSqFt != nil && listing.SquareFeet > 0 && listing.SquareFeet > *up.MaxSqFt {
        return false
    }
    
    // Geography check
    if !up.Geography.Contains(listing) {
        return false
    }
    
    // Keywords and exclusions check
    return up.matchesKeywords(listing) && !up.containsExclusions(listing)
}
```

### Geographic Matching
```go
func (g *Geography) Contains(listing *Listing) bool {
    // City check
    for _, city := range g.Cities {
        if strings.EqualFold(city, listing.City) {
            return true
        }
    }
    
    // Zip code check
    for _, zip := range g.ZipCodes {
        if zip == listing.ZipCode {
            return true
        }
    }
    
    // Distance check (if center coordinates provided)
    if g.CenterLat != nil && g.CenterLng != nil && g.MaxDistance != nil {
        listingLat, listingLng, err := geocode(listing.Address)
        if err == nil {
            distance := calculateDistance(*g.CenterLat, *g.CenterLng, listingLat, listingLng)
            return distance <= float64(*g.MaxDistance)
        }
    }
    
    // If no geographic constraints specified, match all
    return len(g.Cities) == 0 && len(g.ZipCodes) == 0 && g.CenterLat == nil
}
```

## Multi-User Features

### User Isolation
```go
// All preference operations are scoped to user
type PreferenceService struct {
    repo UserPreferencesRepository
}

func (s *PreferenceService) GetUserPreferences(userID string) ([]*UserPreferences, error) {
    return s.repo.FindByUserID(userID)
}

func (s *PreferenceService) CreatePreference(userID string, pref *UserPreferences) error {
    pref.UserID = userID
    return pref.Create()
}
```

### Default Preference Management
```go
func (s *PreferenceService) GetDefaultPreference(userID string) (*UserPreferences, error) {
    prefs, err := s.repo.FindDefaultByUserID(userID)
    if err != nil {
        return nil, err
    }
    
    if prefs == nil {
        // Create default preference if none exists
        return s.CreateDefaultPreference(userID)
    }
    
    return prefs, nil
}
```

### Preference Templates
```go
// Common preference templates for new users
var DefaultTemplates = map[string]*UserPreferences{
    "first_apartment": {
        Name: "First Apartment",
        Description: "Starter apartment with basic requirements",
        PriceRange: Range{Min: 800, Max: 1500},
        Bedrooms: Range{Min: 1, Max: 2},
        Sources: []string{"craigslist", "apartments"},
    },
    "family_home": {
        Name: "Family Home",
        Description: "Family-friendly housing with more space",
        PriceRange: Range{Min: 1500, Max: 3000},
        Bedrooms: Range{Min: 2, Max: 4},
        Bathrooms: &Range{Min: 1, Max: 3},
        MinSqFt: intPtr(800),
        Sources: []string{"zillow", "apartments"},
    },
}
```

## API Operations

### Core Operations
- `CreatePreference(userID, preference)` - Create new preference set
- `GetUserPreferences(userID)` - List all user's preferences
- `GetPreference(userID, preferenceID)` - Get specific preference
- `UpdatePreference(userID, preferenceID, updates)` - Modify preference
- `DeletePreference(userID, preferenceID)` - Remove preference
- `SetDefaultPreference(userID, preferenceID)` - Set as default
- `DuplicatePreference(userID, preferenceID, newName)` - Copy existing preference

### Search Operations
- `MatchListings(userID, preferenceID, listings)` - Filter listings by preferences
- `GetMatchingListings(userID, preferenceID)` - Get all matching listings
- `TestPreference(userID, preference, listings)` - Preview matches without saving

### Analytics Operations
- `GetPreferenceUsageStats(userID)` - Usage statistics for user's preferences
- `GetPopularFilters()` - Most common filter combinations across users