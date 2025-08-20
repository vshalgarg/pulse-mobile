# JWT Token Management Implementation Guide

## Overview

This implementation provides JWT token management functionality to handle expired tokens and ensure seamless API communication. Since the API doesn't support refresh tokens, the system automatically logs out users when tokens expire.

## Features

1. **Token Validation**: Validates JWT tokens and checks expiration times
2. **Automatic Logout**: Logs out users when tokens are expired or invalid
3. **Simple Headers**: Uses only essential headers required by the API

## How It Works

### 1. Token Storage
- JWT tokens are stored in Hive database
- Tokens are validated before each API request
- Expired tokens are automatically cleared

### 2. Token Validation
- Before each API request, the system checks if the current token is expired
- If expired, the user is automatically logged out and redirected to login
- If valid, the request proceeds with the Authorization header

### 3. Simple Header Management
- Only essential headers are included
- Authorization header is added automatically for authenticated requests
- No custom API keys or session management

## API Endpoints

### Login Endpoint
```
POST https://pulseapi.premiumfreshers.com/authenticate/login
```

**Request Body:**
```json
{
  "username": "7549904844",
  "password": "bipin@123"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiI3NTQ5OTA0ODQ0IiwiaWF0IjoxNzU1NjIyMjg1LCJleHAiOjE3NTU2NDAyODV9.3iV8CmqhFKnQ9xeFRot5as-fodNppFEJhDphqqnL4ulfjSRsAm3J7uJ4M57d-H0UrAWcrWfjfbbWjY47yS49CQ"
}
```

## Implementation Details

### 1. AuthModel
The `AuthModel` class handles the JWT token:

```dart
class AuthModel extends Equatable {
  final String token;
  final String? userId;
  final String? email;
  final String? firstName;
  final String? lastName;
  
  // ... constructor and methods
}
```

### 2. HiveDB Storage
Token storage methods:

```dart
// Get token
static String? get getToken => userCredential.get(HiveConstant.token);

// Save token
static Future<void> saveToken(String token) async {
  await userCredential.put(HiveConstant.token, token);
}
```

### 3. API Provider
The `ApiProvider` class handles token validation:

```dart
onRequest: (options, handler) async {
  // Don't add Authorization header for login endpoint
  final isAuthEndpoint = options.path.contains('authenticate/login');
  
  if (!isAuthEndpoint) {
    // Check if token is expired and logout if needed
    if (Utils.isCurrentTokenExpired()) {
      await _logoutUser();
      return handler.next(DioException(...));
    }
    
    if (HiveDB.getToken != null) {
      options.headers['Authorization'] = 'Bearer ${HiveDB.getToken}';
    }
  }
  return handler.next(options);
}
```

### 4. Token Validation Utilities
The `Utils` class provides token validation methods:

```dart
// Check if token is expired
static bool isTokenExpired(String? token)

// Check if current stored token is expired
static bool isCurrentTokenExpired()

// Get token expiration time
static DateTime? getTokenExpiration(String? token)
```

## Usage

### 1. Login
When a user logs in, the token is automatically saved:

```dart
final result = await authRepository.login(
  username: '7549904844',
  password: 'bipin@123',
);

if (result.isSuccess) {
  // Token is automatically saved to HiveDB
  // User is now authenticated
}
```

### 2. API Calls
Make API calls normally - token validation is handled automatically:

```dart
final response = await apiService.get(path: '/api/data');
// If token is expired, user will be logged out automatically
```

### 3. Logout
Clear token on logout:

```dart
await HiveDB.logout();
// This clears the token and other user data
```

## Configuration

### 1. API Headers
The system automatically includes these headers:
- `content-Type`: 'application/json'
- `accept`: 'application/json'
- `Authorization`: 'Bearer [token]' (for authenticated requests only)

### 2. Token Expiration Handling
When a token expires:
1. User is automatically logged out
2. All user data is cleared
3. User is redirected to login screen
4. User must log in again to get a new token

## Security Considerations

1. **Token Storage**: JWT tokens are stored securely in Hive database
2. **Token Validation**: All tokens are validated before use
3. **Automatic Cleanup**: Expired tokens are automatically cleared
4. **Secure Logout**: All user data is cleared on logout

## Testing

To test the token management functionality:

1. **Login** with valid credentials
2. **Wait** for token to expire (or use a short-lived token)
3. **Make API calls** - user should be logged out automatically
4. **Check logs** for token validation messages

The system will automatically handle token expiration and logout users when needed.
