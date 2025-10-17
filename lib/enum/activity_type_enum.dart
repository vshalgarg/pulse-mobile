enum ActivityTypeEnum {
  assetAudit("AA"),
  preventiveMaintenance("PM"),
  energyReading("ER"),
  correctiveMaintenance("CM"),
  siteVisit("SV"),
  generalInspection("GI");

  const ActivityTypeEnum(this.value);

  final String value;

  /// Create ActivityTypeEnum from string value
  static ActivityTypeEnum fromString(String value) {
    switch (value) {
      case "AA":
        return ActivityTypeEnum.assetAudit;
      case "PM":
        return ActivityTypeEnum.preventiveMaintenance;
      case "ER":
        return ActivityTypeEnum.energyReading;
      case "CM":
        return ActivityTypeEnum.correctiveMaintenance;
      case "SV":
        return ActivityTypeEnum.siteVisit;
      case "GI":
        return ActivityTypeEnum.generalInspection;
      default:
        throw ArgumentError('Unknown ActivityTypeEnum value: $value');
    }
  }
}
