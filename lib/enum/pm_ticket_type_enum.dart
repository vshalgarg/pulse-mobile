enum PmTicketTypeEnum {
  telecom("Telecom"),
  solar("Solar");

  const PmTicketTypeEnum(this.value);

  final String value;

  static PmTicketTypeEnum fromString(String? value) {
    if (value == null) return PmTicketTypeEnum.telecom;

    // Handle both "Solar" and "solar" cases
    final normalizedValue = value.toLowerCase();

    switch (normalizedValue) {
      case "telecom":

        return PmTicketTypeEnum.telecom;
      case "solar":

        return PmTicketTypeEnum.solar;
      default:

        return PmTicketTypeEnum.telecom;
    }
  }

  bool get isTelecom => this == PmTicketTypeEnum.telecom;
  bool get isSolar => this == PmTicketTypeEnum.solar;
}
