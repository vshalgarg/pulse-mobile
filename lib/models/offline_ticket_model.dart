// Removed Hive dependency - using SharedPreferences now

class OfflineTicket {
  final String ticketId;
  final String siteAuditSchId;
  final String siteId;
  final String auditSchId;
  final String activityType;
  final String ticketType;
  final String companyName;
  final String siteName;
  final String siteAddress;
  final String scheduledDate;
  final String dueDate;
  final String status;
  final String priority;
  final bool isDownloaded;
  final bool isOfflineAvailable;
  final DateTime downloadedAt;
  final DateTime lastModified;
  final Map<String, dynamic> completeTicketData;
  final List<OfflineFormData> formDataList;
  final List<OfflinePhoto> photos;
  final List<OfflineRemark> remarks;
  final bool isPendingSync;
  final DateTime? lastSyncAttempt;
  final int syncRetryCount;

  OfflineTicket({
    required this.ticketId,
    required this.siteAuditSchId,
    required this.siteId,
    required this.auditSchId,
    required this.activityType,
    required this.ticketType,
    required this.companyName,
    required this.siteName,
    required this.siteAddress,
    required this.scheduledDate,
    required this.dueDate,
    required this.status,
    required this.priority,
    this.isDownloaded = false,
    this.isOfflineAvailable = false,
    required this.downloadedAt,
    required this.lastModified,
    required this.completeTicketData,
    this.formDataList = const [],
    this.photos = const [],
    this.remarks = const [],
    this.isPendingSync = false,
    this.lastSyncAttempt,
    this.syncRetryCount = 0,
  });

  OfflineTicket copyWith({
    String? ticketId,
    String? siteAuditSchId,
    String? siteId,
    String? auditSchId,
    String? activityType,
    String? ticketType,
    String? companyName,
    String? siteName,
    String? siteAddress,
    String? scheduledDate,
    String? dueDate,
    String? status,
    String? priority,
    bool? isDownloaded,
    bool? isOfflineAvailable,
    DateTime? downloadedAt,
    DateTime? lastModified,
    Map<String, dynamic>? completeTicketData,
    List<OfflineFormData>? formDataList,
    List<OfflinePhoto>? photos,
    List<OfflineRemark>? remarks,
    bool? isPendingSync,
    DateTime? lastSyncAttempt,
    int? syncRetryCount,
  }) {
    return OfflineTicket(
      ticketId: ticketId ?? this.ticketId,
      siteAuditSchId: siteAuditSchId ?? this.siteAuditSchId,
      siteId: siteId ?? this.siteId,
      auditSchId: auditSchId ?? this.auditSchId,
      activityType: activityType ?? this.activityType,
      ticketType: ticketType ?? this.ticketType,
      companyName: companyName ?? this.companyName,
      siteName: siteName ?? this.siteName,
      siteAddress: siteAddress ?? this.siteAddress,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isOfflineAvailable: isOfflineAvailable ?? this.isOfflineAvailable,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      lastModified: lastModified ?? this.lastModified,
      completeTicketData: completeTicketData ?? this.completeTicketData,
      formDataList: formDataList ?? this.formDataList,
      photos: photos ?? this.photos,
      remarks: remarks ?? this.remarks,
      isPendingSync: isPendingSync ?? this.isPendingSync,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      syncRetryCount: syncRetryCount ?? this.syncRetryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticketId': ticketId,
      'siteAuditSchId': siteAuditSchId,
      'siteId': siteId,
      'auditSchId': auditSchId,
      'activityType': activityType,
      'ticketType': ticketType,
      'companyName': companyName,
      'siteName': siteName,
      'siteAddress': siteAddress,
      'scheduledDate': scheduledDate,
      'dueDate': dueDate,
      'status': status,
      'priority': priority,
      'isDownloaded': isDownloaded,
      'isOfflineAvailable': isOfflineAvailable,
      'downloadedAt': downloadedAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'completeTicketData': completeTicketData,
      'formDataList': formDataList.map((e) => e.toJson()).toList(),
      'photos': photos.map((e) => e.toJson()).toList(),
      'remarks': remarks.map((e) => e.toJson()).toList(),
      'isPendingSync': isPendingSync,
      'lastSyncAttempt': lastSyncAttempt?.toIso8601String(),
      'syncRetryCount': syncRetryCount,
    };
  }

