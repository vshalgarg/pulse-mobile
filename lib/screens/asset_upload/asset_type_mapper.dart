/// Maps asset type acronyms to their display names
class AssetTypeMapper {
  static const Map<String, String> _acronymToDisplayName = {
    'ACDB': 'ACDB',
    'AVL': 'Aviation Light',
    'BATT': 'Battery',
    'BATTC': 'Battery Cabinet',
    'BNDR': 'Boundary',
    'CBMS': 'CBMS',
    'CCTV': 'CCTV',
    'CCU': 'CCU',
    'CCUC': 'CCU Cabin',
    'CCUM': 'CCU MPPT',
    'CCUR': 'CCU Rectifier',
    'DCDB': 'DCDB',
    'DG': 'DG',
    'FLLT': 'Flood Light',
    'FREX': 'Fire Extinguisher',
    'HOOTER': 'Hooter',
    'INVR': 'Invertor',
    'LSPU': 'LSPU',
    'LTDB': 'LTDB',
    'MMS': 'MMS',
    'MPPT': 'MPPT',
    'OTH': 'Others',
    'REC': 'Rectifier',
    'SADA': 'WMS',
    'SCADA': 'SCADA',
    'SMPS': 'SMPS',
    'SMPSC': 'SMPS Cabinet',
    'SMPSM': 'SMPS MPPT',
    'SMPSR': 'SMPS Rectifier',
    'SNDB': 'Sand Bucket',
    'SOLAR': 'Solar',
    'TFR': 'Transformer',
    'TV': 'LED TV',
    'VCB': 'VCB',
  };

  /// Gets the display name for an acronym
  /// Returns the display name if found, otherwise returns the acronym itself
  static String getDisplayName(String acronym) {
    return _acronymToDisplayName[acronym.toUpperCase()] ?? acronym.toUpperCase();
  }

  /// Checks if an acronym exists in the mapping
  static bool isValidAcronym(String acronym) {
    return _acronymToDisplayName.containsKey(acronym.toUpperCase());
  }

  /// Gets all valid acronyms
  static List<String> getAllAcronyms() {
    return _acronymToDisplayName.keys.toList();
  }

  /// Gets the acronym for a display name (reverse lookup)
  /// Returns the acronym if found, otherwise returns null
  static String? getAcronymForDisplayName(String displayName) {
    for (var entry in _acronymToDisplayName.entries) {
      if (entry.value == displayName) {
        return entry.key;
      }
    }
    return null;
  }
}

