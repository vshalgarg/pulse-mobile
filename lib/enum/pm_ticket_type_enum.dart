enum PmTicketTypeEnum {
  telecom("Telecom"),
  solar("Solar");

  const PmTicketTypeEnum(this.value);

  final String value;

  static PmTicketTypeEnum fromString(String? value) {
    if (value == null) return PmTicketTypeEnum.telecom;
    
    print("🔍 DEBUG: PmTicketTypeEnum.fromString called with: '$value'");
    
    // Handle both "Solar" and "solar" cases
    final normalizedValue = value.toLowerCase();
    print("🔍 DEBUG: Normalized value: '$normalizedValue'");
    
    switch (normalizedValue) {
      case "telecom":
        print("🔍 DEBUG: Returning PmTicketTypeEnum.telecom");
        return PmTicketTypeEnum.telecom;
      case "solar":
        print("🔍 DEBUG: Returning PmTicketTypeEnum.solar");
        return PmTicketTypeEnum.solar;
      default:
        print("🔍 DEBUG: Default case, returning PmTicketTypeEnum.telecom");
        return PmTicketTypeEnum.telecom;
    }
  }

  bool get isTelecom => this == PmTicketTypeEnum.telecom;
  bool get isSolar => this == PmTicketTypeEnum.solar;
}
