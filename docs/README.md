# Documentation Index

This directory contains all project documentation organized by category for easy navigation.

## Quick Navigation

### 📋 Planning Documents
Strategic planning, architecture design, and implementation phases.

- **[Architecture Overview](planning/architecture.md)** - Complete system design and structure
- **[Docker Orchestration](planning/docker-orchestration.md)** - Container architecture and microservices
- **[Data Models](planning/data-models.md)** - Data structures, validation, and relationships
- **[Caching Strategy](planning/caching.md)** - Multi-source deduplication and storage
- **[Phase 1: Core Infrastructure](planning/phase1-core.md)** - Initial implementation roadmap

### 🔧 Technical Documentation
Implementation guides, methodology, and development workflows.

- **[TDD Methodology](technical/tdd.md)** - Test-driven development approach
- **[Technical Considerations](technical/technical.md)** - Dependencies, security, deployment
- **[Development Commands](technical/commands.md)** - Build, test, and deployment workflows
- **[Database Migrations](technical/database-migrations.md)** - Migration strategy and version control

### 📝 Requirements & Tasking
Project requirements, specifications, and task definitions.

- **[Original Requirements](tasking/apartment-hunt-tasking.md)** - Initial project scope and goals
- **[Docker Architecture Requirements](tasking/tasking-mk-2.md)** - Microservices specifications
- **[Structure Reorganization](tasking/t3.md)** - File organization requirements
- **[Database Requirements](tasking/t4.md)** - PostgreSQL integration and persistence
- **[Multi-User Support](tasking/t5.md)** - User management and preference tracking

## Cross-References

### Service Architecture
- [Container Communication Flow](planning/docker-orchestration.md#container-communication-flow)
- [Microservices Architecture Diagram](planning/architecture.md#microservices-architecture)
- [Service Dependencies](technical/technical.md#core-dependencies)

### Data Flow
- [Multi-Source Deduplication](planning/data-models/cache-entries.md)
- [Cache Strategy](planning/caching.md)
- [User Data Separation](planning/data-models.md#multi-user-architecture)
- [Data Privacy](planning/data-models.md#data-privacy-and-security)

### Development Workflow
- [TDD Implementation](technical/tdd.md#implementation-workflow)
- [Build Commands](technical/commands.md)
- [Testing Strategy](technical/tdd.md#testing-strategy)

## Document Conventions

- **Planning**: High-level design and strategic decisions
- **Technical**: Implementation details and development practices
- **Tasking**: Requirements, specifications, and task definitions

Each document is self-contained but includes cross-references for related concepts.