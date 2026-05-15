/// Reads API / SQLite maps that may use snake_case or camelCase keys.
String? readMapString(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) return null;
  for (final k in keys) {
    final v = map[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return null;
}

bool _isEmptyDynamic(dynamic v) {
  if (v == null) return true;
  final s = v.toString().trim();
  return s.isEmpty || s == 'null';
}

/// Flattens nested site blobs (`site`, `siteDetails`, …) onto the root when
/// those keys are missing — incident ticket APIs often nest contacts there.
Map<String, dynamic> mergeNestedSiteMapsIntoIncidentTicket(
  Map<String, dynamic> ticket,
) {
  final out = Map<String, dynamic>.from(ticket);
  const nestedKeys = <String>[
    'site',
    'siteVo',
    'siteVO',
    'siteDetails',
    'site_details',
    'cmSite',
    'siteInfo',
  ];
  for (final nk in nestedKeys) {
    final v = ticket[nk];
    if (v is! Map) continue;
    final nested = Map<String, dynamic>.from(v);
    nested.forEach((k, val) {
      if (_isEmptyDynamic(val)) return;
      if (_isEmptyDynamic(out[k])) out[k] = val;
    });
  }
  return out;
}

Map<String, dynamic> _overlayNonEmptyValues(
  Map<String, dynamic> base,
  Map<String, dynamic> overlay,
) {
  final out = Map<String, dynamic>.from(base);
  overlay.forEach((k, v) {
    if (_isEmptyDynamic(v)) return;
    if (_isEmptyDynamic(out[k])) out[k] = v;
  });
  return out;
}

/// Combines ticket JSON with rows from `incident_sites_data` / `cm_sites_data`
/// so offline open has cluster incharge and infra fields when the raw ticket
/// payload omitted them.
Map<String, dynamic> mergeIncidentTicketWithSqliteSiteRows(
  Map<String, dynamic> incidentTicketData,
  List<Map<String, dynamic>?> sqliteSiteRows,
) {
  var m = mergeNestedSiteMapsIntoIncidentTicket(incidentTicketData);
  for (final row in sqliteSiteRows) {
    if (row == null || row.isEmpty) continue;
    m = _overlayNonEmptyValues(m, row);
  }
  return m;
}

Map<String, dynamic> unwrapTicketDataMap(Map<String, dynamic> raw) {
  if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw['data'] as Map);
  }
  return Map<String, dynamic>.from(raw);
}

/// CM tickets use [ticketSchId] as cmSiteReqId; site contacts live under physical [siteId].
int resolveCmPhysicalSiteId(
  Map<String, dynamic> raw, {
  int? ticketSchIdFallback,
}) {
  final flat = mergeNestedSiteMapsIntoIncidentTicket(unwrapTicketDataMap(raw));
  for (final key in ['siteId', 'site_id']) {
    final v = flat[key];
    if (v is int && v > 0) return v;
    if (v != null) {
      final parsed = int.tryParse(v.toString());
      if (parsed != null && parsed > 0) return parsed;
    }
  }
  return ticketSchIdFallback ?? 0;
}

bool cmTicketPayloadMissingSiteContacts(Map<String, dynamic> map) {
  final flat = mergeNestedSiteMapsIntoIncidentTicket(unwrapTicketDataMap(map));
  final hasInfra = readMapString(flat, [
        'infraDistrictEngineerName',
        'infra_district_engineer_name',
        'infraEngineerName',
        'infra_engineer_name',
      ]) !=
      null;
  final hasIncharge = readMapString(flat, [
        'clusterInchargeName',
        'cluster_incharge_name',
      ]) !=
      null;
  return !hasInfra && !hasIncharge;
}

Map<String, dynamic> overlayCmSiteContactFields({
  required Map<String, dynamic> base,
  String? infraName,
  String? infraPhone,
  String? clusterInchargeName,
  String? clusterInchargeContact,
}) {
  final overlay = <String, dynamic>{};
  if (infraName != null && infraName.trim().isNotEmpty) {
    overlay['infraDistrictEngineerName'] = infraName;
    overlay['infraEngineerName'] = infraName;
    overlay['infra_district_engineer_name'] = infraName;
    overlay['infra_engineer_name'] = infraName;
  }
  if (infraPhone != null && infraPhone.trim().isNotEmpty) {
    overlay['infraDistrictEngineerContactNo'] = infraPhone;
    overlay['infraEngineerContactNo'] = infraPhone;
    overlay['infra_district_engineer_contact_no'] = infraPhone;
    overlay['infra_engineer_contact_no'] = infraPhone;
  }
  if (clusterInchargeName != null && clusterInchargeName.trim().isNotEmpty) {
    overlay['clusterInchargeName'] = clusterInchargeName;
    overlay['cluster_incharge_name'] = clusterInchargeName;
  }
  if (clusterInchargeContact != null && clusterInchargeContact.trim().isNotEmpty) {
    overlay['clusterInchargeContactNo'] = clusterInchargeContact;
    overlay['cluster_incharge_contact_no'] = clusterInchargeContact;
  }
  return _overlayNonEmptyValues(base, overlay);
}