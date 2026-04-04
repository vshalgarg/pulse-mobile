enum ActivityTypeEnum {
  assetAudit("AA"),
  preventiveMaintenance("PM"),
  energyReading("ER"),
  correctiveMaintenance("CM"),
  siteVisit("SV"),
  generalInspection("GI"),
  incident("Incident"),
  assetUpload("AU"),
  siteVisitLog("siteVisit"),
  siteVisitDocs("siteVisitDocs"),
  generalInspectionSelf("GenInspection"),
  incidentSelf("incidentTicket"),
  generalInspChecklist("genInspectionResp");


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
      case "Incident":
        return ActivityTypeEnum.incident;
      case "AU":
        return ActivityTypeEnum.assetUpload;
      case "siteVisit":
        return ActivityTypeEnum.siteVisitLog;
      case "siteVisitDocs":
        return ActivityTypeEnum.siteVisitDocs;
      case "GenInspection":
        return ActivityTypeEnum.generalInspectionSelf;
      case "incidentTicket":
        return ActivityTypeEnum.incidentSelf;
      case "genInspectionResp":
        return ActivityTypeEnum.generalInspChecklist;
      default:
        throw ArgumentError('Unknown ActivityTypeEnum value: $value');
    }
  }
}
