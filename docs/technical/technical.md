# Technical Considerations

## Dependencies

### Core Dependencies
```go
// CLI and Configuration
"github.com/spf13/cobra"           // CLI framework
"github.com/spf13/viper"           // Configuration management (optional)
"gopkg.in/yaml.v3"                 // YAML parsing

// HTTP and Web Scraping
"github.com/go-resty/resty/v2"     // HTTP client with built-in retry
"github.com/PuerkitoBio/goquery"   // HTML parsing and CSS selectors
"golang.org/x/net/html"            // Low-level HTML parsing
"golang.org/x/time/rate"           // Rate limiting

// Data Processing
"github.com/google/uuid"           // UUID generation
"github.com/go-playground/validator/v10" // Struct validation

// Container Orchestration
"github.com/docker/docker/client"  // Docker API client
"github.com/docker/docker/api/types" // Docker types
"google.golang.org/grpc"           // gRPC communication between containers
"google.golang.org/protobuf"       // Protocol buffers for service definitions

// Database
"github.com/lib/pq"                // PostgreSQL driver
"github.com/jackc/pgx/v5"          // PostgreSQL driver and toolkit
"github.com/jackc/pgx/v5/pgxpool"  // Connection pooling
"github.com/pressly/goose/v3"      // Database migrations
"github.com/jmoiron/sqlx"          // SQL extensions for enhanced querying

// Testing Dependencies
"github.com/stretchr/testify"      // Test assertions and mocking
"github.com/h2non/gock"            // HTTP mocking for tests
"github.com/golang/mock"           // Interface mocking
"github.com/testcontainers/testcontainers-go" // Container testing

// Optional Enhancements
"github.com/chromedp/chromedp"     // JavaScript rendering (for SPAs)
"github.com/elastic/go-elasticsearch/v8" // Search (if scaling)
"github.com/sirupsen/logrus"       // Structured logging
"github.com/prometheus/client_golang" // Metrics collection
```

### Dependency Management Strategy
- **Minimal Dependencies**: Only add dependencies when they provide significant value
- **Version Pinning**: Pin major versions, allow minor/patch updates
- **Security Updates**: Regularly check for vulnerabilities with `go list -m -u all`
- **Licensing**: Ensure all dependencies have compatible licenses

```bash
# Check for vulnerabilities
go list -m -u all | grep -v "go.mod"

# Audit dependencies
go mod download
go list -m all | xargs go list -m -u

# Update dependencies safely
go get -u=patch ./...  # Patch updates only
go get -u=minor ./...  # Minor updates
```

## Rate Limiting & Ethical Considerations

### Rate Limiting Implementation
```go
type RateLimiter struct {
    limiter map[string]*rate.Limiter
    mutex   sync.RWMutex
    config  RateLimitConfig
}

type RateLimitConfig struct {
    RequestsPerSecond map[string]int // source -> rate limit
    BurstSize        map[string]int // source -> burst size
    BackoffStrategy  BackoffStrategy
}

type BackoffStrategy struct {
    InitialDelay time.Duration
    MaxDelay     time.Duration
    Multiplier   float64
    MaxRetries   int
}

func (rl *RateLimiter) Allow(source string) bool {
    rl.mutex.RLock()
    limiter, exists := rl.limiter[source]
    rl.mutex.RUnlock()
    
    if !exists {
        rl.mutex.Lock()
        // Create rate limiter for new source
        rate := rate.Limit(rl.config.RequestsPerSecond[source])
        burst := rl.config.BurstSize[source]
        rl.limiter[source] = rate.NewLimiter(rate, burst)
        limiter = rl.limiter[source]
        rl.mutex.Unlock()
    }
    
    return limiter.Allow()
}
```

### Ethical Scraping Guidelines
1. **Respect robots.txt**: Check and honor robots.txt files
2. **Rate Limiting**: Don't overwhelm servers with requests
3. **User-Agent**: Use descriptive, identifiable user-agent strings
4. **Caching**: Minimize redundant requests through aggressive caching
5. **Legal Compliance**: Ensure scraping complies with Terms of Service

