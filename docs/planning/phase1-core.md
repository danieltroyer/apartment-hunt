# Phase 1: Core Infrastructure (Week 1)

## Overview
Establish the foundation of the apartment hunting application including project setup, core data models, storage system, and caching infrastructure.

## TDD Approach
For each feature, follow the Red-Green-Refactor cycle:
1. Write failing tests that define expected behavior
2. Implement minimal code to pass tests
3. Refactor while keeping tests green

## Day 1-2: Project Setup and Configuration

### 1. Initialize Go Module and Project Structure
```bash
# Create project directory
mkdir apartment-hunt
cd apartment-hunt

# Initialize Go module
go mod init apartment-hunt

# Create directory structure
mkdir -p {cmd/apartment-hunt,internal/{config,models,storage,scrapers,search,ui},pkg/utils,test/{integration,fixtures,helpers},docs,data}

# Create initial files
touch {cmd/apartment-hunt/main.go,internal/config/config.go,Makefile,README.md}
```

### 2. Setup Testing Framework
**Test First**: Write configuration tests
```go
// internal/config/config_test.go
package config

import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestConfig_LoadFromDefaults(t *testing.T) {
    cfg, err := NewConfig()
    require.NoError(t, err)
    
    assert.Equal(t, "./data", cfg.Storage.DataDir)
    assert.Equal(t, 5, cfg.Scrapers.RateLimit.RequestsPerSecond)
    assert.True(t, cfg.Storage.EnableCache)
}

func TestConfig_LoadFromEnvironment(t *testing.T) {
    t.Setenv("APARTMENT_HUNT_DATA_DIR", "/custom/path")
    t.Setenv("APARTMENT_HUNT_RATE_LIMIT", "10")
    
    cfg, err := NewConfig()
    require.NoError(t, err)
    
    assert.Equal(t, "/custom/path", cfg.Storage.DataDir)
    assert.Equal(t, 10, cfg.Scrapers.RateLimit.RequestsPerSecond)
}

func TestConfig_ValidateRequired(t *testing.T) {
    cfg := &Config{
        Storage: StorageConfig{
            DataDir: "", // Invalid empty path
        },
    }
    
    err := cfg.Validate()
    assert.Error(t, err)
    assert.Contains(t, err.Error(), "DataDir")
}
```

**Implementation**: Create configuration management
```go
// internal/config/config.go
package config

import (
    "fmt"
    "os"
    "strconv"
    "github.com/go-playground/validator/v10"
)

type Config struct {
    Storage   StorageConfig   `yaml:"storage" validate:"required"`
    Scrapers  ScrapersConfig  `yaml:"scrapers" validate:"required"`
    Search    SearchConfig    `yaml:"search" validate:"required"`
}

type StorageConfig struct {
    DataDir     string `yaml:"data_dir" env:"APARTMENT_HUNT_DATA_DIR" validate:"required"`
    EnableCache bool   `yaml:"enable_cache" env:"APARTMENT_HUNT_ENABLE_CACHE"`
    CacheSize   int    `yaml:"cache_size" env:"APARTMENT_HUNT_CACHE_SIZE" validate:"min=1"`
}

type ScrapersConfig struct {
    RateLimit RateLimitConfig `yaml:"rate_limit" validate:"required"`
    Timeout   int             `yaml:"timeout" env:"APARTMENT_HUNT_TIMEOUT" validate:"min=1"`
    UserAgent string          `yaml:"user_agent" env:"APARTMENT_HUNT_USER_AGENT"`
}

type RateLimitConfig struct {
    RequestsPerSecond int `yaml:"requests_per_second" env:"APARTMENT_HUNT_RATE_LIMIT" validate:"min=1,max=100"`
    Burst            int `yaml:"burst" env:"APARTMENT_HUNT_BURST" validate:"min=1"`
}

type SearchConfig struct {
    MaxResults int `yaml:"max_results" env:"APARTMENT_HUNT_MAX_RESULTS" validate:"min=1,max=1000"`
}

func NewConfig() (*Config, error) {
    cfg := &Config{
        Storage: StorageConfig{
            DataDir:     getEnvOrDefault("APARTMENT_HUNT_DATA_DIR", "./data"),
            EnableCache: getEnvBoolOrDefault("APARTMENT_HUNT_ENABLE_CACHE", true),
            CacheSize:   getEnvIntOrDefault("APARTMENT_HUNT_CACHE_SIZE", 1000),
        },
        Scrapers: ScrapersConfig{
            RateLimit: RateLimitConfig{
                RequestsPerSecond: getEnvIntOrDefault("APARTMENT_HUNT_RATE_LIMIT", 5),
                Burst:            getEnvIntOrDefault("APARTMENT_HUNT_BURST", 10),
            },
            Timeout:   getEnvIntOrDefault("APARTMENT_HUNT_TIMEOUT", 30),
            UserAgent: getEnvOrDefault("APARTMENT_HUNT_USER_AGENT", "apartment-hunt/1.0"),
        },
        Search: SearchConfig{
            MaxResults: getEnvIntOrDefault("APARTMENT_HUNT_MAX_RESULTS", 100),
        },
    }
    
    return cfg, cfg.Validate()
}

func (c *Config) Validate() error {
    validate := validator.New()
    return validate.Struct(c)
}

func getEnvOrDefault(key, defaultVal string) string {
    if val := os.Getenv(key); val != "" {
        return val
    }
    return defaultVal
}

func getEnvIntOrDefault(key string, defaultVal int) int {
    if val := os.Getenv(key); val != "" {
        if intVal, err := strconv.Atoi(val); err == nil {
            return intVal
        }
    }
    return defaultVal
}

func getEnvBoolOrDefault(key string, defaultVal bool) bool {
    if val := os.Getenv(key); val != "" {
        if boolVal, err := strconv.ParseBool(val); err == nil {
            return boolVal
        }
    }
    return defaultVal
}
```

