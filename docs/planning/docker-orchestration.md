# Docker Orchestration & Container Architecture

> **Related Documents:**
> - [System Architecture](architecture.md) - Overall project structure  
> - [Technical Requirements](../tasking/tasking-mk-2.md) - Docker specifications
> - [Technical Implementation](../technical/technical.md) - Infrastructure dependencies
> - [Back to Documentation Index](../README.md)

## Overview

The apartment hunting application uses a microservices architecture with Docker containers to separate concerns and enable efficient resource management. The primary controller container manages peripheral containers for scraping, storage, and user interaction.

## Container Architecture

### Primary Controller Container
**Role**: Central orchestration, task management, and progress tracking
**Responsibilities**:
- Start and stop peripheral containers as needed
- Distribute scraping tasks across scraper containers
- Monitor progress and health of all containers
- Coordinate data flow between containers
- Manage resource allocation and scaling

### Storage Container
**Role**: Centralized data persistence and caching
**Responsibilities**:
- File-based storage management
- Multi-source deduplication cache
- Data validation and normalization
- Availability status tracking
- Archive management for unavailable listings

### Scraper Containers
**Role**: Source-specific data extraction (dynamically spawned)
**Responsibilities**:
- API-first data extraction with web scraping fallback
- Availability verification
- Rate limiting and ethical scraping compliance
- Error handling and retry logic
- Progress reporting to controller

### CLI Container
**Role**: User interface and interaction
**Responsibilities**:
- Command-line interface with hyperlinks
- Multi-source selection UI
- Preference management
- Result presentation and formatting
- User feedback collection

## Container Communication

### gRPC Service Definitions

#### Controller Service
```protobuf
syntax = "proto3";

package controller;

service ControllerService {
    rpc StartTask(TaskRequest) returns (TaskResponse);
    rpc GetProgress(ProgressRequest) returns (ProgressResponse);
    rpc StopTask(StopRequest) returns (StopResponse);
    rpc GetContainerStatus(StatusRequest) returns (StatusResponse);
    rpc ManageContainer(ContainerRequest) returns (ContainerResponse);
}

message TaskRequest {
    string task_id = 1;
    string task_type = 2; // "scrape", "availability_check", "search"
    map<string, string> parameters = 3;
    repeated string sources = 4;
}

message TaskResponse {
    string task_id = 1;
    bool success = 2;
    string message = 3;
    map<string, string> container_assignments = 4;
}

message ProgressRequest {
    string task_id = 1;
}

message ProgressResponse {
    string task_id = 1;
    float completion_percentage = 2;
    int32 items_processed = 3;
    int32 items_total = 4;
    repeated ContainerProgress container_progress = 5;
    string status = 6;
}

message ContainerProgress {
    string container_id = 1;
    string source = 2;
    float progress = 3;
    string current_operation = 4;
    string status = 5;
}
```

#### Scraper Service
```protobuf
syntax = "proto3";

package scraper;

service ScraperService {
    rpc Scrape(ScrapeRequest) returns (stream ScrapeResponse);
    rpc CheckAvailability(AvailabilityRequest) returns (AvailabilityResponse);
    rpc GetCapabilities(CapabilitiesRequest) returns (CapabilitiesResponse);
    rpc Ping(PingRequest) returns (PingResponse);
}

message ScrapeRequest {
    string source = 1;
    map<string, string> search_parameters = 2;
    bool use_api = 3;
    string user_agent = 4;
    int32 rate_limit = 5;
}

message ScrapeResponse {
    string listing_id = 1;
    string raw_data = 2;
    string data_format = 3; // "json", "html"
    bool success = 4;
    string error = 5;
    float progress = 6;
}

message AvailabilityRequest {
    string listing_url = 1;
    string source = 2;
    string method = 3; // "api", "scrape", "http_check"
}

message AvailabilityResponse {
    string status = 1; // "available", "unavailable", "unknown"
    string method_used = 2;
    string details = 3;
    string error = 4;
}
```

#### Storage Service
```protobuf
syntax = "proto3";

package storage;

service StorageService {
    rpc Store(StoreRequest) returns (StoreResponse);
    rpc Load(LoadRequest) returns (LoadResponse);
    rpc Query(QueryRequest) returns (stream QueryResponse);
    rpc CheckDuplicate(DuplicateRequest) returns (DuplicateResponse);
    rpc UpdateAvailability(AvailabilityUpdateRequest) returns (AvailabilityUpdateResponse);
}

message StoreRequest {
    string listing_data = 1;
    string data_format = 2;
    string source = 3;
    bool force_update = 4;
}

message StoreResponse {
    string listing_id = 1;
    bool is_duplicate = 2;
    string existing_id = 3;
    bool success = 4;
    string error = 5;
}

message DuplicateRequest {
    string content_hash = 1;
    string address_hash = 2;
    string url = 3;
}

message DuplicateResponse {
    bool is_duplicate = 1;
    string existing_id = 2;
    repeated string matching_sources = 3;
}
```