  factory OfflineTicket.fromJson(Map<String, dynamic> json) {
    return OfflineTicket(
      ticketId: json['ticketId'] ?? '',
      siteAuditSchId: json['siteAuditSchId'] ?? '',
      siteId: json['siteId'] ?? '',
      auditSchId: json['auditSchId'] ?? '',
      activityType: json['activityType'] ?? '',
      ticketType: json['ticketType'] ?? '',
      companyName: json['companyName'] ?? '',
      siteName: json['siteName'] ?? '',
      siteAddress: json['siteAddress'] ?? '',
      scheduledDate: json['scheduledDate'] ?? '',
      dueDate: json['dueDate'] ?? '',
      status: json['status'] ?? '',
      priority: json['priority'] ?? '',
      isDownloaded: json['isDownloaded'] ?? false,
      isOfflineAvailable: json['isOfflineAvailable'] ?? false,
      downloadedAt: DateTime.parse(json['downloadedAt']),
      lastModified: DateTime.parse(json['lastModified']),
      completeTicketData: Map<String, dynamic>.from(json['completeTicketData'] ?? {}),
      formDataList: (json['formDataList'] as List<dynamic>?)
          ?.map((e) => OfflineFormData.fromJson(e))
          .toList() ?? [],
      photos: (json['photos'] as List<dynamic>?)
          ?.map((e) => OfflinePhoto.fromJson(e))
          .toList() ?? [],
      remarks: (json['remarks'] as List<dynamic>?)
          ?.map((e) => OfflineRemark.fromJson(e))
          .toList() ?? [],
      isPendingSync: json['isPendingSync'] ?? false,
      lastSyncAttempt: json['lastSyncAttempt'] != null 
          ? DateTime.parse(json['lastSyncAttempt']) 
          : null,
      syncRetryCount: json['syncRetryCount'] ?? 0,
    );
  }
}

class OfflineFormData {
  final String screenName;
  final String itemType;
  final Map<String, dynamic> formData;
  final DateTime lastModified;
  final bool isPendingSync;
  final String? assetAuditSiteRespId;

  OfflineFormData({
    required this.screenName,
    required this.itemType,
    required this.formData,
    required this.lastModified,
    this.isPendingSync = false,
    this.assetAuditSiteRespId,
  });

  OfflineFormData copyWith({
    String? screenName,
    String? itemType,
    Map<String, dynamic>? formData,
    DateTime? lastModified,
    bool? isPendingSync,
    String? assetAuditSiteRespId,
  }) {
    return OfflineFormData(
      screenName: screenName ?? this.screenName,
      itemType: itemType ?? this.itemType,
      formData: formData ?? this.formData,
      lastModified: lastModified ?? this.lastModified,
      isPendingSync: isPendingSync ?? this.isPendingSync,
      assetAuditSiteRespId: assetAuditSiteRespId ?? this.assetAuditSiteRespId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'screenName': screenName,
      'itemType': itemType,
      'formData': formData,
      'lastModified': lastModified.toIso8601String(),
      'isPendingSync': isPendingSync,
      'assetAuditSiteRespId': assetAuditSiteRespId,
    };
  }

  factory OfflineFormData.fromJson(Map<String, dynamic> json) {
    return OfflineFormData(
      screenName: json['screenName'] ?? '',
      itemType: json['itemType'] ?? '',
      formData: Map<String, dynamic>.from(json['formData'] ?? {}),
      lastModified: DateTime.parse(json['lastModified']),
      isPendingSync: json['isPendingSync'] ?? false,
      assetAuditSiteRespId: json['assetAuditSiteRespId'],
    );
  }
}

