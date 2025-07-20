# Epic: Listing Aggregation

## Purpose
Multi-source apartment listing collection system with intelligent deduplication, respectful scraping practices, and dynamic source management for comprehensive apartment search coverage.

## Business Value
- **Comprehensive Coverage**: Aggregate listings from multiple sources (Craigslist, Zillow, Apartments.com)
- **Data Quality**: Intelligent deduplication prevents duplicate listings across sources
- **Respectful Scraping**: Rate limiting and robots.txt compliance maintains good relationships with sources
- **Real-time Updates**: Fresh listing data with availability verification
- **Scalable Architecture**: Easy addition of new listing sources

## Features

### [Scraping Framework](scraping-framework/)
Extensible scraper architecture with API-first approach, fallback web scraping, and comprehensive error handling.

### [Data Deduplication](data-deduplication/)
Multi-level duplicate detection using content hashing, address normalization, and listing attributes to ensure clean data.

### [Source Management](source-management/)
Dynamic source configuration, health monitoring, and automatic source disabling with circuit breaker patterns.

## Success Criteria
- [ ] Successfully scrape listings from at least 3 major sources
- [ ] Achieve <5% duplicate listings in final dataset
- [ ] Maintain >95% uptime for scraping operations
- [ ] Respect rate limits and robots.txt for all sources
- [ ] Automatically handle source failures with graceful degradation
- [ ] Verify listing availability before presenting to users
- [ ] Cache listings efficiently to minimize external requests

## Dependencies
- PostgreSQL database for listing storage
- HTTP client libraries (Resty) for web requests
- HTML parsing library (GoQuery) for web scraping
- gRPC communication for microservices
- Rate limiting and circuit breaker libraries

## Database Schema Impact
- `apartments` table for listing data
- `cache_entries` table for deduplication metadata
- `source_health` table for monitoring source status
- `scraping_logs` table for operation tracking

## Scraping Targets
1. **Craigslist**: Web scraping with respectful rate limits
2. **Zillow API**: API-first with fallback scraping
3. **Apartments.com**: Web scraping with retry logic
4. **Local Property Management**: Custom API integrations

## Performance Goals
- Process 10,000+ listings per hour
- Deduplication accuracy >95%
- Average response time <2 seconds
- Memory usage <500MB per scraper container