### 3. Setup CLI Framework
**Test First**: Write CLI tests
```go
// internal/ui/cli_test.go
package ui

import (
    "bytes"
    "testing"
    "github.com/spf13/cobra"
    "github.com/stretchr/testify/assert"
)

func TestRootCommand_Execute(t *testing.T) {
    cmd := NewRootCommand()
    cmd.SetArgs([]string{"--help"})
    
    var output bytes.Buffer
    cmd.SetOut(&output)
    
    err := cmd.Execute()
    assert.NoError(t, err)
    assert.Contains(t, output.String(), "apartment hunting")
}

func TestSearchCommand_RequiredFlags(t *testing.T) {
    cmd := NewRootCommand()
    cmd.SetArgs([]string{"search"})
    
    err := cmd.Execute()
    // Should not error with default preferences
    assert.NoError(t, err)
}
```

**Implementation**: Create basic CLI structure
```go
// cmd/apartment-hunt/main.go
package main

import (
    "log"
    "apartment-hunt/internal/ui"
)

func main() {
    if err := ui.NewRootCommand().Execute(); err != nil {
        log.Fatal(err)
    }
}
```

```go
// internal/ui/cli.go
package ui

import (
    "fmt"
    "github.com/spf13/cobra"
    "apartment-hunt/internal/config"
)

func NewRootCommand() *cobra.Command {
    var configPath string
    
    cmd := &cobra.Command{
        Use:   "apartment-hunt",
        Short: "A tool for hunting apartments across multiple sources",
        Long: `apartment-hunt aggregates apartment listings from multiple sources,
manages your preferences, and helps refine your search based on feedback.`,
    }
    
    cmd.PersistentFlags().StringVar(&configPath, "config", "", "config file path")
    
    // Add subcommands
    cmd.AddCommand(newSearchCommand())
    cmd.AddCommand(newCacheCommand())
    cmd.AddCommand(newPreferencesCommand())
    
    return cmd
}

func newSearchCommand() *cobra.Command {
    var refresh bool
    var refreshSource string
    
    cmd := &cobra.Command{
        Use:   "search",
        Short: "Search for apartments",
        RunE: func(cmd *cobra.Command, args []string) error {
            // Will implement search logic in later phases
            fmt.Println("Search functionality coming soon...")
            return nil
        },
    }
    
    cmd.Flags().BoolVar(&refresh, "refresh", false, "Force refresh all cached listings")
    cmd.Flags().StringVar(&refreshSource, "refresh-source", "", "Refresh specific source")
    
    return cmd
}

func newCacheCommand() *cobra.Command {
    cmd := &cobra.Command{
        Use:   "cache",
        Short: "Cache management operations",
    }
    
    cmd.AddCommand(&cobra.Command{
        Use:   "stats",
        Short: "Show cache statistics",
        RunE: func(cmd *cobra.Command, args []string) error {
            fmt.Println("Cache stats coming soon...")
            return nil
        },
    })
    
    return cmd
}

func newPreferencesCommand() *cobra.Command {
    return &cobra.Command{
        Use:   "preferences",
        Short: "Manage search preferences",
        RunE: func(cmd *cobra.Command, args []string) error {
            fmt.Println("Preferences management coming soon...")
            return nil
        },
    }
}
```