```go
// Robots.txt checker
type RobotsChecker struct {
    cache map[string]*robotstxt.RobotsData
    mutex sync.RWMutex
}

func (rc *RobotsChecker) CanFetch(userAgent, url string) (bool, error) {
    parsedURL, err := neturl.Parse(url)
    if err != nil {
        return false, err
    }
    
    robotsURL := parsedURL.Scheme + "://" + parsedURL.Host + "/robots.txt"
    
    rc.mutex.RLock()
    robots, exists := rc.cache[robotsURL]
    rc.mutex.RUnlock()
    
    if !exists {
        // Fetch and parse robots.txt
        robots, err = rc.fetchRobotsTxt(robotsURL)
        if err != nil {
            // If robots.txt is not accessible, assume allowed
            return true, nil
        }
        
        rc.mutex.Lock()
        rc.cache[robotsURL] = robots
        rc.mutex.Unlock()
    }
    
    return robots.TestAgent(parsedURL.Path, userAgent), nil
}
```

### Request Configuration
```go
type HTTPConfig struct {
    UserAgent       string
    Timeout         time.Duration
    MaxRetries      int
    RetryDelay      time.Duration
    FollowRedirects bool
    ProxyURL        string
    Headers         map[string]string
}

// Per-source configurations
var sourceConfigs = map[string]HTTPConfig{
    "craigslist": {
        UserAgent:       "apartment-hunt/1.0 (+https://github.com/user/apartment-hunt)",
        Timeout:         30 * time.Second,
        MaxRetries:      3,
        RetryDelay:      2 * time.Second,
        FollowRedirects: true,
    },
    "zillow": {
        UserAgent:  "apartment-hunt/1.0",
        Timeout:    45 * time.Second,
        MaxRetries: 2,
        RetryDelay: 5 * time.Second,
    },
}
```

## Error Handling Strategy

### Error Types Hierarchy
```go
// Base error types
type AppError struct {
    Code    string    `json:"code"`
    Message string    `json:"message"`
    Details string    `json:"details,omitempty"`
    Time    time.Time `json:"time"`
    Context map[string]interface{} `json:"context,omitempty"`
}

func (e *AppError) Error() string {
    return fmt.Sprintf("[%s] %s: %s", e.Code, e.Message, e.Details)
}

// Domain-specific errors
type ValidationError struct {
    *AppError
    Field string `json:"field"`
    Value interface{} `json:"value"`
}

type ScrapingError struct {
    *AppError
    Source string `json:"source"`
    URL    string `json:"url"`
    Status int    `json:"status,omitempty"`
}

type StorageError struct {
    *AppError
    Operation string `json:"operation"`
    Path      string `json:"path"`
}

type CacheError struct {
    *AppError
    CacheKey string `json:"cache_key"`
}
```

### Error Recovery Strategies
```go
type ErrorHandler struct {
    logger     *slog.Logger
    metrics    *Metrics
    retryLogic RetryLogic
}

func (eh *ErrorHandler) Handle(err error, ctx context.Context) error {
    switch e := err.(type) {
    case *ScrapingError:
        return eh.handleScrapingError(e, ctx)
    case *StorageError:
        return eh.handleStorageError(e, ctx)
    case *ValidationError:
        return eh.handleValidationError(e, ctx)
    default:
        return eh.handleGenericError(err, ctx)
    }
}

func (eh *ErrorHandler) handleScrapingError(err *ScrapingError, ctx context.Context) error {
    eh.metrics.IncrementError("scraping", err.Source)
    
    // Log error with context
    eh.logger.Error("Scraping failed",
        "source", err.Source,
        "url", err.URL,
        "status", err.Status,
        "error", err.Details)
    
    // Determine if retry is appropriate
    if err.Status >= 500 || err.Status == 429 { // Server errors or rate limiting
        if eh.retryLogic.ShouldRetry(err.Source) {
            delay := eh.retryLogic.GetDelay(err.Source)
            eh.logger.Info("Scheduling retry", "delay", delay)
            return &RetryableError{
                OriginalError: err,
                RetryAfter:    time.Now().Add(delay),
            }
        }
    }
    
    // For 4xx errors, mark source as temporarily unavailable
    if err.Status >= 400 && err.Status < 500 {
        eh.markSourceUnavailable(err.Source, 1*time.Hour)
    }
    
    return err
}
```

