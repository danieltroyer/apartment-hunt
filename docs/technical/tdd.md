# Test-Driven Development Methodology

> **Related Documents:**
> - [Work Items Index](../planning/work-items.md) - Epic/Feature/UserStory workflow
> - [Development Methodology](../tasking/t6.md) - Structured development approach
> - [Architecture](../planning/architecture.md) - System design context
> - [Back to Technical Documentation](../README.md)

## TDD Principles

### Red-Green-Refactor Cycle
1. **Red**: Write a failing test that defines the desired behavior
2. **Green**: Write the minimal code needed to make the test pass
3. **Refactor**: Improve the code while keeping all tests green

### Test-First Approach
- Write tests before writing implementation code
- Tests serve as specifications for the desired behavior
- Implementation is guided by test requirements
- No production code without a failing test

## Epic/Feature/UserStory Testing Strategy

### Work Item Testing Hierarchy
The testing approach aligns with the structured development methodology:

#### UserStory Level Testing
- **Unit Tests**: Each UserStory must have comprehensive unit tests
- **TDD Required**: Red-Green-Refactor cycle for every UserStory
- **Coverage Target**: 90%+ for UserStory implementation
- **Completion Criteria**: All unit tests pass before UserStory completion
- **Commit Strategy**: Only commit when UserStory passes all tests

#### Feature Level Testing  
- **Integration Tests**: Test cohesive functionality across UserStories
- **Build Requirement**: Feature must result in successful build
- **Cross-Story Testing**: Verify UserStory interactions within Feature
- **Performance Testing**: Feature-level performance and resource usage

#### Epic Level Testing
- **End-to-End Tests**: Complete user workflow validation
- **Business Value Testing**: Verify epic delivers intended capabilities
- **System Integration**: Test epic interactions with other epics
- **Acceptance Testing**: Epic-level acceptance criteria validation

### Development Workflow Integration
```
UserStory Selection
        ↓
    Write Unit Tests (Red)
        ↓
    Implement Code (Green)
        ↓
    Refactor (Green)
        ↓
    Commit UserStory
        ↓
    Feature Integration Tests
        ↓
    Epic End-to-End Tests
```

## Test Organization

### Test File Structure
```
package_name/
├── feature.go           # Implementation
├── feature_test.go      # Unit tests
└── testdata/           # Test fixtures
    ├── sample_input.json
    └── expected_output.html
```

### Work Item Test Structure
```
docs/planning/[epic]/[feature]/[userStory].md  # UserStory definition
src/[service]/[package]/
├── user_story_impl.go                         # UserStory implementation
├── user_story_impl_test.go                    # UserStory unit tests
├── feature_integration_test.go                # Feature integration tests
└── epic_e2e_test.go                          # Epic end-to-end tests
```

### Test Categories

#### Unit Tests
- Test individual functions and methods in isolation
- Fast execution (< 1 second per test)
- No external dependencies (database, network, filesystem)
- Use mocks for dependencies

```go
// Example: Unit test for apartment validation
func TestApartment_Validate(t *testing.T) {
    tests := []struct {
        name      string
        apartment *Apartment
        wantErr   bool
        errField  string
    }{
        {
            name: "valid apartment",
            apartment: &Apartment{
                Source:    "craigslist",
                URL:       "https://example.com/listing",
                Address:   "123 Main St",
                City:      "San Francisco",
                State:     "CA",
                ZipCode:   "94102",
                Price:     2500,
                Bedrooms:  2,
                Bathrooms: 1.5,
            },
            wantErr: false,
        },
        {
            name: "missing required field",
            apartment: &Apartment{
                Source: "craigslist",
                // Missing URL
            },
            wantErr:  true,
            errField: "URL",
        },
        {
            name: "invalid price",
            apartment: &Apartment{
                Source:  "craigslist",
                URL:     "https://example.com/listing",
                Address: "123 Main St",
                Price:   -100, // Invalid negative price
            },
            wantErr:  true,
            errField: "Price",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.apartment.Validate()
            
            if tt.wantErr {
                assert.Error(t, err)
                if tt.errField != "" {
                    assert.Contains(t, err.Error(), tt.errField)
                }
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

#### Integration Tests
- Test component interactions
- May involve external resources (test database, test files)
- Slower execution (seconds to minutes)
- Run with build tag to separate from unit tests

```go
//go:build integration