## Docker Compose Configuration

### Development Environment
```yaml
# docker-compose.yml
version: '3.8'

services:
  controller:
    build:
      context: .
      dockerfile: deployments/docker/Dockerfile.controller
    container_name: apartment-hunt-controller
    environment:
      - APARTMENT_HUNT_MODE=controller
      - APARTMENT_HUNT_LOG_LEVEL=debug
      - STORAGE_SERVICE_URL=storage:9001
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - ./config:/app/config
    ports:
      - "9000:9000"  # gRPC
      - "8080:8080"  # HTTP metrics
    depends_on:
      - storage
    networks:
      - apartment-hunt-network

  storage:
    build:
      context: .
      dockerfile: deployments/docker/Dockerfile.storage
    container_name: apartment-hunt-storage
    environment:
      - APARTMENT_HUNT_MODE=storage
      - APARTMENT_HUNT_DATA_DIR=/app/data
      - APARTMENT_HUNT_LOG_LEVEL=info
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=apartment_hunt
      - DB_USER=apartment_user
      - DB_PASSWORD=apartment_password
      - DB_SSL_MODE=disable
    volumes:
      - ./data:/app/data:rw
      - ./config:/app/config:ro
    ports:
      - "9001:9001"  # gRPC
    depends_on:
      - postgres
    networks:
      - apartment-hunt-network

  postgres:
    image: postgres:15-alpine
    container_name: apartment-hunt-postgres
    environment:
      - POSTGRES_DB=apartment_hunt
      - POSTGRES_USER=apartment_user
      - POSTGRES_PASSWORD=apartment_password
      - POSTGRES_INITDB_ARGS=--encoding=UTF-8 --lc-collate=C --lc-ctype=C
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./database/migrations:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    networks:
      - apartment-hunt-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U apartment_user -d apartment_hunt"]
      interval: 30s
      timeout: 10s
      retries: 3

  cli:
    build:
      context: .
      dockerfile: deployments/docker/Dockerfile.cli
    container_name: apartment-hunt-cli
    environment:
      - APARTMENT_HUNT_MODE=cli
      - CONTROLLER_SERVICE_URL=controller:9000
    volumes:
      - ./config:/app/config:ro
    stdin_open: true
    tty: true
    depends_on:
      - controller
    networks:
      - apartment-hunt-network

  # Scraper containers are dynamically created by controller
  # Template for manual testing:
  scraper-craigslist:
    build:
      context: .
      dockerfile: deployments/docker/Dockerfile.scraper
    environment:
      - APARTMENT_HUNT_MODE=scraper
      - APARTMENT_HUNT_SOURCE=craigslist
      - APARTMENT_HUNT_LOG_LEVEL=info
      - CONTROLLER_SERVICE_URL=controller:9000
    profiles:
      - manual-testing
    networks:
      - apartment-hunt-network

networks:
  apartment-hunt-network:
    driver: bridge

volumes:
  apartment-hunt-data:
    driver: local
  postgres-data:
    driver: local
```