## Day 3-4: Data Models Implementation

### 1. Apartment Model
**Test First**: Write apartment model tests
```go
// internal/models/apartment_test.go
package models

import (
    "testing"
    "time"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestApartment_Validate(t *testing.T) {
    tests := []struct {
        name        string
        apartment   *Apartment
        expectError bool
        errorField  string
    }{
        {
            name:        "valid apartment",
            apartment:   createValidApartment(),
            expectError: false,
        },
        {
            name: "missing required fields",
            apartment: &Apartment{
                Source: "craigslist",
                // Missing other required fields
            },
            expectError: true,
            errorField:  "Address",
        },
        {
            name: "invalid price",
            apartment: func() *Apartment {
                apt := createValidApartment()
                apt.Price = -100
                return apt
            }(),
            expectError: true,
            errorField:  "Price",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.apartment.Validate()
            
            if tt.expectError {
                assert.Error(t, err)
                if tt.errorField != "" {
                    assert.Contains(t, err.Error(), tt.errorField)
                }
            } else {
                assert.NoError(t, err)
            }
        })
    }
}

func TestApartment_GenerateContentHash(t *testing.T) {
    apt1 := createValidApartment()
    apt2 := createValidApartment()
    
    // Same apartment should generate same hash
    apt1.GenerateContentHash()
    apt2.GenerateContentHash()
    assert.Equal(t, apt1.ContentHash, apt2.ContentHash)
    
    // Different apartment should generate different hash
    apt2.Price = 2000
    apt2.GenerateContentHash()
    assert.NotEqual(t, apt1.ContentHash, apt2.ContentHash)
}

func TestApartment_CalculatePricePerSqFt(t *testing.T) {
    apt := createValidApartment()
    apt.Price = 1500
    apt.SquareFeet = 750
    
    apt.CalculatePricePerSqFt()
    assert.Equal(t, 2.0, apt.PricePerSqFt)
}

func createValidApartment() *Apartment {
    return &Apartment{
        Source:      "craigslist",
        SourceID:    "12345",
        URL:         "https://craigslist.org/apt/12345",
        Address:     "123 Main Street",
        City:        "San Francisco",
        State:       "CA",
        ZipCode:     "94102",
        Price:       1500,
        Bedrooms:    2,
        Bathrooms:   1.5,
        SquareFeet:  800,
        Description: "Nice apartment in great location",
        DatePosted:  time.Now().Add(-24 * time.Hour),
        DateFound:   time.Now(),
        LastSeen:    time.Now(),
    }
}
```

**Implementation**: Create apartment model (see data-models.md for full implementation)

### 2. Preferences Model
**Test First**: Write preferences tests
```go
// internal/models/preferences_test.go
package models

func TestPreferences_Matches(t *testing.T) {
    preferences := &Preferences{
        PriceRange: Range{Min: 1000, Max: 2000},
        Bedrooms:   Range{Min: 1, Max: 3},
        Geography: Geography{
            Cities: []string{"San Francisco", "Oakland"},
        },
    }
    
    tests := []struct {
        name      string
        apartment *Apartment
        matches   bool
    }{
        {
            name: "matches all criteria",
            apartment: &Apartment{
                Price:    1500,
                Bedrooms: 2,
                City:     "San Francisco",
            },
            matches: true,
        },
        {
            name: "price too high",
            apartment: &Apartment{
                Price:    2500,
                Bedrooms: 2,
                City:     "San Francisco",
            },
            matches: false,
        },
        {
            name: "wrong city",
            apartment: &Apartment{
                Price:    1500,
                Bedrooms: 2,
                City:     "Los Angeles",
            },
            matches: false,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := preferences.Matches(tt.apartment)
            assert.Equal(t, tt.matches, result)
        })
    }
}
```