### Circuit Breaker Pattern
```go
type CircuitBreaker struct {
    name         string
    threshold    int
    timeout      time.Duration
    failures     int
    lastFailure  time.Time
    state        CircuitState
    mutex        sync.RWMutex
}

type CircuitState int

const (
    Closed CircuitState = iota
    Open
    HalfOpen
)

func (cb *CircuitBreaker) Call(fn func() error) error {
    cb.mutex.Lock()
    defer cb.mutex.Unlock()
    
    if cb.state == Open {
        if time.Since(cb.lastFailure) > cb.timeout {
            cb.state = HalfOpen
        } else {
            return fmt.Errorf("circuit breaker is open for %s", cb.name)
        }
    }
    
    err := fn()
    
    if err != nil {
        cb.failures++
        cb.lastFailure = time.Now()
        
        if cb.failures >= cb.threshold {
            cb.state = Open
        }
        return err
    }
    
    // Success - reset circuit breaker
    cb.failures = 0
    cb.state = Closed
    return nil
}
```

## Performance Optimization

### Memory Management
```go
// Object pooling for frequently allocated objects
var apartmentPool = sync.Pool{
    New: func() interface{} {
        return &models.Apartment{}
    },
}

func GetApartment() *models.Apartment {
    apt := apartmentPool.Get().(*models.Apartment)
    // Reset fields
    *apt = models.Apartment{}
    return apt
}

func PutApartment(apt *models.Apartment) {
    apartmentPool.Put(apt)
}

// String builder pooling
var stringBuilderPool = sync.Pool{
    New: func() interface{} {
        return &strings.Builder{}
    },
}
```

### Concurrent Processing
```go
type WorkerPool struct {
    workers    int
    jobs       chan Job
    results    chan Result
    wg         sync.WaitGroup
    ctx        context.Context
    cancel     context.CancelFunc
}

type Job struct {
    ID   string
    URL  string
    Data interface{}
}

type Result struct {
    Job       Job
    Apartment *models.Apartment
    Error     error
}

func NewWorkerPool(workers int) *WorkerPool {
    ctx, cancel := context.WithCancel(context.Background())
    return &WorkerPool{
        workers: workers,
        jobs:    make(chan Job, workers*2),
        results: make(chan Result, workers*2),
        ctx:     ctx,
        cancel:  cancel,
    }
}

func (wp *WorkerPool) Start() {
    for i := 0; i < wp.workers; i++ {
        wp.wg.Add(1)
        go wp.worker()
    }
}

func (wp *WorkerPool) worker() {
    defer wp.wg.Done()
    
    for {
        select {
        case job := <-wp.jobs:
            result := wp.processJob(job)
            select {
            case wp.results <- result:
            case <-wp.ctx.Done():
                return
            }
        case <-wp.ctx.Done():
            return
        }
    }
}
```

### Caching Strategies
```go
// Multi-level caching
type CacheLayer struct {
    memory    *MemoryCache
    disk      *DiskCache
    ttl       time.Duration
    maxSize   int64
}

func (cl *CacheLayer) Get(key string) (interface{}, bool) {
    // Check memory cache first
    if value, exists := cl.memory.Get(key); exists {
        return value, true
    }
    
    // Check disk cache
    if value, exists := cl.disk.Get(key); exists {
        // Promote to memory cache
        cl.memory.Set(key, value, cl.ttl)
        return value, true
    }
    
    return nil, false
}

func (cl *CacheLayer) Set(key string, value interface{}) {
    // Set in both layers
    cl.memory.Set(key, value, cl.ttl)
    cl.disk.Set(key, value, cl.ttl)
}
```

## Security Considerations

### Input Validation
```go
// Sanitize user inputs
func SanitizeSearchQuery(query string) string {
    // Remove potentially dangerous characters
    query = regexp.MustCompile(`[<>'"&]`).ReplaceAllString(query, "")
    
    // Limit length
    if len(query) > 1000 {
        query = query[:1000]
    }
    
    return strings.TrimSpace(query)
}