### Production Environment
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  controller:
    build:
      context: .
      dockerfile: deployments/docker/Dockerfile.controller
      target: production
    restart: unless-stopped
    environment:
      - APARTMENT_HUNT_MODE=controller
      - APARTMENT_HUNT_LOG_LEVEL=info
      - STORAGE_SERVICE_URL=storage:9001
      - MAX_SCRAPER_CONTAINERS=5
      - CONTAINER_MEMORY_LIMIT=512m
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - apartment-hunt-data:/app/data
      - ./config/production.yaml:/app/config/config.yaml:ro
    ports:
      - "9000:9000"
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'
    healthcheck:
      test: ["CMD", "grpc_health_probe", "-addr=:9000"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - apartment-hunt-network
    depends_on:
      storage:
        condition: service_healthy

  storage:
    build:
      context: .
      dockerfile: deployments/docker/Dockerfile.storage
      target: production
    restart: unless-stopped
    environment:
      - APARTMENT_HUNT_MODE=storage
      - APARTMENT_HUNT_DATA_DIR=/app/data
      - APARTMENT_HUNT_LOG_LEVEL=info
      - APARTMENT_HUNT_CACHE_SIZE=10000
    volumes:
      - apartment-hunt-data:/app/data
      - ./config/production.yaml:/app/config/config.yaml:ro
    ports:
      - "9001:9001"
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
    healthcheck:
      test: ["CMD", "grpc_health_probe", "-addr=:9001"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - apartment-hunt-network

networks:
  apartment-hunt-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  apartment-hunt-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/apartment-hunt/data
```

## Dockerfiles

### Controller Container
```dockerfile
# deployments/docker/Dockerfile.controller
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o controller cmd/controller/main.go

FROM alpine:latest AS production

RUN apk --no-cache add ca-certificates docker-cli grpc-health-probe
WORKDIR /app

COPY --from=builder /app/controller .
COPY --from=builder /app/config ./config

# Create non-root user
RUN addgroup -g 1001 -S apartment && \
    adduser -u 1001 -S apartment -G apartment -G docker

USER apartment

EXPOSE 9000 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD grpc_health_probe -addr=:9000

CMD ["./controller"]
```

### Storage Container
```dockerfile
# deployments/docker/Dockerfile.storage
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o storage cmd/storage/main.go

FROM alpine:latest AS production

RUN apk --no-cache add ca-certificates grpc-health-probe
WORKDIR /app

COPY --from=builder /app/storage .

# Create data directory
RUN mkdir -p /app/data && \
    addgroup -g 1001 -S apartment && \
    adduser -u 1001 -S apartment -G apartment && \
    chown -R apartment:apartment /app

USER apartment

EXPOSE 9001

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD grpc_health_probe -addr=:9001

CMD ["./storage"]
```

### Scraper Container
```dockerfile
# deployments/docker/Dockerfile.scraper
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o scraper cmd/scraper/main.go

FROM alpine:latest AS production

RUN apk --no-cache add ca-certificates chromium grpc-health-probe
WORKDIR /app

COPY --from=builder /app/scraper .

# Create non-root user
RUN addgroup -g 1001 -S apartment && \
    adduser -u 1001 -S apartment -G apartment

USER apartment

ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/lib/chromium/

EXPOSE 9002

CMD ["./scraper"]
```

### CLI Container
```dockerfile
# deployments/docker/Dockerfile.cli
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o cli cmd/cli/main.go

FROM alpine:latest AS production

RUN apk --no-cache add ca-certificates
WORKDIR /app

COPY --from=builder /app/cli .

# Create non-root user
RUN addgroup -g 1001 -S apartment && \
    adduser -u 1001 -S apartment -G apartment

USER apartment

CMD ["./cli"]
```

## Container Orchestration Logic

### Controller Container Management
```go
// internal/controller/orchestrator.go
type ContainerOrchestrator struct {
    dockerClient   *client.Client
    scraperImages  map[string]string
    activeContainers map[string]*ContainerInfo
    taskQueue      chan Task
    progressTracker *ProgressTracker
    logger         *slog.Logger
}

type ContainerInfo struct {
    ID            string
    Source        string
    Status        string
    LastHeartbeat time.Time
    TasksAssigned int
    TasksCompleted int
}

func (co *ContainerOrchestrator) StartScraperContainer(source string, config ScraperConfig) (*ContainerInfo, error) {
    ctx := context.Background()
    
    // Check if container already exists for this source
    if existing, exists := co.activeContainers[source]; exists {
        if existing.Status == "running" {
            return existing, nil
        }
    }
    
    // Create container configuration
    containerConfig := &container.Config{
        Image: co.scraperImages[source],
        Env: []string{
            fmt.Sprintf("APARTMENT_HUNT_SOURCE=%s", source),
            fmt.Sprintf("CONTROLLER_SERVICE_URL=%s", co.getControllerURL()),
            fmt.Sprintf("APARTMENT_HUNT_LOG_LEVEL=%s", config.LogLevel),
        },
        Labels: map[string]string{
            "apartment-hunt.component": "scraper",
            "apartment-hunt.source":    source,
            "apartment-hunt.managed":   "true",
        },
    }
    
    hostConfig := &container.HostConfig{
        NetworkMode: "apartment-hunt-network",
        Resources: container.Resources{
            Memory:   config.MemoryLimit,
            NanoCPUs: config.CPULimit,
        },
        RestartPolicy: container.RestartPolicy{
            Name: "unless-stopped",
        },
    }
    
    // Create and start container
    resp, err := co.dockerClient.ContainerCreate(ctx, containerConfig, hostConfig, nil, nil, "")
    if err != nil {
        return nil, fmt.Errorf("failed to create container: %w", err)
    }
    
    if err := co.dockerClient.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
        return nil, fmt.Errorf("failed to start container: %w", err)
    }
    
    // Wait for container to be ready
    if err := co.waitForContainerReady(resp.ID, 30*time.Second); err != nil {
        co.StopContainer(resp.ID)
        return nil, fmt.Errorf("container failed to become ready: %w", err)
    }
    
    containerInfo := &ContainerInfo{
        ID:            resp.ID,
        Source:        source,
        Status:        "running",
        LastHeartbeat: time.Now(),
    }
    
    co.activeContainers[source] = containerInfo
    co.logger.Info("Started scraper container", 
        "container_id", resp.ID, 
        "source", source)
    
    return containerInfo, nil
}

func (co *ContainerOrchestrator) StopContainer(containerID string) error {
    ctx := context.Background()
    
    // Graceful shutdown with timeout
    timeout := 30 * time.Second
    if err := co.dockerClient.ContainerStop(ctx, containerID, &timeout); err != nil {
        co.logger.Warn("Failed to stop container gracefully, forcing", 
            "container_id", containerID, 
            "error", err)
        
        // Force kill if graceful shutdown fails
        if err := co.dockerClient.ContainerKill(ctx, containerID, "SIGKILL"); err != nil {
            return fmt.Errorf("failed to kill container: %w", err)
        }
    }
    
    // Remove container
    if err := co.dockerClient.ContainerRemove(ctx, containerID, types.ContainerRemoveOptions{
        Force: true,
    }); err != nil {
        co.logger.Warn("Failed to remove container", 
            "container_id", containerID, 
            "error", err)
    }
    
    // Remove from active containers
    for source, info := range co.activeContainers {
        if info.ID == containerID {
            delete(co.activeContainers, source)
            break
        }
    }
    
    co.logger.Info("Stopped and removed container", "container_id", containerID)
    return nil
}

func (co *ContainerOrchestrator) ManageContainerLifecycle() {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ticker.C:
            co.performHealthChecks()
            co.scaleContainers()
            co.cleanupStaleContainers()
        }
    }
}

