# Apartment Hunt - Implementation Plan

## Overview
A Go-based apartment hunting application that aggregates listings from multiple sources, manages user preferences, and provides intelligent search refinement based on user feedback. The application uses a Docker-based microservices architecture with a primary controller managing peripheral containers for scraping, storage, and user interaction.

## Quick Start
This implementation plan is organized into modular documents for efficient development and context retrieval:

## Documentation Structure

### Planning Documents
- **[Architecture](docs/planning/architecture.md)** - Project structure, dependencies, and system design
- **[Docker Orchestration](docs/planning/docker-orchestration.md)** - Container architecture and microservices coordination
- **[Data Models Index](docs/planning/data-models.md)** - Central index of all data structures and relationships
- **[Caching Strategy](docs/planning/caching.md)** - Deduplication, storage, and refresh mechanisms
- **[Phase 1: Core Infrastructure](docs/planning/phase1-core.md)** - Project setup, models, storage

#### Data Model Documentation
- **[Users](docs/planning/data-models/users.md)** - User accounts and authentication
- **[User Preferences](docs/planning/data-models/user-preferences.md)** - Search criteria and filtering preferences  
- **[Listings](docs/planning/data-models/listings.md)** - Apartment listing data and metadata
- **[User Feedback](docs/planning/data-models/user-feedback.md)** - User opinions and ratings
- **[Cache Entries](docs/planning/data-models/cache-entries.md)** - Deduplication and caching metadata

#### Work Items & Development
- **[Work Items Index](docs/planning/work-items.md)** - Central index of all development work
- **[Epic Definitions](docs/planning/)** - Large-scale capability areas
- **[Feature Specifications](docs/planning/)** - Cohesive functionality sets
- **[User Story Definitions](docs/planning/)** - Specific testable work items

### Technical Documentation
- **[TDD Methodology](docs/technical/tdd.md)** - Testing approach, organization, and automation
- **[Technical Considerations](docs/technical/technical.md)** - Dependencies, ethics, deployment
- **[Development Commands](docs/technical/commands.md)** - Build, test, and deployment commands

### Requirements & Tasking
- **[Original Requirements](docs/tasking/apartment-hunt-tasking.md)** - Initial project requirements
- **[Updated Requirements](docs/tasking/tasking-mk-2.md)** - Docker architecture requirements
- **[Structure Reorganization](docs/tasking/t3.md)** - File organization requirements
- **[Database Requirements](docs/tasking/t4.md)** - PostgreSQL integration and data persistence
- **[Multi-User Support](docs/tasking/t5.md)** - User management and preference tracking
- **[Development Methodology](docs/tasking/t6.md)** - Epic/Feature/UserStory workflow and testing standards

## Development Approach

### Test-Driven Development
This project follows strict TDD methodology:
1. **Red**: Write failing tests first
2. **Green**: Write minimal code to pass tests
3. **Refactor**: Improve code while keeping tests green

See [TDD Methodology](docs/technical/tdd.md) for detailed testing strategies.

### Database-First Storage
All persistent data is stored in PostgreSQL with efficient indexing and querying:
- Listings, user preferences, and feedback in relational database
- Indexed fields for optimized search performance
- CNPG for cloud-native PostgreSQL deployment
- Version-controlled database migrations

See [Caching Strategy](docs/planning/caching.md) and [Database Requirements](docs/tasking/t4.md) for implementation details.

### Structured Development Workflow
Development follows a hierarchical Epic/Feature/UserStory methodology:
- **Epics**: Large-scale capabilities with business value
- **Features**: Cohesive functionality that can be built and tested
- **User Stories**: Specific, testable work items with acceptance criteria
- Work items organized in `docs/planning/[epic]/[feature]/[userStory].md` structure

See [Development Methodology](docs/tasking/t6.md) and [Work Items Index](docs/planning/work-items.md) for detailed workflow.

## Key Principles

1. **Respectful Scraping**: Rate limiting, robots.txt compliance, minimal requests
2. **Data Integrity**: Comprehensive validation and error handling  
3. **User Experience**: Interactive CLI with clear feedback and progress
4. **Maintainability**: Clean architecture with comprehensive test coverage
5. **Container Orchestration**: Microservices architecture with dynamic container management
6. **Multi-Source Deduplication**: Intelligent listing deduplication across different sources based on apartment attributes
7. **Cloud-Native Data Storage**: PostgreSQL with Cloud Native PostgreSQL (CNPG) for persistent data storage
8. **Efficient Data Access**: Indexed database schema optimized for search performance and query efficiency
9. **Multi-User Architecture**: Support for multiple users with individual preferences and progress tracking
10. **Data Separation**: User opinions and progress stored separately from listings for scalability
11. **Structured Development**: Epic/Feature/UserStory methodology with clear acceptance criteria
12. **Quality Assurance**: Comprehensive testing at unit, feature, and integration levels

## Getting Started

1. Review the [Architecture](docs/planning/architecture.md) for system overview
2. Start with [Phase 1](docs/planning/phase1-core.md) for initial implementation
3. Follow [TDD Methodology](docs/technical/tdd.md) for each feature
4. Refer to [Development Commands](docs/technical/commands.md) for workflow automation

## File Organization

```
apartment-hunt/
├── IMPLEMENTATION_PLAN.md          # This file - main index
├── CLAUDE.md                       # Claude Code guidance
├── docs/                           # Documentation organized by type
│   ├── planning/                   # Architecture and design documents
│   │   ├── architecture.md         # System design and structure
│   │   ├── data-models.md          # Data structures and validation
│   │   ├── caching.md              # Deduplication and storage
│   │   ├── docker-orchestration.md # Container architecture
│   │   └── phase1-core.md          # Implementation phases
│   ├── technical/                  # Technical implementation guides
│   │   ├── tdd.md                  # Testing methodology
│   │   ├── technical.md            # Dependencies and considerations
│   │   └── commands.md             # Development workflow
│   └── tasking/                    # Requirements and task specifications
│       ├── apartment-hunt-tasking.md # Original requirements
│       ├── tasking-mk-2.md         # Docker architecture requirements
│       └── t3.md                   # Structure reorganization
├── controller/                     # Controller service
│   ├── src/                        # Functional code
│   └── docs/                       # Service-specific documentation
├── storage/                        # Storage service
│   ├── src/                        # Functional code
│   └── docs/                       # Service-specific documentation
├── scraper/                        # Scraper service
│   ├── src/                        # Functional code
│   └── docs/                       # Service-specific documentation
├── cli/                           # CLI service
│   ├── src/                        # Functional code
│   └── docs/                       # Service-specific documentation
├── shared/                         # Shared components
│   ├── src/                        # Models, communication, utilities
│   └── docs/                       # Deployment configs, tests
├── database/                       # Database configurations
│   ├── migrations/                 # SQL migration files
│   ├── schema/                     # Database schema definitions
│   └── cnpg/                       # Cloud Native PostgreSQL configs
├── go.mod                          # Go module definition
└── Makefile                        # Build automation
```

Each document is self-contained and can be referenced independently for specific development tasks.