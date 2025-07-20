# Development Commands

## Prerequisites
```bash
# Install Go 1.21+
go version

# Install development tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/vektra/mockery/v2@latest
go install honnef.co/go/tools/cmd/staticcheck@latest

# Install file watching tool (for TDD)
go install github.com/eradman/entr@latest
```

## Project Setup
```bash
# Initialize project
go mod init apartment-hunt
go mod tidy

# Install dependencies
go get github.com/spf13/cobra@latest
go get github.com/stretchr/testify@latest
go get github.com/PuerkitoBio/goquery@latest
go get github.com/go-resty/resty/v2@latest
go get github.com/google/uuid@latest
go get github.com/go-playground/validator/v10@latest
go get gopkg.in/yaml.v3@latest

# Install test dependencies
go get github.com/h2non/gock@latest
go get github.com/golang/mock@latest
```

## Build Commands
```bash
# Build application
make build
# or
go build -o bin/apartment-hunt cmd/apartment-hunt/main.go

# Build for multiple platforms
make build-all

# Build with version info
make build-release

# Clean build artifacts
make clean
```

## Testing Commands

### Unit Tests
```bash
# Run all unit tests
make test-unit
# or
go test -short ./...

# Run specific package tests
go test ./internal/models/
go test ./internal/storage/

# Run specific test
go test -run TestApartment_Validate ./internal/models/

# Run tests with verbose output
go test -v ./...

# Run tests with race detection
make test-race
# or
go test -race ./...
```

### Integration Tests
```bash
# Run integration tests
make test-integration
# or
go test -tags=integration ./test/integration/

# Run all tests (unit + integration)
make test
# or
go test ./...
```

### Test Coverage
```bash
# Generate coverage report
make test-coverage
# or
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html

# View coverage in terminal
go test -cover ./...

# Coverage with threshold check
go test -cover ./... | grep -E "coverage: [0-9]+\.[0-9]+%" | \
    awk '{if ($2 < 90.0) exit 1}'
```

### Test Development Workflow
```bash
# TDD workflow - watch for changes and run tests
make tdd
# or
make test-watch

# Run tests continuously (manual)
while true; do
    find . -name "*.go" | entr -d make test-unit
done
```

### Benchmarks
```bash
# Run benchmarks
make test-bench
# or
go test -bench=. -benchmem ./...

# Run specific benchmark
go test -bench=BenchmarkStorage ./internal/storage/

# Compare benchmarks
go test -bench=. ./... > old.txt
# Make changes
go test -bench=. ./... > new.txt
benchcmp old.txt new.txt
```

## Code Quality

### Linting
```bash
# Run linter
make lint
# or
golangci-lint run

# Fix auto-fixable issues
golangci-lint run --fix

# Lint specific directory
golangci-lint run ./internal/models/
```

### Static Analysis
```bash
# Run staticcheck
staticcheck ./...

# Run go vet
go vet ./...

# Check for formatting issues
gofmt -l .

# Format code
gofmt -w .
# or
go fmt ./...
```

### Generate Code
```bash
# Generate mocks
make generate-mocks
# or
go generate ./...

# Generate specific mocks
mockery --name=Storage --dir=./internal/storage --output=./internal/storage/mocks

# Update go.mod
go mod tidy
```

## Application Commands

### Basic Usage
```bash
# Show help
./bin/apartment-hunt --help
./bin/apartment-hunt search --help

# Run search with default preferences
./bin/apartment-hunt search

# Run search with custom config
./bin/apartment-hunt --config ./config.yaml search
```

### Search Commands
```bash
# Normal search (uses cache)
./bin/apartment-hunt search

# Force refresh all sources
./bin/apartment-hunt search --refresh

# Refresh specific source
./bin/apartment-hunt search --refresh-source craigslist

# Search with custom preferences
./bin/apartment-hunt search \
    --min-price 1500 \
    --max-price 3000 \
    --bedrooms 2 \
    --city "San Francisco"

# Refresh listings older than specified time
./bin/apartment-hunt search --refresh-older-than 24h
```

### Cache Management
```bash
# Show cache statistics
./bin/apartment-hunt cache stats

# Clear all cache
./bin/apartment-hunt cache clear

# Clear cache for specific source
./bin/apartment-hunt cache clear --source craigslist

# Validate cache integrity
./bin/apartment-hunt cache validate

# Compact cache (remove stale entries)
./bin/apartment-hunt cache compact

# Backup cache
./bin/apartment-hunt cache backup ./backup/

# List cached listings
./bin/apartment-hunt cache list

# Show cache by source
./bin/apartment-hunt cache list-sources
```

### Preferences Management
```bash
# Show current preferences
./bin/apartment-hunt preferences show

# Set preferences interactively
./bin/apartment-hunt preferences set

# Import preferences from file
./bin/apartment-hunt preferences import ./preferences.yaml

# Export preferences to file
./bin/apartment-hunt preferences export ./preferences.yaml

# Reset preferences to defaults
./bin/apartment-hunt preferences reset
```

