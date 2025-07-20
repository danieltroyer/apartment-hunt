# User Feedback Data Model

> **Related Documents:**
> - [Data Models Index](../data-models.md) - Central data model index
> - [Users](users.md) - User accounts and authentication
> - [Listings](listings.md) - Apartment listing data
> - [User Preferences](user-preferences.md) - Search criteria
> - [Multi-User Requirements](../../tasking/t5.md) - Multi-user specifications
> - [Back to Documentation Index](../../README.md)

## Overview

The User Feedback model manages user opinions, ratings, and comments on apartment listings. This data is completely separated from the listing data itself, allowing multiple users to provide independent feedback on the same listing while maintaining data isolation and privacy.

## Data Structure

### User Feedback Model
```go
type UserFeedback struct {
    ID          string                 `json:"id" db:"id" validate:"required"`
    UserID      string                 `json:"user_id" db:"user_id" validate:"required"`
    ListingID   string                 `json:"listing_id" db:"listing_id" validate:"required"`
    
    // Rating and opinion
    Rating      FeedbackRating         `json:"rating" db:"rating" validate:"required,oneof=dislike neutral like love"`
    Comments    string                 `json:"comments,omitempty" db:"comments" validate:"omitempty,max=2000"`
    
    // Detailed attribute ratings (1-5 scale)
    Attributes  map[string]int         `json:"attributes,omitempty" db:"attributes" validate:"dive,min=1,max=5"`
    
    // Contextual information
    VisitDate   *time.Time            `json:"visit_date,omitempty" db:"visit_date"`
    VisitType   *string               `json:"visit_type,omitempty" db:"visit_type" validate:"omitempty,oneof=virtual in_person phone"`
    Source      string                `json:"source" db:"source" validate:"required"` // How they found the listing
    
    // Application/contact tracking
    ContactedLandlord bool              `json:"contacted_landlord" db:"contacted_landlord"`
    ContactDate      *time.Time        `json:"contact_date,omitempty" db:"contact_date"`
    AppliedToListing bool              `json:"applied_to_listing" db:"applied_to_listing"`
    ApplicationDate  *time.Time        `json:"application_date,omitempty" db:"application_date"`
    ApplicationStatus *string          `json:"application_status,omitempty" db:"application_status" validate:"omitempty,oneof=pending approved rejected withdrawn"`
    
    // Follow-up and notes
    FollowUpNeeded   bool              `json:"follow_up_needed" db:"follow_up_needed"`
    FollowUpDate     *time.Time        `json:"follow_up_date,omitempty" db:"follow_up_date"`
    PrivateNotes     string            `json:"private_notes,omitempty" db:"private_notes" validate:"omitempty,max=1000"`
    
    // Sharing and recommendations
    SharedWithOthers bool              `json:"shared_with_others" db:"shared_with_others"`
    WouldRecommend   *bool             `json:"would_recommend,omitempty" db:"would_recommend"`
    
    // Timestamps
    Timestamp   time.Time             `json:"timestamp" db:"timestamp" validate:"required"`
    CreatedAt   time.Time             `json:"created_at" db:"created_at"`
    UpdatedAt   time.Time             `json:"updated_at" db:"updated_at"`
    
    // Soft delete
    DeletedAt   *time.Time            `json:"deleted_at,omitempty" db:"deleted_at"`
}
```

### Feedback Rating Enum
```go
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

func (f FeedbackRating) IsPositive() bool {
    return f >= Like
}

func (f FeedbackRating) IsNegative() bool {
    return f == Dislike
}
```

### Feedback Summary for Analytics
```go
type FeedbackSummary struct {
    ListingID       string             `json:"listing_id"`
    TotalFeedback   int                `json:"total_feedback"`
    PositiveCount   int                `json:"positive_count"`
    NegativeCount   int                `json:"negative_count"`
    NeutralCount    int                `json:"neutral_count"`
    AverageRating   float64            `json:"average_rating"`
    AttributeScores map[string]float64 `json:"attribute_scores"`
    LastUpdated     time.Time          `json:"last_updated"`
    
    // User-specific aggregate (when queried for a specific user)
    UserHasFeedback bool               `json:"user_has_feedback,omitempty"`
    UserRating      *FeedbackRating    `json:"user_rating,omitempty"`
}
```

