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