func TestCacheManager_Integration(t *testing.T) {
    // Create temporary directory for test
    tempDir := t.TempDir()
    
    // Initialize cache manager with real filesystem
    cacheManager := NewFilesystemCacheManager(tempDir, slog.Default())
    
    // Test storing and retrieving apartment
    apartment := createTestApartment()
    err := cacheManager.StoreListing(apartment, "<html>test</html>")
    require.NoError(t, err)
    
    // Verify cache entry exists
    entry, exists := cacheManager.ExistsByURL(apartment.URL)
    assert.True(t, exists)
    assert.Equal(t, apartment.ID, entry.ID)
    
    // Verify file was created
    assert.FileExists(t, entry.FilePath)
}
```

#### End-to-End Tests
- Test complete user workflows
- Use real or test external services
- Slowest execution (minutes)
- Run separately from unit/integration tests

```go
func TestCompleteSearchWorkflow(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping end-to-end test in short mode")
    }
    
    // Setup test environment
    app := setupTestApp(t)
    defer app.Cleanup()
    
    // Simulate user workflow
    // 1. Set preferences
    // 2. Run search
    // 3. Provide feedback
    // 4. Refine search
    // 5. Verify results
}
```

## Test Utilities and Helpers

### Test Data Factories
```go
// test/helpers/test_helpers.go
package helpers

import (
    "time"
    "github.com/google/uuid"
)

func CreateTestApartment() *Apartment {
    return &Apartment{
        ID:          uuid.New().String(),
        Source:      "test",
        SourceID:    "test-123",
        URL:         "https://test.com/listing/123",
        Address:     "123 Test Street",
        City:        "Test City",
        State:       "CA",
        ZipCode:     "12345",
        Price:       1500,
        Bedrooms:    2,
        Bathrooms:   1.0,
        SquareFeet:  800,
        Description: "Test apartment description",
        DatePosted:  time.Now().Add(-24 * time.Hour),
        DateFound:   time.Now(),
        LastSeen:    time.Now(),
        ContentHash: "testhash123",
    }
}

func CreateTestPreferences() *Preferences {
    return &Preferences{
        ID: uuid.New().String(),
        Geography: Geography{
            Cities: []string{"Test City", "Another City"},
        },
        PriceRange: Range{Min: 1000, Max: 2000},
        Bedrooms:   Range{Min: 1, Max: 3},
        Bathrooms:  Range{Min: 1, Max: 2},
        Sources:    []string{"craigslist", "zillow"},
        CreatedAt:  time.Now(),
        UpdatedAt:  time.Now(),
    }
}

func LoadTestHTML(filename string) string {
    data, err := os.ReadFile(filepath.Join("testdata", filename))
    if err != nil {
        panic(fmt.Sprintf("Failed to load test HTML: %v", err))
    }
    return string(data)
}
```

### Mock Interfaces
```go
// Use mockery to generate mocks from interfaces
//go:generate mockery --name=Storage --output=mocks
//go:generate mockery --name=Scraper --output=mocks
//go:generate mockery --name=CacheManager --output=mocks

// Example usage in tests
func TestSearchEngine_Search(t *testing.T) {
    mockStorage := mocks.NewMockStorage(t)
    mockCache := mocks.NewMockCacheManager(t)
    
    // Setup expectations
    apartments := []*Apartment{createTestApartment()}
    mockStorage.EXPECT().
        Query(mock.AnythingOfType("*SearchFilters")).
        Return(apartments, nil).
        Once()
    
    // Create search engine with mocks
    engine := NewSearchEngine(mockStorage, mockCache)
    
    // Test search functionality
    results, err := engine.Search(createTestPreferences())
    require.NoError(t, err)
    assert.Len(t, results.Apartments, 1)
    
    // Verify all expectations were met
    mockStorage.AssertExpectations(t)
}
```

### HTTP Mocking for Scrapers
```go
func TestCraigslistScraper_Scrape(t *testing.T) {
    defer gock.Off() // Clean up after test
    
    // Mock HTTP response
    gock.New("https://craigslist.org").
        Get("/search/apa").
        Reply(200).
        BodyString(LoadTestHTML("craigslist_listing.html"))
    
    scraper := NewCraigslistScraper(http.DefaultClient)
    preferences := createTestPreferences()
    
    apartments, err := scraper.Scrape(preferences)
    require.NoError(t, err)
    assert.NotEmpty(t, apartments)
    
    // Verify HTTP call was made
    assert.True(t, gock.IsDone())
}
```

## Testing Strategies by Component

### Models Testing
```go
// Test validation rules
func TestApartmentValidation(t *testing.T) {
    // Test valid cases
    // Test invalid field values
    // Test edge cases
    // Test required field validation
}

// Test business logic
func TestPreferences_Matches(t *testing.T) {
    // Test price range matching
    // Test geographic matching
    // Test keyword matching
    // Test exclusion logic
}

