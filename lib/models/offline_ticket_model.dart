import 'package:hive/hive.dart';

part 'offline_ticket_model.g.dart';

@HiveType(typeId: 0)
class OfflineTicket extends HiveObject {
  @HiveField(0)
  final String ticketId;

  @HiveField(1)
  final String siteAuditSchId;

  @HiveField(2)
  final String siteId;

  @HiveField(3)
  final String auditSchId;

  @HiveField(4)
  final String activityType;

  @HiveField(5)
  final String ticketType;

  @HiveField(6)
  final String companyName;

  @HiveField(7)
  final String siteName;

  @HiveField(8)
  final String siteAddress;

  @HiveField(9)
  final String scheduledDate;

  @HiveField(10)
  final String dueDate;

  @HiveField(11)
  final String status;

  @HiveField(12)
  final String priority;

  @HiveField(13)
  final bool isDownloaded;

  @HiveField(14)
  final bool isOfflineAvailable;

  @HiveField(15)
  final DateTime downloadedAt;

  @HiveField(16)
  final DateTime lastModified;

  @HiveField(17)
  final Map<String, dynamic> completeTicketData;

  @HiveField(18)
  final List<OfflineFormData> formDataList;

  @HiveField(19)
  final List<OfflinePhoto> photos;

  @HiveField(20)
  final List<OfflineRemark> remarks;

  @HiveField(21)
  final bool isPendingSync;

  @HiveField(22)
  final DateTime? lastSyncAttempt;

  @HiveField(23)
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

@HiveType(typeId: 1)
class OfflineFormData extends HiveObject {
  @HiveField(0)
  final String screenName;

  @HiveField(1)
  final String itemType;

  @HiveField(2)
  final Map<String, dynamic> formData;

  @HiveField(3)
  final DateTime lastModified;

  @HiveField(4)
  final bool isPendingSync;

  @HiveField(5)
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

@HiveType(typeId: 2)
class OfflinePhoto extends HiveObject {
  @HiveField(0)
  final String photoId;

  @HiveField(1)
  final String photoPath;

  @HiveField(2)
  final String? base64Data;

  @HiveField(3)
  final String screenName;

  @HiveField(4)
  final String itemType;

  @HiveField(5)
  final DateTime takenAt;

  @HiveField(6)
  final bool isUploaded;

  @HiveField(7)
  final bool isPendingSync;

  @HiveField(8)
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

@HiveType(typeId: 3)
class OfflineRemark extends HiveObject {
  @HiveField(0)
  final String remarkId;

  @HiveField(1)
  final String screenName;

  @HiveField(2)
  final String itemType;

  @HiveField(3)
  final String remarkText;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final bool isPendingSync;

  @HiveField(6)
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
