# Architecture & Project Structure

> **Related Documents:**
> - [Docker Orchestration](docker-orchestration.md) - Container communication and management
> - [Data Models](data-models.md) - Structure definitions and validation
> - [Technical Implementation](../technical/technical.md) - Dependencies and deployment
> - [Back to Documentation Index](../README.md)

## Project Structure

### Containerized Architecture
```
apartment-hunt/
├── cmd/
│   ├── controller/                # Primary container - orchestration
│   │   └── main.go
│   ├── scraper/                   # Scraper containers
│   │   └── main.go
│   ├── storage/                   # Storage container
│   │   └── main.go
│   └── cli/                       # CLI interface
│       └── main.go
├── internal/
│   ├── config/
│   │   ├── config.go              # Configuration management
│   │   └── config_test.go         # Configuration tests
│   ├── models/
│   │   ├── apartment.go           # Apartment listing model with availability
│   │   ├── apartment_test.go      # Apartment model tests
│   │   ├── preferences.go         # User preference model
│   │   ├── preferences_test.go    # Preferences tests
│   │   ├── feedback.go            # User feedback model
│   │   └── feedback_test.go       # Feedback tests
│   ├── controller/
│   │   ├── orchestrator.go        # Container orchestration
│   │   ├── orchestrator_test.go   # Orchestrator tests
│   │   ├── task_manager.go        # Task distribution
│   │   └── progress_tracker.go    # Progress monitoring
│   ├── storage/
│   │   ├── filesystem.go          # File-based storage implementation
│   │   ├── filesystem_test.go     # Filesystem storage tests
│   │   ├── cache.go               # Multi-source deduplication cache
│   │   ├── cache_test.go          # Cache tests
│   │   ├── interface.go           # Storage interface
│   │   ├── service.go             # Storage microservice
│   │   └── testdata/              # Test fixtures and data
│   │       ├── sample_listing.json
│   │       └── sample_cache_index.json
│   ├── scrapers/
│   │   ├── interface.go           # Scraper interface
│   │   ├── api/                   # API-first implementations
│   │   │   ├── zillow_api.go      # Zillow API client
│   │   │   ├── rentals_api.go     # Rentals.com API client
│   │   │   └── common.go          # Common API utilities
│   │   ├── web/                   # Web scraping fallbacks
│   │   │   ├── craigslist.go      # Craigslist scraper
│   │   │   ├── apartments.go      # Apartments.com scraper
│   │   │   └── common.go          # Common scraping utilities
│   │   ├── availability/
│   │   │   ├── checker.go         # Availability verification
│   │   │   └── tracker.go         # Availability tracking
│   │   ├── service.go             # Scraper microservice
│   │   ├── manager.go             # Scraper coordination
│   │   ├── manager_test.go        # Manager tests
│   │   └── testdata/              # HTML fixtures for scraper tests
│   │       ├── craigslist_sample.html
│   │       └── zillow_sample.html
│   ├── search/
│   │   ├── engine.go              # Search and filtering logic
│   │   ├── engine_test.go         # Search engine tests
│   │   ├── deduplication.go       # Multi-source deduplication
│   │   ├── refinement.go          # ML-based search refinement
│   │   └── refinement_test.go     # Refinement tests
│   ├── communication/
│   │   ├── grpc/                  # gRPC service definitions
│   │   │   ├── controller.proto   # Controller service
│   │   │   ├── scraper.proto      # Scraper service
│   │   │   └── storage.proto      # Storage service
│   │   ├── messages/              # Message types
│   │   │   ├── tasks.go           # Task messages
│   │   │   ├── progress.go        # Progress messages
│   │   │   └── commands.go        # Command messages
│   │   └── client/                # Service clients
│   │       ├── controller.go      # Controller client
│   │       ├── scraper.go         # Scraper client
│   │       └── storage.go         # Storage client
│   └── ui/
│       ├── cli.go                 # Command-line interface with hyperlinks
│       ├── cli_test.go            # CLI tests
│       ├── interactive.go         # Interactive user prompts
│       ├── hyperlink.go           # Hyperlink handling
│       └── source_selector.go     # Multi-source selection UI
├── pkg/
│   └── utils/
│       ├── http.go                # HTTP utilities
│       ├── http_test.go           # HTTP utility tests
│       ├── validation.go          # Input validation
│       ├── validation_test.go     # Validation tests
│       └── docker.go              # Docker utilities
├── deployments/
│   ├── docker/
│   │   ├── Dockerfile.controller  # Controller container
│   │   ├── Dockerfile.scraper     # Scraper container
│   │   ├── Dockerfile.storage     # Storage container
│   │   └── Dockerfile.cli         # CLI container
│   ├── docker-compose.yml         # Local development
│   ├── docker-compose.prod.yml    # Production deployment
│   └── kubernetes/                # K8s manifests (optional)
│       ├── controller.yaml
│       ├── scraper.yaml
│       └── storage.yaml
├── test/
│   ├── integration/               # Integration tests
│   │   ├── container_integration_test.go
│   │   ├── scraper_integration_test.go
│   │   └── search_integration_test.go
│   ├── fixtures/                  # Shared test fixtures
│   │   └── sample_apartments.json
│   └── helpers/                   # Test helper functions
│       └── test_helpers.go
├── data/                          # Data storage directory (volume mount)
├── docs/                          # Implementation documentation
├── go.mod
├── go.sum
├── Makefile                       # Build and test automation
└── README.md
```