// Validate URLs
func ValidateURL(url string) error {
    parsedURL, err := neturl.Parse(url)
    if err != nil {
        return fmt.Errorf("invalid URL: %w", err)
    }
    
    // Only allow HTTP/HTTPS
    if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
        return fmt.Errorf("unsupported URL scheme: %s", parsedURL.Scheme)
    }
    
    // Validate hostname
    if parsedURL.Host == "" {
        return fmt.Errorf("missing hostname")
    }
    
    return nil
}
```

### Secrets Management
```go
// Never log sensitive data
type SafeURL struct {
    url.URL
}

func (s SafeURL) String() string {
    // Remove query parameters that might contain sensitive data
    u := s.URL
    u.RawQuery = ""
    return u.String()
}

// Configuration with sensitive data
type Config struct {
    APIKeys map[string]string `yaml:"api_keys" json:"-"` // Exclude from JSON
    Proxies []ProxyConfig     `yaml:"proxies" json:"-"`
}

func (c *Config) Redacted() *Config {
    redacted := *c
    redacted.APIKeys = make(map[string]string)
    for k := range c.APIKeys {
        redacted.APIKeys[k] = "***REDACTED***"
    }
    return &redacted
}
```

### File System Security
```go
// Secure file operations
func SecureWriteFile(filename string, data []byte) error {
    // Validate filename
    if err := validateFilename(filename); err != nil {
        return err
    }
    
    // Create temp file with restricted permissions
    tempFile, err := os.CreateTemp(filepath.Dir(filename), ".tmp-")
    if err != nil {
        return err
    }
    defer os.Remove(tempFile.Name())
    
    // Set restrictive permissions
    if err := tempFile.Chmod(0600); err != nil {
        return err
    }
    
    // Write data
    if _, err := tempFile.Write(data); err != nil {
        return err
    }
    
    // Sync to disk
    if err := tempFile.Sync(); err != nil {
        return err
    }
    
    // Close and atomically rename
    if err := tempFile.Close(); err != nil {
        return err
    }
    
    return os.Rename(tempFile.Name(), filename)
}

func validateFilename(filename string) error {
    // Prevent path traversal
    if strings.Contains(filename, "..") {
        return fmt.Errorf("path traversal detected")
    }
    
    // Ensure filename is within allowed directory
    absPath, err := filepath.Abs(filename)
    if err != nil {
        return err
    }
    
    allowedDir, err := filepath.Abs("./data")
    if err != nil {
        return err
    }
    
    if !strings.HasPrefix(absPath, allowedDir) {
        return fmt.Errorf("file outside allowed directory")
    }
    
    return nil
}
```

## Monitoring and Observability

### Structured Logging
```go
type Logger struct {
    *slog.Logger
    fields map[string]interface{}
}

func NewLogger() *Logger {
    handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: slog.LevelInfo,
    })
    
    return &Logger{
        Logger: slog.New(handler),
        fields: make(map[string]interface{}),
    }
}

func (l *Logger) WithField(key string, value interface{}) *Logger {
    newFields := make(map[string]interface{})
    for k, v := range l.fields {
        newFields[k] = v
    }
    newFields[key] = value
    
    return &Logger{
        Logger: l.Logger,
        fields: newFields,
    }
}

func (l *Logger) Info(msg string) {
    attrs := make([]slog.Attr, 0, len(l.fields))
    for k, v := range l.fields {
        attrs = append(attrs, slog.Any(k, v))
    }
    l.Logger.LogAttrs(context.Background(), slog.LevelInfo, msg, attrs...)
}
```

### Metrics Collection
```go
type Metrics struct {
    scrapingDuration   *prometheus.HistogramVec
    cacheHits         *prometheus.CounterVec
    errorCount        *prometheus.CounterVec
    listingsProcessed *prometheus.CounterVec
}

