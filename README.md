# PottyPal

PottyPal is a user-powered public restroom finder built with Flutter.

## Milestone 3: API Integration

### Short Introduction to RESTful APIs

A RESTful API is a web service that exposes resources through standard HTTP methods such as `GET`, `POST`, `PUT`, and `DELETE`.
In this milestone, PottyPal uses a `GET` request to retrieve live restroom-related place data from an external endpoint and display it in the app.

### Implemented Requirements

- Added the `http` package in `pubspec.yaml`.
- Connected to one real API endpoint:
  - `https://nominatim.openstreetmap.org/search?q=public+toilet+Manila+Philippines&format=json&limit=5`
- Parsed JSON data using `jsonDecode`.
- Created a model class with `fromJson()`:
  - `ApiRestroomPlace` in `lib/models/api_restroom_place.dart`
- Implemented API fetch and mapped response data to model objects.
- Added loading state UI using `CircularProgressIndicator`.
- Added basic error handling using `try/catch` and an on-screen error message with a retry button.

### Notes

- The app still keeps local restroom entries, and now also shows a new `Live API Suggestions` section powered by the API response.