## Architectural Patterns

### Microservices Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    CLI Container                            │  ← User interaction
│              (hyperlinks, source selection)                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                Controller Container                         │  ← Orchestration
│         (task management, progress tracking)               │
└─────────────────────────────────────────────────────────────┘
              │                      │                      │
              ▼                      ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Scraper        │    │  Scraper        │    │   Storage       │
│  Container      │    │  Container      │    │   Container     │
│  (Craigslist)   │    │  (Zillow API)   │    │ (Files/Cache/   │
│                 │    │                 │    │  Deduplication) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
              │                      │                      ▲
              └──────────────────────┼──────────────────────┘
                                     │
              ┌─────────────────────────────────────────────────┐
              │         Additional Scraper Containers          │
              │      (apartments.com, local managers)          │
              └─────────────────────────────────────────────────┘
```

### Container Communication Flow with Database
```
┌──────────────┐    gRPC    ┌──────────────┐    gRPC    ┌──────────────┐
│     CLI      │ ◄─────────►│ Controller   │ ◄─────────►│   Storage    │
│  Container   │            │  Container   │            │  Container   │
└──────────────┘            └──────────────┘            └──────────────┘
                                    │                            │
                                    │ gRPC (task distribution)   │ SQL
                                    ▼                            ▼
                            ┌──────────────┐            ┌──────────────┐
                            │   Scraper    │            │ PostgreSQL   │
                            │  Containers  │            │   (CNPG)     │
                            │ (dynamically │            │              │
                            │   spawned)   │            │ - Listings   │
                            └──────────────┘            │ - Preferences│
                                                        │ - Feedback   │
                                                        │ - Cache Index│
                                                        └──────────────┘
```

### API-First Data Extraction Strategy
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Source      │────▶│   API Client    │────▶│   Fallback      │
│   Detection     │     │  (Preferred)    │     │ Web Scraper     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                │                         │
                                ▼                         ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │  Structured     │     │    Parsed       │
                        │     Data        │     │   HTML Data     │
                        └─────────────────┘     └─────────────────┘
                                │                         │
                                └─────────┬───────────────┘
                                          ▼
                                ┌─────────────────┐
                                │ Data Validation │
                                │ & Normalization │
                                └─────────────────┘
                                          │
                                          ▼
                                ┌─────────────────┐
                                │ Multi-Source    │
                                │ Deduplication   │
                                └─────────────────┘
                                          │
                                          ▼
                                ┌─────────────────┐
                                │  Availability   │
                                │   Verification  │
                                └─────────────────┘
```

## Module Responsibilities

### `/cmd/apartment-hunt/`
- **Purpose**: Application entry point and CLI setup
- **Dependencies**: Cobra CLI framework, internal packages
- **Responsibilities**: 
  - Command parsing and routing
  - Global configuration loading
  - Application lifecycle management

### `/internal/config/`
- **Purpose**: Configuration management and validation
- **Responsibilities**:
  - Load configuration from files and environment
  - Validate configuration parameters
  - Provide typed configuration access

### `/internal/models/`
- **Purpose**: Core data structures and business rules
- **Responsibilities**:
  - Define apartment, preferences, and feedback models
  - Implement validation logic
  - Provide JSON/YAML serialization

### `/storage/src/storage/`
- **Purpose**: Data persistence and database operations
- **Responsibilities**:
  - Abstract storage operations via interfaces
  - Implement PostgreSQL database operations
  - Manage listing deduplication and indexing
  - Handle user data isolation and multi-tenant operations
  - Handle database migrations and schema updates
  - Optimize query performance with strategic indexing

