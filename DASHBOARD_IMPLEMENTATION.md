# Dashboard Implementation

This document describes the implementation of the dashboard count functionality for the home screen.

## Overview

The dashboard implementation includes:
- Dashboard model to handle API response
- Dashboard repository for API calls
- Dashboard cubit for state management
- Integration with the home screen

## Files Created/Modified

### New Files:
1. `lib/models/dashboard_model.dart` - Model classes for dashboard data
2. `lib/repositories/dashboard_repository.dart` - Repository for dashboard API calls
3. `lib/bloc/dashboard_cubit.dart` - Cubit for dashboard state management
4. `lib/bloc/dashboard_state.dart` - State definitions for dashboard cubit
5. `test/dashboard_test.dart` - Unit tests for dashboard model

### Modified Files:
1. `lib/app_config.dart` - Added dashboard repository
2. `lib/app_root.dart` - Added dashboard cubit provider
3. `lib/screens/home_screen.dart` - Integrated dashboard cubit

## API Endpoint

- **Endpoint**: `/api/v1/mobile/mobile-dashboard`
- **Method**: GET
- **Response Format**: JSON object with activity types as keys

## Response Schema

```json
{
    "Energy Readiing": [
        {
            "activity_type": "Energy Readiing",
            "ticket_code": "All Tickets",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Energy Readiing",
            "ticket_code": "Due",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Energy Readiing",
            "ticket_code": "Completed",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Energy Readiing",
            "ticket_code": "Closed",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Energy Readiing",
            "ticket_code": "Missed Deadline",
            "ticket_cnt": 0
        }
    ],
    "Preventive Maintenance": [
        {
            "activity_type": "Preventive Maintenance",
            "ticket_code": "All Tickets",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Preventive Maintenance",
            "ticket_code": "Due",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Preventive Maintenance",
            "ticket_code": "Completed",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Preventive Maintenance",
            "ticket_code": "Closed",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Preventive Maintenance",
            "ticket_code": "Missed Deadline",
            "ticket_cnt": 0
        }
    ],
    "Asset Audit": [
        {
            "activity_type": "Asset Audit",
            "ticket_code": "All Tickets",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Asset Audit",
            "ticket_code": "Due",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Asset Audit",
            "ticket_code": "Completed",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Asset Audit",
            "ticket_code": "Closed",
            "ticket_cnt": 0
        },
        {
            "activity_type": "Asset Audit",
            "ticket_code": "Missed Deadline",
            "ticket_cnt": 0
        }
    ]
}
```

## Implementation Details

### Dashboard Model
- `DashboardModel` - Main model class that contains a map of activity types to ticket data
- `TicketData` - Individual ticket data with activity type, ticket code, and count

### Dashboard Repository
- Handles API calls to fetch dashboard data
- Uses the existing `ApiService` for HTTP requests
- Returns `ResponseResult<DashboardModel?>` for proper error handling

### Dashboard Cubit
- Manages dashboard state using BLoC pattern
- States: `DashboardInitial`, `DashboardLoading`, `DashboardSuccess`, `DashboardFailure`
- Provides `getDashboardCount()` method to fetch data

### Home Screen Integration
- Uses `BlocBuilder` to listen to dashboard state changes
- Shows loading indicator while fetching data
- Shows error message with retry button on failure
- Updates ticket counts dynamically based on API response
- Maintains existing UI structure without changes

## Usage

The dashboard data is automatically fetched when the home screen loads. The implementation:

1. Calls the API when the screen initializes
2. Shows loading state while fetching data
3. Updates all ticket counts with real data from the API
4. Handles errors gracefully with retry functionality
5. Maintains the existing UI design and functionality

## Notes

- The API is currently not live, so the implementation includes proper error handling
- Corrective Maintenance section uses hardcoded values since it's not included in the current API response
- All UI elements remain unchanged as requested
- The implementation follows the existing code patterns and architecture

## Testing

Run the tests with:
```bash
flutter test test/dashboard_test.dart
```

The tests verify:
- JSON parsing functionality
- Model creation and serialization
- Edge cases (empty/null data)
