# Authentication System

This document describes the authentication system implementation for the Nexgen Flutter app.

## Overview

The authentication system includes:
- Login API integration
- Token-based authentication
- Local storage for token persistence
- Cubit state management
- Repository pattern

## Components

### 1. Models (`lib/models/auth_model.dart`)
- `AuthModel`: Handles login response with token
- `LoginRequestModel`: Handles login request data

### 2. Repository (`lib/repositories/auth_repository.dart`)
- `AuthRepository`: Handles API calls for authentication
- Login method that calls `authenticate/login` endpoint

### 3. Cubit (`lib/bloc/auth_cubit.dart`)
- `AuthCubit`: Manages authentication state
- Handles login, logout, and token storage
- Provides authentication status checks

### 4. States (`lib/bloc/auth_state.dart`)
- `AuthInitial`: Initial state
- `AuthLoading`: Loading state during API calls
- `AuthSuccess`: Success state with auth data
- `AuthFailure`: Error state with error message

### 5. Service (`lib/services/auth_service.dart`)
- `AuthService`: Utility service for token management
- Provides authentication status and token utilities

## Setup

### 1. Environment Configuration
Create a `.env` file in the root directory with your API base URL:

```env
BASE_URL_DEV=https://your-api-base-url.com/api/
```

### 2. API Response Format
The login API should return:

```json
{
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiI3NTQ5OTA0ODQ0IiwiaWF0IjoxNzU1NTgxNjk2LCJleHAiOjE3NTU1OTk2OTZ9.r43hT3_Sms6dshgJ_ebx3qUopgXYF4GFqDIKOst97t83jtZKgXMITCfdziaLZ4pxitDKRYClo4RE2yHYyV6eiQ"
}
```

## Usage

### Login
```dart
// In your widget
context.read<AuthCubit>().login(
  email: 'user@example.com',
  password: 'password123',
);
```

### Listen to Authentication State
```dart
BlocListener<AuthCubit, AuthState>(
  listener: (context, state) {
    if (state is AuthSuccess) {
      // Navigate to home screen
      Navigator.pushReplacementNamed(context, '/home');
    } else if (state is AuthFailure) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage)),
      );
    }
  },
  child: YourWidget(),
)
```

### Check Authentication Status
```dart
// Check if user is logged in
bool isLoggedIn = AuthService.instance.isAuthenticated;

// Get current token
String? token = AuthService.instance.currentToken;
```

### Logout
```dart
// Clear token and logout
await AuthService.instance.clearToken();
// or
context.read<AuthCubit>().logout();
```

## Token Management

The system automatically:
- Saves the token to local storage (Hive) after successful login
- Includes the token in API request headers for authenticated endpoints
- Clears the token on logout

## API Headers

Authenticated requests automatically include:
```
Authorization: Bearer <token>
```

## Error Handling

The system handles:
- Network errors
- Invalid credentials
- Token storage errors
- API response errors

## Security

- Tokens are stored securely in local storage
- Tokens are automatically included in API headers
- Logout clears all stored authentication data