### `/cli/src/ui/`
- **Purpose**: User interface and interaction management
- **Responsibilities**:
  - Handle user authentication and session management
  - Manage user-specific preference selection
  - Display user-scoped listing results with feedback
  - Provide user-specific hyperlinks and source selection
  - Collect and manage user feedback and ratings

### `/internal/scrapers/`
- **Purpose**: External data collection
- **Responsibilities**:
  - Define scraper interface
  - Implement source-specific scrapers
  - Coordinate multiple scrapers
  - Handle rate limiting and retries

### `/internal/search/`
- **Purpose**: Search and recommendation logic
- **Responsibilities**:
  - Filter listings by preferences
  - Rank results based on user feedback
  - Implement search refinement algorithms

### `/internal/ui/`
- **Purpose**: User interaction and presentation
- **Responsibilities**:
  - Handle interactive CLI prompts
  - Format and display listings
  - Collect user feedback
  - Manage user preferences input

### `/pkg/utils/`
- **Purpose**: Reusable utility functions
- **Responsibilities**:
  - HTTP client utilities
  - Input validation helpers
  - Common data processing functions

## Dependency Flow

### High-Level Dependencies
```
main.go
  ├── config
  ├── ui/cli
  │   ├── search/engine
  │   │   ├── storage
  │   │   └── models
  │   ├── scrapers/manager
  │   │   ├── scrapers/*
  │   │   ├── storage
  │   │   └── utils/http
  │   └── storage
  └── models
```

### Interface Boundaries
```go
// Storage abstraction
type Storage interface {
    Store(apartment *Apartment) error
    Load(id string) (*Apartment, error)
    Query(filters *SearchFilters) ([]*Apartment, error)
}

// Scraper abstraction  
type Scraper interface {
    Name() string
    Scrape(preferences *Preferences) ([]*Apartment, error)
    CanScrape(url string) bool
}

// Search abstraction
type SearchEngine interface {
    Search(preferences *Preferences) ([]*Apartment, error)
    Refine(feedback []*Feedback) (*Preferences, error)
}
```

## Design Principles

### 1. Dependency Inversion
- High-level modules don't depend on low-level modules
- Both depend on abstractions (interfaces)
- Enables easy testing and component swapping

### 2. Single Responsibility
- Each package has one clear responsibility
- Models only handle data structure and validation
- Storage only handles persistence and database operations
- Scrapers only handle data collection

### 3. Interface Segregation
- Small, focused interfaces
- Clients depend only on methods they use
- Easy to mock for testing

### 4. Open/Closed Principle
- Open for extension (new scrapers, storage backends)
- Closed for modification (existing interfaces remain stable)

### 5. Database Design Patterns
- **Repository Pattern**: Abstract database operations behind interfaces
- **Migration Versioning**: Version-controlled schema changes with rollback capability
- **Indexing Strategy**: Strategic indexes on search-critical fields
- **Connection Pooling**: Efficient database connection management
- **Query Optimization**: Structured queries optimized for common access patterns

### 6. Multi-User Architecture Patterns
- **Data Isolation**: User-specific data completely separated while sharing common listings
- **Authentication Service**: Centralized user authentication and session management
- **Authorization Middleware**: User-scoped data access controls at service layer
- **Preference Management**: Multiple preference sets per user for different scenarios
- **Privacy by Design**: User opinions and feedback never shared between users

## Configuration Management

### Configuration Sources (Priority Order)
1. Command-line flags
2. Environment variables
3. Configuration file (`config.yaml`)
4. Default values

### Configuration Structure
```go
type Config struct {
    Storage   StorageConfig   `yaml:"storage"`
    Scrapers  ScrapersConfig  `yaml:"scrapers"`
    Search    SearchConfig    `yaml:"search"`
    RateLimit RateLimitConfig `yaml:"rate_limit"`
}

type StorageConfig struct {
    DataDir    string `yaml:"data_dir" env:"APARTMENT_HUNT_DATA_DIR"`
    CacheSize  int    `yaml:"cache_size" env:"APARTMENT_HUNT_CACHE_SIZE"`
}
```

## Error Handling Strategy

### Error Types
```go
// Domain-specific errors
type ValidationError struct {
    Field   string
    Message string
}

type ScrapingError struct {
    Source string
    URL    string
    Err    error
}

type StorageError struct {
    Operation string
    Path      string
    Err       error
}
```

### Error Propagation
- Errors bubble up through layers
- Each layer adds context
- UI layer presents user-friendly messages
- All errors logged with full context