func (co *ContainerOrchestrator) performHealthChecks() {
    for source, containerInfo := range co.activeContainers {
        // Check container health via Docker API
        ctx := context.Background()
        inspect, err := co.dockerClient.ContainerInspect(ctx, containerInfo.ID)
        if err != nil {
            co.logger.Error("Failed to inspect container", 
                "container_id", containerInfo.ID, 
                "source", source, 
                "error", err)
            continue
        }
        
        // Update container status
        if inspect.State.Running {
            containerInfo.Status = "running"
            containerInfo.LastHeartbeat = time.Now()
        } else {
            containerInfo.Status = "stopped"
            co.logger.Warn("Container is not running", 
                "container_id", containerInfo.ID, 
                "source", source)
            
            // Attempt to restart
            if err := co.dockerClient.ContainerStart(ctx, containerInfo.ID, types.ContainerStartOptions{}); err != nil {
                co.logger.Error("Failed to restart container", 
                    "container_id", containerInfo.ID, 
                    "error", err)
                // Remove from active containers
                delete(co.activeContainers, source)
            }
        }
    }
}
```

## Development Workflow

### Local Development Commands
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f controller
docker-compose logs -f storage

# Scale scraper containers manually (for testing)
docker-compose up -d --scale scraper-craigslist=2

# Run CLI interactively
docker-compose run --rm cli

# Stop all services
docker-compose down

# Clean up volumes and networks
docker-compose down -v --remove-orphans
```

### Production Deployment
```bash
# Deploy production stack
docker-compose -f docker-compose.prod.yml up -d

# Monitor container health
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs --tail=100 -f

# Update containers (rolling update)
docker-compose -f docker-compose.prod.yml up -d --no-deps controller
docker-compose -f docker-compose.prod.yml up -d --no-deps storage

# Backup data volume
docker run --rm -v apartment-hunt-data:/data -v $(pwd):/backup alpine tar czf /backup/data-backup.tar.gz -C /data .

# Restore data volume
docker run --rm -v apartment-hunt-data:/data -v $(pwd):/backup alpine tar xzf /backup/data-backup.tar.gz -C /data
```

## Monitoring and Observability

### Health Checks
- All containers expose gRPC health check endpoints
- Controller monitors scraper container health
- Docker health checks for automatic restart
- Custom health metrics for business logic

### Logging Strategy
- Structured JSON logging across all containers
- Centralized log aggregation (optional ELK stack)
- Container-specific log levels
- Request tracing across service boundaries

### Metrics Collection
- Prometheus metrics endpoints
- Container resource usage monitoring
- Business metrics (listings processed, availability checks)
- Performance metrics (request latency, throughput)

### Container Resource Management
- Memory and CPU limits per container type
- Automatic scaling based on task queue depth
- Resource cleanup for terminated containers
- Disk space monitoring for data volume