## Day 5-6: Storage System Implementation

### 1. Storage Interface
**Test First**: Write storage interface tests
```go
// internal/storage/interface_test.go
package storage

import (
    "testing"
    "apartment-hunt/internal/models"
)

// Test that all implementations satisfy the interface
func TestStorageImplementations(t *testing.T) {
    var _ Storage = (*FilesystemStorage)(nil)
    // Add other implementations as they're created
}

// Integration test for storage operations
func TestStorage_CRUD(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }
    
    tempDir := t.TempDir()
    storage := NewFilesystemStorage(tempDir)
    
    // Test Store
    apartment := createTestApartment()
    err := storage.Store(apartment)
    require.NoError(t, err)
    
    // Test Load
    loaded, err := storage.Load(apartment.ID)
    require.NoError(t, err)
    assert.Equal(t, apartment.ID, loaded.ID)
    assert.Equal(t, apartment.Address, loaded.Address)
    
    // Test Query
    filters := &models.SearchFilters{
        Preferences: &models.Preferences{
            PriceRange: models.Range{Min: 1000, Max: 2000},
        },
    }
    results, err := storage.Query(filters)
    require.NoError(t, err)
    assert.Len(t, results, 1)
    
    // Test Delete
    err = storage.Delete(apartment.ID)
    require.NoError(t, err)
    
    _, err = storage.Load(apartment.ID)
    assert.Error(t, err)
}
```

**Implementation**: Create filesystem storage
```go
// internal/storage/interface.go
package storage

import "apartment-hunt/internal/models"

type Storage interface {
    Store(apartment *models.Apartment) error
    Load(id string) (*models.Apartment, error)
    Query(filters *models.SearchFilters) ([]*models.Apartment, error)
    Delete(id string) error
    List() ([]*models.Apartment, error)
    Close() error
}
```

```go
// internal/storage/filesystem.go
package storage

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "time"
    "apartment-hunt/internal/models"
)

type FilesystemStorage struct {
    dataDir string
}

func NewFilesystemStorage(dataDir string) *FilesystemStorage {
    return &FilesystemStorage{
        dataDir: dataDir,
    }
}

func (fs *FilesystemStorage) Store(apartment *models.Apartment) error {
    if err := apartment.Validate(); err != nil {
        return fmt.Errorf("invalid apartment: %w", err)
    }
    
    // Create directory structure
    dateDir := apartment.DateFound.Format("2006-01-02")
    fullDir := filepath.Join(fs.dataDir, "listings", dateDir)
    if err := os.MkdirAll(fullDir, 0755); err != nil {
        return fmt.Errorf("failed to create directory: %w", err)
    }
    
    // Write JSON file
    filename := apartment.ID + ".json"
    filePath := filepath.Join(fullDir, filename)
    
    data, err := json.MarshalIndent(apartment, "", "  ")
    if err != nil {
        return fmt.Errorf("failed to marshal apartment: %w", err)
    }
    
    if err := os.WriteFile(filePath, data, 0644); err != nil {
        return fmt.Errorf("failed to write file: %w", err)
    }
    
    // Write markdown file
    if err := fs.writeMarkdownFile(apartment, fullDir); err != nil {
        return fmt.Errorf("failed to write markdown: %w", err)
    }
    
    return nil
}

func (fs *FilesystemStorage) Load(id string) (*models.Apartment, error) {
    // Search through date directories to find the file
    // Implementation details...
}

func (fs *FilesystemStorage) Query(filters *models.SearchFilters) ([]*models.Apartment, error) {
    // Implementation details...
}

// Additional methods...
```

