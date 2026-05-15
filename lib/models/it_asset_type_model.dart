class ItAssetType {
  final int iatmId;
  final String assetType;
  final String assetAcronym;
  final int tenantMstId;

  const ItAssetType({
    required this.iatmId,
    required this.assetType,
    required this.assetAcronym,
    required this.tenantMstId,
  });

  factory ItAssetType.fromJson(Map<String, dynamic> json) {
    return ItAssetType(
      iatmId: int.tryParse(json['iatm_id']?.toString() ?? '') ?? 0,
      assetType: json['asset_type']?.toString() ?? '',
      assetAcronym: json['asset_acronym']?.toString() ?? '',
      tenantMstId: int.tryParse(json['tenant_mst_id']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iatm_id': iatmId,
      'asset_type': assetType,
      'asset_acronym': assetAcronym,
      'tenant_mst_id': tenantMstId,
    };
  }
}