### Advanced Commands
```bash
# Run with debug logging
./bin/apartment-hunt --log-level debug search

# Use custom data directory
./bin/apartment-hunt --data-dir ./custom-data search

# Run with custom user agent
APARTMENT_HUNT_USER_AGENT="custom-bot/1.0" ./bin/apartment-hunt search

# Set rate limiting
APARTMENT_HUNT_RATE_LIMIT=10 ./bin/apartment-hunt search

# Dry run (show what would be done)
./bin/apartment-hunt search --dry-run
```

## Environment Variables
```bash
# Configuration
export APARTMENT_HUNT_DATA_DIR="/path/to/data"
export APARTMENT_HUNT_CONFIG="/path/to/config.yaml"

# Rate limiting
export APARTMENT_HUNT_RATE_LIMIT=5
export APARTMENT_HUNT_BURST=10
export APARTMENT_HUNT_TIMEOUT=30

# Cache settings
export APARTMENT_HUNT_ENABLE_CACHE=true
export APARTMENT_HUNT_CACHE_SIZE=1000

# Scraper settings
export APARTMENT_HUNT_USER_AGENT="apartment-hunt/1.0"
export APARTMENT_HUNT_MAX_RESULTS=100

# Logging
export APARTMENT_HUNT_LOG_LEVEL=info
export APARTMENT_HUNT_LOG_FORMAT=json
```

## Docker Commands
```bash
# Build Docker image
docker build -t apartment-hunt .

# Run in container
docker run -v $(pwd)/data:/app/data apartment-hunt search

# Run with environment variables
docker run \
    -e APARTMENT_HUNT_RATE_LIMIT=10 \
    -v $(pwd)/data:/app/data \
    apartment-hunt search

# Docker Compose
docker-compose up apartment-hunt
```

## Development Workflow

### Daily Development
```bash
# 1. Start TDD cycle
make tdd

# 2. In another terminal, run application
./bin/apartment-hunt search

# 3. Run full test suite before commit
make ci
```

### Before Committing
```bash
# Run full CI pipeline
make ci

# This runs:
# - Unit tests
# - Integration tests
# - Linting
# - Build
# - Coverage check
```

### Release Process
```bash
# 1. Update version
git tag v1.0.0

# 2. Build release
make build-release

# 3. Run release tests
make test-release

# 4. Create release package
make package
```

## Debugging Commands

### Profiling
```bash
# CPU profiling
go test -cpuprofile=cpu.prof -bench=. ./internal/storage/
go tool pprof cpu.prof

# Memory profiling
go test -memprofile=mem.prof -bench=. ./internal/storage/
go tool pprof mem.prof

# Profile running application
go tool pprof http://localhost:6060/debug/pprof/profile
```

### Debugging
```bash
# Run with delve debugger
dlv debug cmd/apartment-hunt/main.go -- search

# Debug tests
dlv test ./internal/models/ -- -test.run TestApartment_Validate

# Trace execution
go run -trace=trace.out cmd/apartment-hunt/main.go search
go tool trace trace.out
```

### Logging and Monitoring
```bash
# Run with debug logging
./bin/apartment-hunt --log-level debug search

# Monitor file system changes
fswatch -o data/ | xargs -n1 echo "Data directory changed"

# Monitor network requests (if using proxy)
mitmproxy -s monitor_requests.py
```

## Performance Testing
```bash
# Load test the application
for i in {1..100}; do
    ./bin/apartment-hunt search &
done
wait

# Memory usage monitoring
valgrind ./bin/apartment-hunt search

# CPU usage monitoring
perf record ./bin/apartment-hunt search
perf report
```

## Continuous Integration

### GitHub Actions
```bash
# Trigger workflow manually
gh workflow run tests.yml

# View workflow status
gh workflow list
gh run list

# Download artifacts
gh run download <run-id>
```

### Local CI Simulation
```bash
# Simulate CI environment
docker run -v $(pwd):/workspace golang:1.21 \
    bash -c "cd /workspace && make ci"
```

## Troubleshooting Commands

### Common Issues
```bash
# Clean module cache
go clean -modcache

# Rebuild from scratch
make clean
rm -rf vendor/
go mod download
make build

# Check for dependency issues
go mod verify
go mod graph | grep apartment-hunt

# Fix import cycles
go list -deps ./... | sort | uniq -c | sort -nr

# Check for unused dependencies
go mod tidy
```

### Performance Issues
```bash
# Check goroutine leaks
go test -race ./...

# Profile memory usage
go test -memprofile=mem.prof ./...
go tool pprof mem.prof

# Check for inefficient allocations
go test -benchmem -run=^$ -bench . ./...
```

## IDE Integration

### VS Code
```bash
# Install Go extension
code --install-extension golang.go

# Configure workspace settings
cat > .vscode/settings.json << EOF
{
    "go.testFlags": ["-v"],
    "go.buildTags": "integration",
    "go.lintTool": "golangci-lint",
    "go.formatTool": "gofmt"
}
EOF
```

### Vim/Neovim
```bash
# Install vim-go
git clone https://github.com/fatih/vim-go.git ~/.vim/pack/plugins/start/vim-go

# Configure keybindings in .vimrc
echo 'autocmd FileType go nmap <Leader>t :GoTest<CR>' >> ~/.vimrc
echo 'autocmd FileType go nmap <Leader>b :GoBuild<CR>' >> ~/.vimrc
```