### 2. Cache Manager
**Test First**: Write cache tests
```go
// internal/storage/cache_test.go
package storage

func TestCacheManager_ExistsByURL(t *testing.T) {
    cache := setupTestCache(t)
    
    apartment := createTestApartment()
    err := cache.StoreListing(apartment, "<html>test</html>")
    require.NoError(t, err)
    
    entry, exists := cache.ExistsByURL(apartment.URL)
    assert.True(t, exists)
    assert.Equal(t, apartment.ID, entry.ID)
    
    _, exists = cache.ExistsByURL("https://nonexistent.com")
    assert.False(t, exists)
}

func TestCacheManager_Deduplication(t *testing.T) {
    cache := setupTestCache(t)
    
    // Store original apartment
    apt1 := createTestApartment()
    apt1.GenerateContentHash()
    err := cache.StoreListing(apt1, "")
    require.NoError(t, err)
    
    // Try to store duplicate with different URL
    apt2 := createTestApartment()
    apt2.URL = "https://different-url.com"
    apt2.GenerateContentHash() // Same content, different URL
    
    entry, exists := cache.ExistsByContentHash(apt2.ContentHash)
    assert.True(t, exists)
    assert.Equal(t, apt1.ID, entry.ID)
}
```

**Implementation**: Create cache manager (see caching.md for full implementation)

## Day 7: Integration and Validation

### 1. End-to-End Testing
```go
// test/integration/core_integration_test.go
//go:build integration

package integration

func TestCoreWorkflow(t *testing.T) {
    // Setup test environment
    tempDir := t.TempDir()
    
    // Initialize components
    storage := storage.NewFilesystemStorage(tempDir)
    cache := storage.NewFilesystemCacheManager(tempDir, slog.Default())
    
    // Test complete workflow
    apartment := models.CreateTestApartment()
    
    // Store apartment
    err := storage.Store(apartment)
    require.NoError(t, err)
    
    // Verify in cache
    entry, exists := cache.ExistsByURL(apartment.URL)
    assert.True(t, exists)
    
    // Query apartments
    filters := &models.SearchFilters{
        Preferences: &models.Preferences{
            PriceRange: models.Range{Min: 1000, Max: 2000},
        },
    }
    results, err := storage.Query(filters)
    require.NoError(t, err)
    assert.Len(t, results, 1)
}
```

### 2. Performance Testing
```go
// internal/storage/benchmark_test.go
package storage

func BenchmarkFilesystemStorage_Store(b *testing.B) {
    tempDir := b.TempDir()
    storage := NewFilesystemStorage(tempDir)
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        apartment := createTestApartment()
        apartment.ID = fmt.Sprintf("bench-%d", i)
        storage.Store(apartment)
    }
}

func BenchmarkCacheManager_ExistsByURL(b *testing.B) {
    cache := setupBenchmarkCache(b)
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        cache.ExistsByURL("https://test.com/listing-" + strconv.Itoa(i))
    }
}
```

### 3. Validation and Documentation
```bash
# Run all tests
make test

# Check coverage
make test-coverage

# Lint code
make lint

# Build application
make build

# Test CLI commands
./bin/apartment-hunt --help
./bin/apartment-hunt search --help
./bin/apartment-hunt cache stats
```

## Phase 1 Deliverables

### ✅ Completed Features
- [x] Go module initialization and project structure
- [x] Configuration management with environment variable support
- [x] CLI framework with basic commands
- [x] Core data models (Apartment, Preferences, Feedback)
- [x] File-based storage system
- [x] Cache manager with deduplication
- [x] Comprehensive test suite
- [x] Build and development automation

### 📁 Files Created
```
apartment-hunt/
├── cmd/apartment-hunt/main.go
├── internal/
│   ├── config/
│   │   ├── config.go
│   │   └── config_test.go
│   ├── models/
│   │   ├── apartment.go
│   │   ├── apartment_test.go
│   │   ├── preferences.go
│   │   ├── preferences_test.go
│   │   ├── feedback.go
│   │   └── feedback_test.go
│   ├── storage/
│   │   ├── interface.go
│   │   ├── filesystem.go
│   │   ├── filesystem_test.go
│   │   ├── cache.go
│   │   └── cache_test.go
│   └── ui/
│       ├── cli.go
│       └── cli_test.go
├── test/
│   ├── integration/
│   │   └── core_integration_test.go
│   └── helpers/
│       └── test_helpers.go
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

### 🔧 Working Commands
```bash
# Build and test
make build
make test
make test-coverage

# CLI commands
apartment-hunt --help
apartment-hunt search
apartment-hunt cache stats
apartment-hunt preferences
```

### ➡️ Next Phase
Ready to proceed to [Phase 2: Data Collection](phase2-scraping.md) with:
- Stable core infrastructure
- Comprehensive test coverage
- Working CLI framework
- Efficient caching system