## Database Schema

### user_feedback table
```sql
CREATE TABLE user_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    
    -- Rating and opinion
    rating feedback_rating NOT NULL,
    comments TEXT,
    
    -- Detailed attribute ratings (stored as JSONB)
    attributes JSONB,
    
    -- Contextual information
    visit_date TIMESTAMP WITH TIME ZONE,
    visit_type VARCHAR(20),
    source VARCHAR(50) NOT NULL,
    
    -- Application/contact tracking
    contacted_landlord BOOLEAN NOT NULL DEFAULT false,
    contact_date TIMESTAMP WITH TIME ZONE,
    applied_to_listing BOOLEAN NOT NULL DEFAULT false,
    application_date TIMESTAMP WITH TIME ZONE,
    application_status VARCHAR(20),
    
    -- Follow-up and notes
    follow_up_needed BOOLEAN NOT NULL DEFAULT false,
    follow_up_date TIMESTAMP WITH TIME ZONE,
    private_notes TEXT,
    
    -- Sharing and recommendations
    shared_with_others BOOLEAN NOT NULL DEFAULT false,
    would_recommend BOOLEAN,
    
    -- Timestamps
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT user_feedback_comments_check CHECK (char_length(comments) <= 2000),
    CONSTRAINT user_feedback_private_notes_check CHECK (char_length(private_notes) <= 1000),
    CONSTRAINT user_feedback_visit_type_check CHECK (
        visit_type IN ('virtual', 'in_person', 'phone') OR visit_type IS NULL
    ),
    CONSTRAINT user_feedback_application_status_check CHECK (
        application_status IN ('pending', 'approved', 'rejected', 'withdrawn') OR application_status IS NULL
    ),
    CONSTRAINT user_feedback_contact_date_check CHECK (
        contact_date IS NULL OR contacted_landlord = true
    ),
    CONSTRAINT user_feedback_application_date_check CHECK (
        application_date IS NULL OR applied_to_listing = true
    )
);

-- Unique constraint: one feedback per user per listing
CREATE UNIQUE INDEX idx_user_feedback_unique 
ON user_feedback (user_id, listing_id) 
WHERE deleted_at IS NULL;

-- Core indexes for querying
CREATE INDEX idx_user_feedback_user_id ON user_feedback (user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_feedback_listing_id ON user_feedback (listing_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_feedback_rating ON user_feedback (rating, timestamp);
CREATE INDEX idx_user_feedback_timestamp ON user_feedback (timestamp);

-- Application tracking indexes
CREATE INDEX idx_user_feedback_contacted ON user_feedback (contacted_landlord, contact_date);
CREATE INDEX idx_user_feedback_applied ON user_feedback (applied_to_listing, application_date);
CREATE INDEX idx_user_feedback_follow_up ON user_feedback (follow_up_needed, follow_up_date) 
WHERE follow_up_needed = true AND deleted_at IS NULL;

-- Analytics indexes
CREATE INDEX idx_user_feedback_source ON user_feedback (source);
CREATE INDEX idx_user_feedback_would_recommend ON user_feedback (would_recommend) 
WHERE would_recommend IS NOT NULL;

-- JSONB index for attribute ratings
CREATE INDEX idx_user_feedback_attributes ON user_feedback USING GIN (attributes);
```

## Validation Rules

