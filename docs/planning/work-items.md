# Work Items Index

> **Related Documents:**
> - [Development Methodology](../tasking/t6.md) - Epic/Feature/UserStory workflow
> - [Architecture](architecture.md) - System design and structure
> - [TDD Methodology](../technical/tdd.md) - Testing approach
> - [Back to Implementation Plan](../../IMPLEMENTATION_PLAN.md)

## Development Methodology

This project follows a structured Epic/Feature/UserStory methodology for organized development:

- **Epics**: Large-scale capabilities with significant business value
- **Features**: Cohesive functionality sets that can be built and tested independently
- **User Stories**: Specific, testable work items with clear acceptance criteria

## Work Organization Structure

All work items are organized in the following directory structure:
```
docs/planning/[epic]/[feature]/[userStory].md
```

Each level has its own `.md` file describing purpose and context:
- Epic files define large-scale capability areas
- Feature files define cohesive functionality sets
- UserStory files define specific, actionable work items

## Current Epics

### 1. User Management
**Purpose**: Complete user authentication, session management, and multi-user support

**Features**:
- [Authentication](user-management/authentication/) - User login, registration, and session handling
- [User Preferences](user-management/user-preferences/) - Multiple preference sets per user
- [User Activity](user-management/user-activity/) - Activity tracking and history

### 2. Listing Aggregation
**Purpose**: Multi-source apartment listing collection with intelligent deduplication

**Features**:
- [Scraping Framework](listing-aggregation/scraping-framework/) - Extensible scraper architecture
- [Data Deduplication](listing-aggregation/data-deduplication/) - Multi-level duplicate detection
- [Source Management](listing-aggregation/source-management/) - Dynamic source configuration

### 3. Search Engine
**Purpose**: Intelligent search, filtering, and recommendation system

**Features**:
- [Core Search](search-engine/core-search/) - Basic filtering and search functionality
- [Search Refinement](search-engine/search-refinement/) - ML-based search improvement
- [Result Ranking](search-engine/result-ranking/) - Personalized result ordering

### 4. Database Infrastructure
**Purpose**: PostgreSQL integration with efficient indexing and migrations

**Features**:
- [Schema Management](database-infrastructure/schema-management/) - Database schema and migrations
- [Query Optimization](database-infrastructure/query-optimization/) - Performance optimization
- [Data Integrity](database-infrastructure/data-integrity/) - Constraints and validation

### 5. Container Architecture
**Purpose**: Docker microservices with orchestration and communication

**Features**:
- [Service Communication](container-architecture/service-communication/) - gRPC between containers
- [Container Orchestration](container-architecture/container-orchestration/) - Dynamic container management
- [Service Discovery](container-architecture/service-discovery/) - Container networking and discovery

## Development Workflow

### 1. Work Item Selection
- Pick a single UserStory to work on
- Ensure all dependencies are completed
- Mark UserStory as `in_progress` before starting

### 2. Test-Driven Development
- Write failing unit tests first (Red)
- Implement minimal code to pass tests (Green)
- Refactor while keeping tests green (Refactor)

### 3. Feature Integration Testing
- Complete all UserStories in a Feature
- Run integration tests covering feature functionality
- Ensure feature can result in successful build

### 4. Epic Completion
- Complete all Features in an Epic
- Run end-to-end tests covering epic capabilities
- Verify epic delivers intended business value

### 5. Commit Strategy
- Only commit when UserStory is complete and passes all tests
- Use descriptive commit messages including UserStory identifier
- Example: `feat: implement user login validation [user-management/authentication/login-validation]`

## Quality Standards

### Unit Testing
- Each UserStory must have comprehensive unit tests
- 90%+ code coverage for core functionality
- Fast execution (< 100ms per test)

### Integration Testing
- Each Feature must have integration tests
- Test feature interactions and boundaries
- Medium execution time (< 5s per feature test)

### End-to-End Testing
- Each Epic must have E2E tests
- Test complete user workflows
- Longer execution time acceptable (< 30s per epic test)

### Logging and Error Handling
- Verbose logging for testing and debugging
- Succinct logging for production use
- Robust error handling with clear user messages
- Circuit breakers and graceful degradation

## Work Item Templates

### Epic Template
```markdown
# [Epic Name]

## Purpose
High-level description of business capability

## Business Value
Why this epic matters to users

## Features
- Feature 1: Description
- Feature 2: Description

## Success Criteria
- Criteria 1
- Criteria 2

## Dependencies
- Other epics or external dependencies
```

### Feature Template
```markdown
# [Feature Name]

## Purpose
Cohesive functionality description

## Acceptance Criteria
- Must deliver X capability
- Must integrate with Y system

## User Stories
- UserStory 1: Description
- UserStory 2: Description

## Integration Tests
- Test scenario 1
- Test scenario 2

## Dependencies
- Required UserStories from other features
```

### UserStory Template
```markdown
# [UserStory Name]

## Summary
Brief description of specific work

## Acceptance Criteria
- [ ] Criteria 1
- [ ] Criteria 2
- [ ] Criteria 3

## Context
Additional context or background information

## Unit Tests
- Test case 1
- Test case 2

## Dependencies
- Other UserStories that must be completed first

## Definition of Done
- [ ] Unit tests written and passing
- [ ] Code review completed
- [ ] Integration tests passing
- [ ] Documentation updated
```

## Progress Tracking

Track progress at all levels:
- **UserStory**: Individual work item completion
- **Feature**: Collection of related UserStories
- **Epic**: Major capability delivery

Use commit messages and pull requests to link work to specific UserStories for traceability.