// Test helper methods
func TestApartment_GenerateContentHash(t *testing.T) {
    // Test hash consistency
    // Test hash uniqueness for different apartments
    // Test hash collision for same apartment
}
```

### Storage Testing
```go
// Test interface compliance
func TestFilesystemStorage_ImplementsInterface(t *testing.T) {
    var _ Storage = (*FilesystemStorage)(nil)
}

// Test CRUD operations
func TestFilesystemStorage_Store(t *testing.T) {
    tempDir := t.TempDir()
    storage := NewFilesystemStorage(tempDir)
    
    apartment := createTestApartment()
    err := storage.Store(apartment)
    require.NoError(t, err)
    
    // Verify file exists
    expectedPath := filepath.Join(tempDir, "listings", "2024-01-15", apartment.ID+".md")
    assert.FileExists(t, expectedPath)
}

// Test error conditions
func TestFilesystemStorage_StoreInvalidApartment(t *testing.T) {
    storage := NewFilesystemStorage("/nonexistent")
    
    apartment := &Apartment{} // Invalid apartment
    err := storage.Store(apartment)
    assert.Error(t, err)
}
```

### Cache Testing
```go
// Test deduplication logic
func TestCacheManager_Deduplication(t *testing.T) {
    cache := setupTestCache(t)
    
    // Store original apartment
    apt1 := createTestApartment()
    err := cache.StoreListing(apt1, "")
    require.NoError(t, err)
    
    // Try to store same apartment with different URL
    apt2 := createTestApartment()
    apt2.URL = "https://different-url.com"
    // Same content hash
    
    entry, exists := cache.ExistsByContentHash(apt2.ContentHash)
    assert.True(t, exists)
    assert.Equal(t, apt1.ID, entry.ID)
}

// Test cache expiration
func TestCacheManager_StalenessDetection(t *testing.T) {
    // Test listing staleness calculation
    // Test automatic cleanup
    // Test refresh triggers
}
```

### Scraper Testing
```go
// Test HTML parsing
func TestCraigslistScraper_ParseListing(t *testing.T) {
    html := LoadTestHTML("craigslist_single_listing.html")
    
    scraper := NewCraigslistScraper(nil)
    apartment, err := scraper.parseListing(html, "test-url")
    
    require.NoError(t, err)
    assert.Equal(t, "123 Main St", apartment.Address)
    assert.Equal(t, 1500, apartment.Price)
    assert.Equal(t, 2, apartment.Bedrooms)
}

// Test error handling
func TestCraigslistScraper_ParseInvalidHTML(t *testing.T) {
    scraper := NewCraigslistScraper(nil)
    
    _, err := scraper.parseListing("<invalid>html</invalid>", "test-url")
    assert.Error(t, err)
}

// Test rate limiting
func TestScraperManager_RateLimit(t *testing.T) {
    // Mock HTTP responses
    // Test request timing
    // Verify rate limiting is enforced
}
```

## Work Item Test Execution

### UserStory Testing Commands
```bash
# Run tests for specific UserStory
make test-user-story STORY=user-management/authentication/user-registration

# Run tests for specific Feature
make test-feature FEATURE=user-management/authentication

# Run tests for specific Epic
make test-epic EPIC=user-management

# TDD cycle for current UserStory
make tdd-user-story STORY=current
```

### Work Item Commit Validation
```bash
# Pre-commit hook validation
#!/bin/bash
# Ensure UserStory tests pass before commit
if [[ $(git diff --cached --name-only | grep -E '\.go$') ]]; then
    echo "Running UserStory tests before commit..."
    make test-user-story STORY=$(git branch --show-current | sed 's/.*\///') || exit 1
fi
```

## Test Automation

### Makefile Targets
```makefile
.PHONY: test test-unit test-integration test-e2e test-coverage test-watch

# Run all tests
test:
	go test ./...

# Run only unit tests (fast)
test-unit:
	go test -short ./...

# Run integration tests
test-integration:
	go test -tags=integration ./...

# Run end-to-end tests
test-e2e:
	go test -tags=e2e ./test/e2e/...

# Generate coverage report
test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

# Watch for changes and run tests
test-watch:
	@echo "Watching for changes..."
	@while true; do \
		find . -name "*.go" | entr -d make test-unit; \
	done

# TDD workflow for UserStories
tdd:
	@echo "Starting TDD cycle..."
	@make test-unit
	@make test-watch

# TDD for specific UserStory
tdd-user-story:
	@echo "Starting TDD cycle for UserStory: $(STORY)..."
	@go test -v ./... -run TestUserStory$(shell echo $(STORY) | sed 's/[^a-zA-Z0-9]//g')
	@make test-watch

# Test specific work items
test-user-story:
	@echo "Testing UserStory: $(STORY)"
	@go test -v ./... -run TestUserStory$(shell echo $(STORY) | sed 's/[^a-zA-Z0-9]//g')