### Feedback Validation
```go
func (uf *UserFeedback) Validate() error {
    validate := validator.New()
    
    if err := validate.Struct(uf); err != nil {
        return err
    }
    
    // Custom validation for attributes
    if uf.Attributes != nil {
        for attr, score := range uf.Attributes {
            if score < 1 || score > 5 {
                return fmt.Errorf("attribute %s score must be between 1 and 5", attr)
            }
        }
    }
    
    // Validate date consistency
    if uf.ContactDate != nil && !uf.ContactedLandlord {
        return errors.New("contact_date requires contacted_landlord to be true")
    }
    
    if uf.ApplicationDate != nil && !uf.AppliedToListing {
        return errors.New("application_date requires applied_to_listing to be true")
    }
    
    // Visit date shouldn't be in the future
    if uf.VisitDate != nil && uf.VisitDate.After(time.Now()) {
        return errors.New("visit_date cannot be in the future")
    }
    
    return nil
}
```

## Business Logic

### Feedback Management
```go
func (uf *UserFeedback) Create() error {
    // Check for existing feedback
    existing, err := uf.repo.FindByUserAndListing(uf.UserID, uf.ListingID)
    if err != nil && err != ErrNotFound {
        return err
    }
    if existing != nil {
        return ErrFeedbackExists
    }
    
    // Set timestamps
    now := time.Now()
    uf.ID = uuid.New().String()
    uf.Timestamp = now
    uf.CreatedAt = now
    uf.UpdatedAt = now
    
    // Validate
    if err := uf.Validate(); err != nil {
        return err
    }
    
    return uf.Save()
}

func (uf *UserFeedback) Update(updates *UserFeedback) error {
    // Preserve immutable fields
    updates.ID = uf.ID
    updates.UserID = uf.UserID
    updates.ListingID = uf.ListingID
    updates.CreatedAt = uf.CreatedAt
    
    // Update timestamp
    updates.UpdatedAt = time.Now()
    
    // Validate updates
    if err := updates.Validate(); err != nil {
        return err
    }
    
    *uf = *updates
    return uf.Save()
}
```

### Attribute Rating Management
```go
func (uf *UserFeedback) SetAttributeRating(attribute string, rating int) error {
    if rating < 1 || rating > 5 {
        return errors.New("rating must be between 1 and 5")
    }
    
    if uf.Attributes == nil {
        uf.Attributes = make(map[string]int)
    }
    
    uf.Attributes[attribute] = rating
    uf.UpdatedAt = time.Now()
    
    return uf.Save()
}

func (uf *UserFeedback) GetAttributeRating(attribute string) (int, bool) {
    if uf.Attributes == nil {
        return 0, false
    }
    
    rating, exists := uf.Attributes[attribute]
    return rating, exists
}

// Common attributes for apartment feedback
var CommonAttributes = []string{
    "location",
    "value_for_money", 
    "condition",
    "neighborhood_safety",
    "noise_level",
    "natural_light",
    "space_layout",
    "landlord_responsiveness",
    "amenities",
    "parking",
    "public_transportation",
    "walkability",
}
```

### Application Tracking
```go
func (uf *UserFeedback) MarkContacted() error {
    uf.ContactedLandlord = true
    now := time.Now()
    uf.ContactDate = &now
    uf.UpdatedAt = now
    
    return uf.Save()
}

func (uf *UserFeedback) MarkApplied(status string) error {
    uf.AppliedToListing = true
    now := time.Now()
    uf.ApplicationDate = &now
    uf.ApplicationStatus = &status
    uf.UpdatedAt = now
    
    return uf.Save()
}

func (uf *UserFeedback) SetFollowUp(date time.Time, notes string) error {
    uf.FollowUpNeeded = true
    uf.FollowUpDate = &date
    if notes != "" {
        uf.PrivateNotes = notes
    }
    uf.UpdatedAt = time.Now()
    
    return uf.Save()
}
```

## Multi-User Features

### User Isolation
```go
// All feedback operations are scoped to user
type FeedbackService struct {
    repo FeedbackRepository
}

func (s *FeedbackService) GetUserFeedback(userID string) ([]*UserFeedback, error) {
    return s.repo.FindByUserID(userID)
}

func (s *FeedbackService) GetUserFeedbackForListing(userID, listingID string) (*UserFeedback, error) {
    return s.repo.FindByUserAndListing(userID, listingID)
}

func (s *FeedbackService) CreateFeedback(userID string, feedback *UserFeedback) error {
    feedback.UserID = userID
    return feedback.Create()
}
```

