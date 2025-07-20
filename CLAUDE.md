# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Go-based apartment hunting application that aggregates listings from multiple sources, manages user preferences, and provides intelligent search refinement based on user feedback. The project follows strict test-driven development (TDD) methodology and implements comprehensive caching to minimize external requests.

## Architecture

### Technology Stack
- **Language**: Go 1.21+
- **CLI Framework**: Cobra
- **Testing**: Testify, Mockery, Gock
- **HTTP Client**: Resty
- **HTML Parsing**: GoQuery
- **Storage**: File-based (JSON + Markdown)
- **Caching**: Multi-level with deduplication

### Project Structure
```
apartment-hunt/
├── IMPLEMENTATION_PLAN.md          # Main implementation index
├── docs/                          # Detailed specifications
│   ├── architecture.md            # System design and structure
│   ├── data-models.md             # Data structures and validation
│   ├── caching.md                 # Deduplication and storage strategy
│   ├── tdd.md                     # Testing methodology
│   ├── phase1-core.md             # Implementation phases
│   ├── technical.md               # Dependencies and considerations
│   └── commands.md                # Development workflow
├── cmd/apartment-hunt/            # Application entry point
├── internal/                      # Private application code
│   ├── config/                    # Configuration management
│   ├── models/                    # Data models and validation
│   ├── storage/                   # File-based storage and caching
│   ├── scrapers/                  # Web scraping implementations
│   ├── search/                    # Search and filtering logic
│   └── ui/                        # CLI interface
├── pkg/utils/                     # Reusable utilities
├── test/                          # Integration tests and helpers
└── data/                          # Data storage directory
```

## Key Implementation Principles

### 1. Test-Driven Development (TDD)
- **Red-Green-Refactor**: Write failing tests first, implement minimal code, then refactor
- **Test Organization**: Unit tests co-located with source, integration tests separate
- **Coverage Target**: 90%+ for core functionality
- **Test Categories**: Unit (fast), Integration (medium), E2E (slow)

### 2. Cache-First Architecture
- **Single Fetch Rule**: Each listing retrieved only once unless explicitly refreshed
- **Multi-Level Deduplication**: URL-based, content hash, and address normalization
- **User-Controlled Refresh**: `--refresh` flags for cache bypass
- **Intelligent Caching**: Content change detection and staleness tracking

### 3. Respectful Web Scraping
- **Rate Limiting**: Per-source request limits with exponential backoff
- **Robots.txt Compliance**: Automatic checking and adherence
- **Circuit Breakers**: Automatic source disabling on repeated failures
- **Minimal Requests**: Aggressive caching to reduce external load

## Development Workflow

### Daily Development Commands
```bash
# Start TDD cycle
make tdd

# Run all tests
make test

# Run with coverage
make test-coverage

# Build application
make build

# Run application
./bin/apartment-hunt search
```

### Application Commands
```bash
# Normal search (uses cache)
apartment-hunt search

# Force refresh from sources
apartment-hunt search --refresh

# Cache management
apartment-hunt cache stats
apartment-hunt cache clear --source craigslist

# Preferences management
apartment-hunt preferences set
apartment-hunt preferences show
```

## Data Models

### Core Entities
- **Apartment**: Listing data with validation and content hashing
- **Preferences**: User search criteria with geographic and price filters
- **Feedback**: User ratings and comments for search refinement
- **CacheEntry**: Metadata for deduplication and staleness tracking

### Storage Strategy
- **File Structure**: Date-based directories (`data/2024-01-15/listing-id.md`)
- **Formats**: JSON for structured data, Markdown for human-readable listings
- **Cache Index**: Master index for fast lookups and deduplication
- **Validation**: Comprehensive input validation with Go validator package

## Important File References

### Core Implementation Guides
- **[IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)**: Main implementation index and overview
- **[docs/architecture.md](docs/architecture.md)**: Detailed system design and component relationships
- **[docs/data-models.md](docs/data-models.md)**: Complete data structure specifications
- **[docs/caching.md](docs/caching.md)**: Deduplication and cache management details
- **[docs/tdd.md](docs/tdd.md)**: Testing methodology and automation

### Phase Implementation
- **[docs/phase1-core.md](docs/phase1-core.md)**: Week 1 - Core infrastructure setup
- **[docs/phase2-scraping.md](docs/phase2-scraping.md)**: Week 2 - Web scraping framework  
- **[docs/phase3-search.md](docs/phase3-search.md)**: Week 3 - Search engine and UI
- **[docs/phase4-intelligence.md](docs/phase4-intelligence.md)**: Week 4 - ML and refinement

### Development Resources
- **[docs/commands.md](docs/commands.md)**: Complete development command reference
- **[docs/technical.md](docs/technical.md)**: Dependencies, security, and deployment

## Common Development Tasks

### When Adding New Features
1. **Start with Tests**: Write failing tests that define expected behavior
2. **Check Architecture**: Ensure feature fits existing component structure
3. **Follow TDD**: Red-Green-Refactor cycle for all implementation
4. **Update Cache**: Consider caching implications for new data
5. **Document**: Update relevant specification files

### When Working with External Sources
1. **Check Rate Limits**: Ensure compliance with respectful scraping practices
2. **Use Cache First**: Always check cache before external requests
3. **Handle Errors**: Implement circuit breakers and graceful degradation
4. **Test with Mocks**: Use HTTP mocking for reliable tests

### When Modifying Data Models
1. **Update Validation**: Ensure validator tags are current
2. **Test Serialization**: Verify JSON/YAML serialization works
3. **Check Cache Impact**: Consider cache invalidation needs
4. **Update Documentation**: Modify data-models.md specification

## Testing Strategy

### Test Execution
```bash
# Unit tests only (fast)
make test-unit

# Integration tests
make test-integration  

# Specific package
go test ./internal/storage/

# With race detection
make test-race

# Benchmarks
make test-bench
```

### Test Data
- **Factories**: Use helper functions in `test/helpers/` for test data creation
- **Fixtures**: Store sample HTML/JSON in `testdata/` directories
- **Mocking**: Use testify/mock for interfaces, gock for HTTP requests

## Error Handling

### Error Types
- **ValidationError**: Input validation failures
- **ScrapingError**: Web scraping issues with source context
- **StorageError**: File system operation failures
- **CacheError**: Cache consistency or corruption issues

### Recovery Strategies
- **Retry Logic**: Exponential backoff for transient failures
- **Circuit Breakers**: Automatic source disabling
- **Graceful Degradation**: Continue with available sources
- **User Feedback**: Clear error messages and suggested actions

## Configuration

### Environment Variables
```bash
APARTMENT_HUNT_DATA_DIR="/path/to/data"
APARTMENT_HUNT_RATE_LIMIT=5
APARTMENT_HUNT_CACHE_SIZE=1000
APARTMENT_HUNT_LOG_LEVEL=info
```

### Configuration Files
- **config.yaml**: Application configuration
- **preferences.json**: User search preferences
- **cache/index.json**: Cache metadata and mappings

## Performance Considerations

- **Memory Management**: Object pooling for frequently allocated structures
- **Concurrency**: Worker pools for parallel scraping
- **Caching**: Multi-level caching with automatic expiration
- **Rate Limiting**: Respectful request timing to prevent blocking