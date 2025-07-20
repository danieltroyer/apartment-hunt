For each data source, like craigslist, create a separate and tailored data extraction appliance. 
- Prefer API access if available
- Use web scraping as a fallback
- Ensure compliance with terms of service and robots.txt

For each listing
- multiple sources may provide the same listing
- deduplicate the listings based on attributes of the apartment, noting that the sources will use different identifiers and may not list all of the same attributes, but most listed attributes should match.
- Critical information: Is the apartment still available? If not, remove it from the suggested listings, but keep the archive of the listing for user reference.

user interface will be a command line interface (CLI) that allows users to set up query parameters and process data. When a listing is selected for more information, provide a hyperlink to the original listing source. If more than one original source is available, provide a choice of sources.

infrastructure:
This should all run within a local docker environment. Multiple containers may be used to separate concerns and increase threading. Use a primary container as the central controller that manages the other containers, which will handle tasks like scraping, data storage, and user interaction. The peripheral containers should communicate with the primary container to report progress and receive commands. The primary container should start and stop peripheral containers as needed, allowing for efficient resource management and task execution.