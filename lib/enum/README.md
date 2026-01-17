# PM Ticket Type Enum

This enum is used to identify the type of PM (Preventive Maintenance) ticket the user is working with.

## Usage

### Basic Usage

```dart
import 'package:app/enum/pm_ticket_type_enum.dart';

// Create from string
PmTicketTypeEnum ticketType = PmTicketTypeEnum.fromString("Telecom");

// Use the enum
if (ticketType.isTelecom) {
  // Handle telecom-specific logic
} else if (ticketType.isSolar) {
  // Handle solar-specific logic
}
```

### In Widgets

```dart
class PmScreen extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  
  const PmScreen({
    super.key,
    required this.ticketType,
  });
  
  @override
  State<PmScreen> createState() => _PmScreenState();
}

class _PmScreenState extends State<PmScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
      ),
      body: _buildContent(),
    );
  }
  
  String _getTitle() {
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "PM (Telecom)";
      case PmTicketTypeEnum.solar:
        return "PM (Solar)";
    }
  }
  
  Widget _buildContent() {
    if (widget.ticketType.isTelecom) {
      return _buildTelecomContent();
    } else {
      return _buildSolarContent();
    }
  }
}
```

### Navigation

```dart
// Navigate to PM screen with ticket type
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PmScreen1(
      ticketType: PmTicketTypeEnum.fromString(ticket.siteDomainName),
      auditSchId: ticket.auditSchId.toString(),
      siteAuditSchId: ticket.ticketSchId.toString(),
      siteId: ticket.ticketSchId.toString(),
    ),
  ),
);
```

## Benefits

1. **Type Safety**: Prevents passing invalid ticket types
2. **Single Flow**: Allows you to maintain one PM flow for both telecom and solar
3. **Easy Extension**: Easy to add new ticket types in the future
4. **Conditional Logic**: Clean way to handle different behaviors based on ticket type
5. **Maintainability**: Centralized logic for ticket type handling

## Adding New Ticket Types

To add a new ticket type:

1. Add the new case to the enum
2. Update the `fromString` method
3. Add getter methods if needed
4. Update any switch statements that use the enum
