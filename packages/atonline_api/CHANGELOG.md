## [0.4.20] March 22nd 2025

* Improved type safety:
  * Update storeToken function to explicitly use Map<String,dynamic> parameter type
  * Fix analyzer warnings in test files
  * Improve error logging with stack traces
  * Clean up unused imports and variables

## [0.4.19+2] March 16th 2025

* Enhanced test coverage with file upload testing:
  * Added tests for file upload parameter validation
  * Added tests for upload progress tracking
  * Added tests for error handling in authenticated uploads
  * Added real API tests using the Misc/Debug:testUpload endpoint (skipped by default)

## [0.4.19+1] March 16th 2025

* Refactored core classes for better error handling and performance:
  * Improved token refresh logic with better error handling
  * Enhanced HTTP request handling with proper error tracking
  * Added better null safety throughout the codebase
  * Improved cookie handling for better compatibility
  * Enhanced Links class with better URI handling and debugging
  * Added convenience methods to User class for profile management
  * Clarified query parameter handling in API requests
  * Added comprehensive test suite for core functionality:
    * Tests for different response types (strings, objects, arrays)
    * Tests for error handling with various error conditions
    * Tests for query parameter and context parameter handling
    * Tests for cookie management

## [0.4.18] March 16th 2025

* Enhanced API explorer command-line tool with recursive mode
* Added ws.atonline.com endpoint support
* Improved documentation for API explorer capabilities

## [0.4.17] September 19th 2024

* Replace uni_links with app_links

## [0.4.16] July 17th 2024

* Updated dependencies

## [0.4.15] October 22nd 2023

* Bump dependencies
* Pass clientId in headers

## [0.4.14] May 25th 2023

* Fix http dep to accept 0.13.6 or higher

## [0.4.13] May 25th 2023

* Updated dependencies

## [0.4.12] June 28th 2022

* Fix map read

## [0.4.11] June 28th 2022

* Testing token voiding

## [0.4.10] June 28th 2022

* Properly void token on refresh token error

## [0.4.9] June 28th 2022

* Void token on refresh token error

## [0.4.8] February 4th 2022

* Handle invalid refresh token errors as login errors

## [0.4.7] February 4th 2022

* Catch in all cases

## [0.4.6] February 4th 2022

* Catch weird flutter errors on invalid (revoked) bearer tokens

## [0.4.5] February 4th 2022

* Cleanup and deps upgrade

## [0.4.4] November 15th 2021

* Fix file upload via API

## [0.4.3] November 7th 2021

* Add support for cookies
* use flutter changenotifier for Api class

## [0.4.2] November 7th 2021

* Expose whole User object in user.object
* use flutter changenotifier for User class

## [0.4.1+3] October 31st 2021

* Make GET body work

## [0.4.1+2] October 31st 2021

* Fix syntax

## [0.4.1+1] October 31st 2021

* Add a debug line and simplify GET request processing

## [0.4.1] October 29th 2021

* Fix some null issues to make api.user easier to use

## [0.4.0] October 16th 2021

* Migrate to dart null safety

## [0.3.1] March 5th 2021

* Update http dependency to work with firebase

## [0.3.0] March 4th 2021

* Upgrade dependencies
* Use Uri when needed

## [0.2.6] September 4th 2020

* Update dependencies

## [0.2.5] January 22nd 2020

* Added support for context override in api

## [0.2.4] January 22nd 2020

* Upgrade dependencies for recent flutter

## [0.2.3] - August 16th 2019

* Fix AtOnlineApiResult data accessor

## [0.2.2] - August 16th 2019

* Fix AtOnlineApiResult

## [0.2.1] - August 16th 2019

* Make AtOnlineApiResult iterable

## [0.2.0] - August 16th 2019

* Add AtOnlineApiResult object to simplify Api result data access

## [0.1.1] - July 23rd 2019

* Fix for flutter 1.2+

## [0.1.0] - March 19th 2019

* AndroidX upgrade (dependency version bump)

## [0.0.3] - January 1st 2019

* Fix links API to handle query string in links correctly

## [0.0.1] - December 29th 2018

* Initial release with API, user & links code.
