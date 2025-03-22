## [0.6.3] - March 22nd 2025

* Optimized User Flow v2 API format implementation:
  * **Fixed critical issue**: Now correctly handles parameter inclusion based on session state:
    * Initial requests (empty session): Include action, v2, and client_id
    * Subsequent requests (with session): Include only session and image_variation
  * Added support for redirect_uri in OAuth2 authentication flow
  * Enhanced session handling for the OAuth2 flow
  * Better logging for initial vs. subsequent API calls
  * Fixed OAuth2 button handling to properly include redirect_uri
  * Enhanced debugging with complete JSON-encoded request and response logs
  * Improved developer mode by showing all data including tokens and passwords
  * Logs now show the exact data being sent and received for easier debugging

## [0.6.2] - March 22nd 2025

* Added explicit support for User Flow v2 API format:
  * Added v2: true parameter to all User:flow API requests
  * Improved token handling for Map token objects
  * Treat token objects as opaque without accessing their contents
  * Better handling of different response formats (map and tuple)
  * Enhanced debug logging for API interactions
* Removed WebAuthService in favor of direct URL launching with url_launcher
* Better OAuth2 button detection and rendering
* Improved error handling and messaging

## [0.6.1] - March 22nd 2025

* Initial support for User Flow v2 API format:
  * Enhanced OAuth2 button handling for the new format
  * Added support for select/dropdown fields with static values
  * Added support for dynamic select fields that fetch options from API
  * Improved error message styling
  * Updated form field processing with category-based handling
  * Better session token management
  * Support for field default values
  * Enhanced redirect handling on flow completion
* Added KLB systems integration documentation

## [0.6.0] - March 16th 2025

* Major refactoring to improve testability and maintainability
* Extracted services for better dependency injection:
  * LoginService for API interactions
  * WebAuthService for OAuth2 authentication
* Updated existing components:
  * ImagePickerWidget now supports dependency injection for testing
  * AtOnlineLoginPageBody reorganized with better UI building methods
* Added comprehensive unit tests
* Update atonline_api dependency to 0.4.19+2
* Fix deprecated color property access in HexColor extension

## [0.5.0] - September 5th 2024

* Switch flutter_web_auth → flutter_web_auth_2
* Updated dependencies

## [0.4.8] - July 17th 2024

* Updated dependencies

## [0.4.7] - May 25th 2023

* Updated dependencies

## [0.4.6] - June 28th 2022

* Accept completion without a valid token, in case of account deletion/etc

## [0.4.5] - June 11th 2022

* Use authenticated requests in flow so requests other than login can be authenticated

## [0.4.4] - June 11th 2022

* Add support for action in flow process

## [0.4.3] - February 4th 2022

* Cleanup and upgrade deps

## [0.4.2] - November 10th 2021

* Added onComplete parameter to override completion action

## [0.4.1] - October 29th 2021

* Bump atonline_api dep

## [0.4.0+1] - October 24th 2021

* Change flutter_svg dep to be more flexible

## [0.4.0] - October 16th 2021

* Upgrade to dart null safety

## [0.3.5] - March 5th 2021

* Return to ^0.6.0 imagepicker dependency as it conflicts due to http package

## [0.3.4] - March 4th 2021

* Update dependencies
* Update code accordingly

## [0.3.3] - September 4th 2020

* Updated dependencies
* Added support for phone field
* Added max size for oauth icons

## [0.3.2] - September 4th 2020

* Updated dependencies

## [0.3.1] - January 27th 2020

* Fix handling of cancellation of login view
* Remove now unneeded dependency on icons theme

## [0.3.0] - January 27th 2020

* Code cleanup & move hexcolor to own file
* Instead of redirectUri we now ask for callbackUrlScheme to process oauth2 login
* Now using flutter_web_auth for web auth, ensuring SSO cookies are available

## [0.2.3] - January 26th 2020

* Fix support for data uri in server-defined buttons

## [0.2.3] - January 26th 2020

* Fix support for server-defined buttons

## [0.2.2] - January 26th 2020

* Adding support for server-defined buttons, using SVG icons

## [0.2.1] - January 22nd 2020

* Upgraded dependencies and pubspec to recent flutter

## [0.2.0] - August 16th 2019

* Upgraded atonline_api dep

## [0.1.0] - March 19th 2019

* AndroidX upgrade (dependency version bump)

## [0.0.1] - January 1st 2019

* Initial login interface system
