// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_ticket_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineTicketAdapter extends TypeAdapter<OfflineTicket> {
  @override
  final int typeId = 0;

  @override
  OfflineTicket read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineTicket(
      ticketId: fields[0] as String,
      siteAuditSchId: fields[1] as String,
      siteId: fields[2] as String,
      auditSchId: fields[3] as String,
      activityType: fields[4] as String,
      ticketType: fields[5] as String,
      companyName: fields[6] as String,
      siteName: fields[7] as String,
      siteAddress: fields[8] as String,
      scheduledDate: fields[9] as String,
      dueDate: fields[10] as String,
      status: fields[11] as String,
      priority: fields[12] as String,
      isDownloaded: fields[13] as bool,
      isOfflineAvailable: fields[14] as bool,
      downloadedAt: fields[15] as DateTime,
      lastModified: fields[16] as DateTime,
      completeTicketData: fields[17] as Map<String, dynamic>,
      formDataList: (fields[18] as List).cast<OfflineFormData>(),
      photos: (fields[19] as List).cast<OfflinePhoto>(),
      remarks: (fields[20] as List).cast<OfflineRemark>(),
      isPendingSync: fields[21] as bool,
      lastSyncAttempt: fields[22] as DateTime?,
      syncRetryCount: fields[23] as int,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineTicket obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.ticketId)
      ..writeByte(1)
      ..write(obj.siteAuditSchId)
      ..writeByte(2)
      ..write(obj.siteId)
      ..writeByte(3)
      ..write(obj.auditSchId)
      ..writeByte(4)
      ..write(obj.activityType)
      ..writeByte(5)
      ..write(obj.ticketType)
      ..writeByte(6)
      ..write(obj.companyName)
      ..writeByte(7)
      ..write(obj.siteName)
      ..writeByte(8)
      ..write(obj.siteAddress)
      ..writeByte(9)
      ..write(obj.scheduledDate)
      ..writeByte(10)
      ..write(obj.dueDate)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.priority)
      ..writeByte(13)
      ..write(obj.isDownloaded)
      ..writeByte(14)
      ..write(obj.isOfflineAvailable)
      ..writeByte(15)
      ..write(obj.downloadedAt)
      ..writeByte(16)
      ..write(obj.lastModified)
      ..writeByte(17)
      ..write(obj.completeTicketData)
      ..writeByte(18)
      ..write(obj.formDataList)
      ..writeByte(19)
      ..write(obj.photos)
      ..writeByte(20)
      ..write(obj.remarks)
      ..writeByte(21)
      ..write(obj.isPendingSync)
      ..writeByte(22)
      ..write(obj.lastSyncAttempt)
      ..writeByte(23)
      ..write(obj.syncRetryCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineTicketAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineFormDataAdapter extends TypeAdapter<OfflineFormData> {
  @override
  final int typeId = 1;

  @override
  OfflineFormData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineFormData(
      screenName: fields[0] as String,
      itemType: fields[1] as String,
      formData: fields[2] as Map<String, dynamic>,
      lastModified: fields[3] as DateTime,
      isPendingSync: fields[4] as bool,
      assetAuditSiteRespId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineFormData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.screenName)
      ..writeByte(1)
      ..write(obj.itemType)
      ..writeByte(2)
      ..write(obj.formData)
      ..writeByte(3)
      ..write(obj.lastModified)
      ..writeByte(4)
      ..write(obj.isPendingSync)
      ..writeByte(5)
      ..write(obj.assetAuditSiteRespId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineFormDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflinePhotoAdapter extends TypeAdapter<OfflinePhoto> {
  @override
  final int typeId = 2;

  @override
  OfflinePhoto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflinePhoto(
      photoId: fields[0] as String,
      photoPath: fields[1] as String,
      base64Data: fields[2] as String?,
      screenName: fields[3] as String,
      itemType: fields[4] as String,
      takenAt: fields[5] as DateTime,
      isUploaded: fields[6] as bool,
      isPendingSync: fields[7] as bool,
      serverPhotoId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflinePhoto obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.photoId)
      ..writeByte(1)
      ..write(obj.photoPath)
      ..writeByte(2)
      ..write(obj.base64Data)
      ..writeByte(3)
      ..write(obj.screenName)
      ..writeByte(4)
      ..write(obj.itemType)
      ..writeByte(5)
      ..write(obj.takenAt)
      ..writeByte(6)
      ..write(obj.isUploaded)
      ..writeByte(7)
      ..write(obj.isPendingSync)
      ..writeByte(8)
      ..write(obj.serverPhotoId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflinePhotoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineRemarkAdapter extends TypeAdapter<OfflineRemark> {
  @override
  final int typeId = 3;

  @override
  OfflineRemark read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineRemark(
      remarkId: fields[0] as String,
      screenName: fields[1] as String,
      itemType: fields[2] as String,
      remarkText: fields[3] as String,
      createdAt: fields[4] as DateTime,
      isPendingSync: fields[5] as bool,
      assetAuditSiteRespId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineRemark obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.remarkId)
      ..writeByte(1)
      ..write(obj.screenName)
      ..writeByte(2)
      ..write(obj.itemType)
      ..writeByte(3)
      ..write(obj.remarkText)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.isPendingSync)
      ..writeByte(6)
      ..write(obj.assetAuditSiteRespId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineRemarkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