### Privacy and Data Separation
```go
// User feedback is completely private - users cannot see other users' feedback
func (s *FeedbackService) GetListingFeedbackSummary(listingID string) (*FeedbackSummary, error) {
    // Returns only aggregate statistics, no individual feedback
    return s.repo.GetFeedbackSummary(listingID)
}

// For specific user, include their own feedback in the summary
func (s *FeedbackService) GetListingFeedbackForUser(listingID, userID string) (*FeedbackSummary, error) {
    summary, err := s.repo.GetFeedbackSummary(listingID)
    if err != nil {
        return nil, err
    }
    
    userFeedback, err := s.repo.FindByUserAndListing(userID, listingID)
    if err == nil && userFeedback != nil {
        summary.UserHasFeedback = true
        summary.UserRating = &userFeedback.Rating
    }
    
    return summary, nil
}
```

### Analytics and Aggregation
```go
func (s *FeedbackService) GetUserFeedbackStats(userID string) (*UserFeedbackStats, error) {
    return &UserFeedbackStats{
        TotalFeedback:     s.repo.CountByUser(userID),
        ApplicationCount:  s.repo.CountApplicationsByUser(userID),
        ContactCount:     s.repo.CountContactsByUser(userID),
        PositiveFeedback: s.repo.CountPositiveByUser(userID),
        AverageRating:    s.repo.GetAverageRatingByUser(userID),
        TopAttributes:    s.repo.GetTopAttributesByUser(userID),
    }
}
```

## Search and Filtering

### Feedback-Based Search
```go
// Find listings user has given positive feedback to
func (s *FeedbackService) GetFavoriteLisings(userID string) ([]*Listing, error) {
    feedbacks, err := s.repo.FindPositiveFeedbackByUser(userID)
    if err != nil {
        return nil, err
    }
    
    var listingIDs []string
    for _, feedback := range feedbacks {
        listingIDs = append(listingIDs, feedback.ListingID)
    }
    
    return s.listingRepo.FindByIDs(listingIDs)
}

// Find listings that need follow-up
func (s *FeedbackService) GetFollowUpListings(userID string) ([]*UserFeedback, error) {
    return s.repo.FindFollowUpNeeded(userID)
}

// Find listings user applied to
func (s *FeedbackService) GetApplicationHistory(userID string) ([]*UserFeedback, error) {
    return s.repo.FindApplicationsByUser(userID)
}
```

## API Operations

### Core Operations
- `CreateFeedback(userID, listingID, feedback)` - Add user feedback
- `GetUserFeedback(userID, listingID)` - Get user's feedback for listing
- `UpdateFeedback(userID, feedbackID, updates)` - Modify feedback
- `DeleteFeedback(userID, feedbackID)` - Remove feedback
- `GetUserFeedbackList(userID)` - List all user's feedback

### Interaction Tracking
- `MarkListingContacted(userID, listingID)` - Track contact attempt
- `MarkListingApplied(userID, listingID, status)` - Track application
- `SetFollowUpReminder(userID, listingID, date)` - Set follow-up reminder
- `GetFollowUpReminders(userID)` - Get pending follow-ups

### Analytics Operations
- `GetFeedbackSummary(listingID)` - Aggregate feedback for listing
- `GetUserFeedbackStats(userID)` - User's feedback statistics
- `GetFavoriteListings(userID)` - User's positively rated listings
- `GetApplicationHistory(userID)` - User's application history

### Recommendation Operations
- `GetSimilarPreferencesUsers(userID)` - Find users with similar taste (anonymized)
- `GetRecommendedListings(userID)` - ML-based recommendations
- `GetPopularListings(userID)` - Generally well-rated listings