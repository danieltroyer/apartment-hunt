# Apartment Hunt Makefile

.PHONY: build test test-unit test-integration test-coverage clean tdd docker-build docker-up docker-down

# Build targets
build:
	go build -o bin/apartment-hunt cmd/cli/main.go

build-all:
	go build -o bin/controller cmd/controller/main.go
	go build -o bin/scraper cmd/scraper/main.go
	go build -o bin/storage cmd/storage/main.go
	go build -o bin/cli cmd/cli/main.go

# Test targets
test:
	go test ./...

test-unit:
	go test -short ./...

test-integration:
	go test -tags=integration ./test/...

test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

test-race:
	go test -race ./...

test-bench:
	go test -bench=. ./...

# TDD workflow
tdd:
	@echo "Starting TDD workflow..."
	@echo "Run 'make test' after writing tests"

# Docker targets
docker-build:
	docker-compose -f deployments/docker/docker-compose.yml build

docker-up:
	docker-compose -f deployments/docker/docker-compose.yml up -d

docker-down:
	docker-compose -f deployments/docker/docker-compose.yml down

docker-logs:
	docker-compose -f deployments/docker/docker-compose.yml logs -f

# Development
clean:
	rm -rf bin/ coverage.out coverage.html
	go clean

deps:
	go mod download
	go mod tidy

lint:
	golangci-lint run

fmt:
	go fmt ./...

# Quick development cycle
dev: fmt test build

.DEFAULT_GOAL := build