func NewMetrics() *Metrics {
    return &Metrics{
        scrapingDuration: prometheus.NewHistogramVec(
            prometheus.HistogramOpts{
                Name: "apartment_hunt_scraping_duration_seconds",
                Help: "Time spent scraping by source",
            },
            []string{"source"},
        ),
        cacheHits: prometheus.NewCounterVec(
            prometheus.CounterOpts{
                Name: "apartment_hunt_cache_hits_total",
                Help: "Number of cache hits",
            },
            []string{"type"},
        ),
        errorCount: prometheus.NewCounterVec(
            prometheus.CounterOpts{
                Name: "apartment_hunt_errors_total",
                Help: "Number of errors by type",
            },
            []string{"type", "source"},
        ),
    }
}

func (m *Metrics) RecordScrapingDuration(source string, duration time.Duration) {
    m.scrapingDuration.WithLabelValues(source).Observe(duration.Seconds())
}
```

## Deployment Considerations

### Configuration Management
```yaml
# Production configuration
production:
  storage:
    data_dir: "/var/lib/apartment-hunt"
    enable_cache: true
    cache_size: 10000
  
  scrapers:
    rate_limit:
      requests_per_second: 2
      burst: 5
    timeout: 60
    user_agent: "apartment-hunt/1.0 (+https://example.com/contact)"
  
  logging:
    level: "info"
    format: "json"
    output: "/var/log/apartment-hunt/app.log"
  
  monitoring:
    enable_metrics: true
    metrics_port: 9090
```

### Docker Infrastructure Requirements

#### Microservices Architecture
The application uses a containerized microservices architecture with dynamic container management:

- **Primary Controller Container**: Central orchestration, task management, and progress tracking
- **Storage Container**: Centralized data persistence and multi-source deduplication cache
- **Scraper Containers**: Dynamically spawned per data source with API-first approach
- **CLI Container**: Interactive command-line interface with hyperlink support

#### Container Communication
- **gRPC**: Inter-service communication with defined protobuf schemas
- **Docker Socket Access**: Controller container manages scraper containers via Docker API
- **Shared Networks**: All containers communicate via dedicated Docker network
- **Volume Mounts**: Persistent data storage shared between controller and storage containers

#### Resource Management
- **Dynamic Scaling**: Scraper containers started/stopped based on task requirements
- **Resource Limits**: Memory and CPU constraints per container type
- **Health Monitoring**: gRPC health checks and automatic container restart
- **Efficient Threading**: Multiple containers enable parallel processing across sources

#### Multi-Source Deduplication Strategy
- **Container Coordination**: Storage container manages deduplication across all scraper sources
- **Attribute Matching**: Listings deduplicated based on apartment attributes (not just identifiers)
- **Content Hashing**: Different sources with same listing detected via content hash comparison
- **Address Normalization**: Geographic matching handles address variations between sources
- **Availability Tracking**: Coordinated availability checks across multiple sources per listing

#### Data Source Management
- **API-First Approach**: Each scraper container prefers API access when available
- **Web Scraping Fallback**: Automatic fallback to web scraping when APIs unavailable
- **Terms of Service Compliance**: Per-source robots.txt checking and rate limiting
- **Source Selection**: CLI container provides hyperlinks with multiple source options

#### Container Configurations

##### Controller Container
```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o controller cmd/controller/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates docker-cli grpc-health-probe
WORKDIR /app

COPY --from=builder /app/controller .

# Create non-root user with Docker access
RUN addgroup -g 1001 -S apartment && \
    adduser -u 1001 -S apartment -G apartment -G docker

USER apartment

EXPOSE 9000 8080

CMD ["./controller"]
```

##### Storage Container
```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o storage cmd/storage/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates grpc-health-probe
WORKDIR /app

COPY --from=builder /app/storage .

# Create data directory with proper permissions
RUN mkdir -p /app/data && \
    addgroup -g 1001 -S apartment && \
    adduser -u 1001 -S apartment -G apartment && \
    chown -R apartment:apartment /app

USER apartment

EXPOSE 9001

CMD ["./storage"]
```

##### Scraper Container (Dynamically Spawned)
```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o scraper cmd/scraper/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates chromium grpc-health-probe
WORKDIR /app

COPY --from=builder /app/scraper .

