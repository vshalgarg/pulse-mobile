# Authentication Implementation with Token Management

This document describes the complete authentication system implementation with automatic login, token expiration handling, and secure token storage.

## Overview

The authentication system provides:
- Secure token storage using Hive database
- Automatic token expiration detection
- Remember me functionality
- Auto-login with stored credentials
- Automatic logout on token expiration
- JWT token validation and parsing

## Key Components

### 1. AuthModel (`lib/models/auth_model.dart`)
- Enhanced to include token expiration time
- Automatic JWT token parsing for expiration
- Support for both API-provided and JWT-extracted expiration times

### 2. AuthCubit (`lib/bloc/login_bloc/auth_cubit.dart`)
- Complete state management for authentication
- Auto-login functionality
- Token validation and expiration checking
- Remember me credential management

### 3. HiveDB (`lib/hive_local_database/hive_db.dart`)
- Secure token storage
- Token expiration storage
- User credential management
- Remember me functionality

### 4. Utils (`lib/utils.dart`)
- JWT token parsing and validation
- Token expiration checking
- Token format validation

### 5. AuthService (`lib/services/auth_service.dart`)
- Centralized authentication logic
- Token management utilities
- Header generation for API requests

## Features

### 🔐 **Secure Token Storage**
- Tokens stored in Hive database (encrypted local storage)
- Token expiration times stored separately
- Automatic cleanup on logout

### ⏰ **Token Expiration Handling**
- Automatic detection of expired tokens
- JWT token parsing to extract expiration
- Graceful logout on token expiration

### 🔄 **Auto-Login Functionality**
- Automatic login with stored credentials
- Remember me option for persistent login
- Secure credential storage

### 🚪 **Automatic Logout**
- Logout on token expiration
- Logout on 401 API responses
- Clear all stored data on logout

### 🛡️ **Token Validation**
- JWT format validation
- Expiration time validation
- Secure token handling

## Implementation Details

### Token Storage Flow
1. User logs in successfully
2. Token and expiration saved to Hive database
3. User credentials saved if "Remember Me" is enabled
4. Token automatically included in API requests

### Auto-Login Flow
1. App starts and checks for stored token
2. If token exists and is valid, user stays logged in
3. If token is expired but "Remember Me" is enabled, auto-login is attempted
4. If auto-login fails, user is redirected to login screen

### Token Expiration Flow
1. API interceptor checks token before each request
2. If token is expired, user is automatically logged out
3. User is redirected to login screen
4. All stored data is cleared

### Remember Me Flow
1. User enables "Remember Me" during login
2. Username and password are securely stored
3. On app restart, auto-login is attempted
4. If successful, user stays logged in
5. If failed, credentials are cleared

## API Integration

### Request Headers
```dart
// Automatic token inclusion in API requests
Map<String, String> headers = {
  'Authorization': 'Bearer ${HiveDB.getToken}',
  'Content-Type': 'application/json',
};
```

### Error Handling
- 401 responses trigger automatic logout
- Expired tokens are detected and cleared
- User is redirected to login screen

## Usage Examples

### Check Authentication Status
```dart
final authCubit = context.read<AuthCubit>();
if (authCubit.isLoggedIn) {
  // User is authenticated
} else {
  // User needs to login
}
```

### Auto-Login
```dart
final authCubit = context.read<AuthCubit>();
await authCubit.autoLogin();
```

### Manual Logout
```dart
final authCubit = context.read<AuthCubit>();
await authCubit.logout();
```

### Check Token Validity
```dart
final authCubit = context.read<AuthCubit>();
if (authCubit.isTokenValid) {
  // Token is valid
} else {
  // Token is expired or invalid
}
```

## Security Features

### 🔒 **Secure Storage**
- Hive database with encryption
- No plain text password storage
- Secure token handling

### 🕒 **Token Expiration**
- Automatic expiration detection
- Immediate logout on expiration
- No expired token usage

### 🧹 **Data Cleanup**
- Complete data removal on logout
- Automatic cleanup of expired tokens
- Secure credential removal

### 🛡️ **JWT Validation**
- Token format validation
- Expiration time extraction
- Secure token parsing

## Configuration

### Token Expiration Buffer
```dart
// Check if token expires within 5 minutes
bool isExpiringSoon = Utils.isTokenExpiringSoon();
```

### Remember Me Settings
```dart
// Enable remember me
await HiveDB.setRememberMe(true);

// Check remember me status
bool isRememberMeEnabled = HiveDB.getRememberMe;
```

## Error Handling

### Network Errors
- Automatic retry for network issues
- Graceful handling of API failures
- User-friendly error messages

### Token Errors
- Automatic logout on token issues
- Clear error messages for users
- Secure error handling

### Storage Errors
- Fallback mechanisms for storage issues
- Error logging for debugging
- Graceful degradation

## Testing

### Token Validation Tests
```dart
// Test token expiration
bool isExpired = Utils.isTokenExpired(token);

// Test token format
bool isValid = AuthService.instance.isValidTokenFormat(token);
```

### Authentication Flow Tests
```dart
// Test auto-login
await authCubit.autoLogin();

// Test logout
await authCubit.logout();
```

## Best Practices

1. **Always check token validity before API calls**
2. **Use the AuthCubit for all authentication operations**
3. **Handle token expiration gracefully**
4. **Clear sensitive data on logout**
5. **Use secure storage for credentials**
6. **Implement proper error handling**
7. **Test authentication flows thoroughly**

## Troubleshooting

### Common Issues

1. **Token not being saved**
   - Check Hive database initialization
   - Verify storage permissions

2. **Auto-login not working**
   - Check "Remember Me" is enabled
   - Verify stored credentials

3. **Token expiration not detected**
   - Check JWT token format
   - Verify expiration time parsing

4. **Logout not working**
   - Check Hive database access
   - Verify navigation setup

### Debug Information

```dart
// Debug token information
print('Token: ${HiveDB.getToken}');
print('Expiry: ${HiveDB.getTokenExpiry}');
print('Is Valid: ${Utils.isTokenExpired(HiveDB.getToken)}');
```

This implementation provides a robust, secure, and user-friendly authentication system with automatic token management and expiration handling.