test-feature:
	@echo "Testing Feature: $(FEATURE)"
	@go test -tags=integration -v ./... -run TestFeature$(shell echo $(FEATURE) | sed 's/[^a-zA-Z0-9]//g')

test-epic:
	@echo "Testing Epic: $(EPIC)"
	@go test -tags=e2e -v ./... -run TestEpic$(shell echo $(EPIC) | sed 's/[^a-zA-Z0-9]//g')

# Validate work item completion
validate-user-story:
	@echo "Validating UserStory completion: $(STORY)"
	@make test-user-story STORY=$(STORY)
	@echo "UserStory $(STORY) validation complete"

validate-feature:
	@echo "Validating Feature completion: $(FEATURE)"
	@make test-feature FEATURE=$(FEATURE)
	@make build
	@echo "Feature $(FEATURE) validation complete"

validate-epic:
	@echo "Validating Epic completion: $(EPIC)"
	@make test-epic EPIC=$(EPIC)
	@make test-integration
	@echo "Epic $(EPIC) validation complete"

# Benchmark tests
test-bench:
	go test -bench=. -benchmem ./...

# Race condition detection
test-race:
	go test -race ./...

# Generate mocks
generate-mocks:
	go generate ./...

# Lint tests
lint-tests:
	golangci-lint run --config .golangci-tests.yml ./...
```

### Continuous Integration
```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Go
      uses: actions/setup-go@v3
      with:
        go-version: '1.21'
    
    - name: Cache Go modules
      uses: actions/cache@v3
      with:
        path: ~/go/pkg/mod
        key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
        restore-keys: |
          ${{ runner.os }}-go-
    
    - name: Install dependencies
      run: go mod download
    
    - name: Generate mocks
      run: make generate-mocks
    
    - name: Run unit tests
      run: make test-unit
    
    - name: Run integration tests
      run: make test-integration
    
    - name: Run race detection
      run: make test-race
    
    - name: Generate coverage
      run: make test-coverage
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.out
```

## Test Configuration

### Test-specific Configuration
```go
// config/test.go
package config

func TestConfig() *Config {
    return &Config{
        Storage: StorageConfig{
            DataDir: "/tmp/apartment-hunt-test",
        },
        Scrapers: ScrapersConfig{
            RateLimit: RateLimitConfig{
                RequestsPerSecond: 100, // Higher for tests
                Burst:            10,
            },
        },
        Search: SearchConfig{
            MaxResults: 10,
        },
    }
}
```

### Test Environment Setup
```go
// test/helpers/setup.go
package helpers

func SetupTestEnvironment(t *testing.T) (cleanup func()) {
    // Set test configuration
    originalConfig := os.Getenv("APARTMENT_HUNT_CONFIG")
    os.Setenv("APARTMENT_HUNT_CONFIG", "test")
    
    // Create temporary directory
    tempDir := t.TempDir()
    os.Setenv("APARTMENT_HUNT_DATA_DIR", tempDir)
    
    // Setup test database/storage
    setupTestStorage(tempDir)
    
    return func() {
        // Restore original configuration
        if originalConfig == "" {
            os.Unsetenv("APARTMENT_HUNT_CONFIG")
        } else {
            os.Setenv("APARTMENT_HUNT_CONFIG", originalConfig)
        }
        
        // Cleanup is automatic with t.TempDir()
    }
}
```

## Test Coverage Goals

### Coverage Targets
- **Unit Tests**: 90%+ line coverage
- **Integration Tests**: 80%+ feature coverage
- **Critical Paths**: 100% coverage (validation, caching, deduplication)

### Coverage Reporting
```bash
# Generate detailed coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Check coverage threshold
go test -cover ./... | grep -E "coverage: [0-9]+\.[0-9]+%" | \
    awk '{if ($2 < 90.0) exit 1}'
```

## Best Practices

### Test Organization
1. **Arrange-Act-Assert**: Structure tests clearly
2. **One assertion per test**: Focus on single behavior
3. **Descriptive names**: Test names should explain the scenario
4. **Independent tests**: No dependencies between tests
5. **Fast execution**: Unit tests should run in milliseconds

### Test Data Management
1. **Use factories**: Create test data programmatically
2. **Minimize fixtures**: Prefer generated over static test data
3. **Clean slate**: Each test starts with fresh state
4. **Realistic data**: Test data should reflect production scenarios

### Error Testing
1. **Test error paths**: Don't just test happy path
2. **Specific assertions**: Check error messages and types
3. **Error boundaries**: Test system behavior under failures
4. **Recovery testing**: Verify graceful degradation