# Create non-root user
RUN addgroup -g 1001 -S apartment && \
    adduser -u 1001 -S apartment -G apartment

USER apartment

ENV CHROME_BIN=/usr/bin/chromium-browser

EXPOSE 9002

CMD ["./scraper"]
```

#### Database Container (Cloud Native PostgreSQL)
```yaml
# database/cnpg/cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: apartment-hunt-postgres
spec:
  instances: 1  # Single instance for development, can be scaled for production
  
  postgresql:
    parameters:
      max_connections: "100"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      maintenance_work_mem: "64MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"
      effective_io_concurrency: "200"
  
  bootstrap:
    initdb:
      database: apartment_hunt
      owner: apartment_user
      secret:
        name: postgres-credentials
  
  storage:
    size: 20Gi
    storageClass: "standard"
  
  monitoring:
    enabled: true
    
  backup:
    barmanObjectStore:
      destinationPath: "s3://apartment-hunt-backups/postgres"
      s3Credentials:
        accessKeyId:
          name: backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-credentials
          key: SECRET_ACCESS_KEY
      wal:
        retention: "7d"
      data:
        retention: "30d"
```

#### Database Connection Configuration
```go
type DatabaseConfig struct {
    Host     string `yaml:"host" env:"DB_HOST"`
    Port     int    `yaml:"port" env:"DB_PORT"`
    Database string `yaml:"database" env:"DB_NAME"`
    User     string `yaml:"user" env:"DB_USER"`
    Password string `yaml:"password" env:"DB_PASSWORD"`
    SSLMode  string `yaml:"ssl_mode" env:"DB_SSL_MODE"`
    
    // Connection pooling
    MaxOpenConns    int           `yaml:"max_open_conns" env:"DB_MAX_OPEN_CONNS"`
    MaxIdleConns    int           `yaml:"max_idle_conns" env:"DB_MAX_IDLE_CONNS"`
    ConnMaxLifetime time.Duration `yaml:"conn_max_lifetime" env:"DB_CONN_MAX_LIFETIME"`
    ConnMaxIdleTime time.Duration `yaml:"conn_max_idle_time" env:"DB_CONN_MAX_IDLE_TIME"`
}

func NewDatabaseConnection(config DatabaseConfig) (*pgxpool.Pool, error) {
    dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
        config.Host, config.Port, config.User, config.Password, config.Database, config.SSLMode)
    
    poolConfig, err := pgxpool.ParseConfig(dsn)
    if err != nil {
        return nil, fmt.Errorf("failed to parse database config: %w", err)
    }
    
    // Configure connection pool
    poolConfig.MaxConns = int32(config.MaxOpenConns)
    poolConfig.MinConns = int32(config.MaxIdleConns)
    poolConfig.MaxConnLifetime = config.ConnMaxLifetime
    poolConfig.MaxConnIdleTime = config.ConnMaxIdleTime
    
    pool, err := pgxpool.NewWithConfig(context.Background(), poolConfig)
    if err != nil {
        return nil, fmt.Errorf("failed to create connection pool: %w", err)
    }
    
    return pool, nil
}
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apartment-hunt
spec:
  replicas: 3
  selector:
    matchLabels:
      app: apartment-hunt
  template:
    metadata:
      labels:
        app: apartment-hunt
    spec:
      containers:
      - name: apartment-hunt
        image: apartment-hunt:latest
        ports:
        - containerPort: 8080
        - containerPort: 9090
        env:
        - name: APARTMENT_HUNT_DATA_DIR
          value: "/app/data"
        - name: APARTMENT_HUNT_LOG_LEVEL
          value: "info"
        volumeMounts:
        - name: data-volume
          mountPath: /app/data
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: apartment-hunt-pvc
```

### Scaling Considerations
- **Horizontal Scaling**: Multiple instances can run with shared storage
- **Caching**: Distributed cache (Redis) for large deployments
- **Database**: Migrate to PostgreSQL/MongoDB for complex queries
- **Search**: Elasticsearch for advanced search capabilities
- **Monitoring**: Prometheus + Grafana for comprehensive monitoring