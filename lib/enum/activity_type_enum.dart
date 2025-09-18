enum ActivityTypeEnum {
  assetAudit("AA"),
  preventiveMaintenance("PM"),
  energyReading("ER"),
  correctiveMaintenance("CM");
  
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
      default:
        throw ArgumentError('Unknown ActivityTypeEnum value: $value');
    }
  }
}