class OfflinePhoto {
  final String photoId;
  final String photoPath;
  final String? base64Data;
  final String screenName;
  final String itemType;
  final DateTime takenAt;
  final bool isUploaded;
  final bool isPendingSync;
  final String? serverPhotoId;

  OfflinePhoto({
    required this.photoId,
    required this.photoPath,
    this.base64Data,
    required this.screenName,
    required this.itemType,
    required this.takenAt,
    this.isUploaded = false,
    this.isPendingSync = false,
    this.serverPhotoId,
  });

  OfflinePhoto copyWith({
    String? photoId,
    String? photoPath,
    String? base64Data,
    String? screenName,
    String? itemType,
    DateTime? takenAt,
    bool? isUploaded,
    bool? isPendingSync,
    String? serverPhotoId,
  }) {
    return OfflinePhoto(
      photoId: photoId ?? this.photoId,
      photoPath: photoPath ?? this.photoPath,
      base64Data: base64Data ?? this.base64Data,
      screenName: screenName ?? this.screenName,
      itemType: itemType ?? this.itemType,
      takenAt: takenAt ?? this.takenAt,
      isUploaded: isUploaded ?? this.isUploaded,
      isPendingSync: isPendingSync ?? this.isPendingSync,
      serverPhotoId: serverPhotoId ?? this.serverPhotoId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'photoId': photoId,
      'photoPath': photoPath,
      'base64Data': base64Data,
      'screenName': screenName,
      'itemType': itemType,
      'takenAt': takenAt.toIso8601String(),
      'isUploaded': isUploaded,
      'isPendingSync': isPendingSync,
      'serverPhotoId': serverPhotoId,
    };
  }

  factory OfflinePhoto.fromJson(Map<String, dynamic> json) {
    return OfflinePhoto(
      photoId: json['photoId'] ?? '',
      photoPath: json['photoPath'] ?? '',
      base64Data: json['base64Data'],
      screenName: json['screenName'] ?? '',
      itemType: json['itemType'] ?? '',
      takenAt: DateTime.parse(json['takenAt']),
      isUploaded: json['isUploaded'] ?? false,
      isPendingSync: json['isPendingSync'] ?? false,
      serverPhotoId: json['serverPhotoId'],
    );
  }
}

class OfflineRemark {
  final String remarkId;
  final String screenName;
  final String itemType;
  final String remarkText;
  final DateTime createdAt;
  final bool isPendingSync;
  final String? assetAuditSiteRespId;

  OfflineRemark({
    required this.remarkId,
    required this.screenName,
    required this.itemType,
    required this.remarkText,
    required this.createdAt,
    this.isPendingSync = false,
    this.assetAuditSiteRespId,
  });

  OfflineRemark copyWith({
    String? remarkId,
    String? screenName,
    String? itemType,
    String? remarkText,
    DateTime? createdAt,
    bool? isPendingSync,
    String? assetAuditSiteRespId,
  }) {
    return OfflineRemark(
      remarkId: remarkId ?? this.remarkId,
      screenName: screenName ?? this.screenName,
      itemType: itemType ?? this.itemType,
      remarkText: remarkText ?? this.remarkText,
      createdAt: createdAt ?? this.createdAt,
      isPendingSync: isPendingSync ?? this.isPendingSync,
      assetAuditSiteRespId: assetAuditSiteRespId ?? this.assetAuditSiteRespId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'remarkId': remarkId,
      'screenName': screenName,
      'itemType': itemType,
      'remarkText': remarkText,
      'createdAt': createdAt.toIso8601String(),
      'isPendingSync': isPendingSync,
      'assetAuditSiteRespId': assetAuditSiteRespId,
    };
  }

  factory OfflineRemark.fromJson(Map<String, dynamic> json) {
    return OfflineRemark(
      remarkId: json['remarkId'] ?? '',
      screenName: json['screenName'] ?? '',
      itemType: json['itemType'] ?? '',
      remarkText: json['remarkText'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      isPendingSync: json['isPendingSync'] ?? false,
      assetAuditSiteRespId: json['assetAuditSiteRespId'],
    );
  }
}
