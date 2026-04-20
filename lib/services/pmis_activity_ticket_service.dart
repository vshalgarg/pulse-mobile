import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/pmis_activity_ticket_model.dart';
import 'api_service.dart';

class PmisActivityTicketService {
  final ApiService _apiService;

  PmisActivityTicketService({required ApiService apiService})
      : _apiService = apiService;

  static const String _pathPrefix = 'pmis/api/v1/project-plan/activity-ticket';

  static Map<String, dynamic>? normalizeActivityTicketResponseBody(
    dynamic data,
  ) {
    if (data is! Map) return null;
    var body = Map<String, dynamic>.from(data);
    final inner = body['data'];
    if (inner is Map) {
      final innerMap = Map<String, dynamic>.from(inner);
      final topTv = body['ticketFieldValues'];
      final innerTv = innerMap['ticketFieldValues'];
      final topTvEmpty = topTv == null || (topTv is List && topTv.isEmpty);
      final innerTvNonempty = innerTv is List && innerTv.isNotEmpty;

      if (body['ticketCheckers'] == null &&
          innerMap['ticketCheckers'] != null) {
        body = innerMap;
      } else if (topTvEmpty && innerTvNonempty) {
        body = innerMap;
      }
    }
    return body;
  }

  Future<ResponseResult<PmisActivityTicketDetail>> getActivityTicket({
    required int activityTicketId,
  }) async {
    try {
      final dio = _apiService.apiProvider.getClient();
       final response = await dio.get('$_pathPrefix/$activityTicketId');

      //20854
        // final response = await dio.get('$_pathPrefix/20854');

      if (response.statusCode == 200) {
        final body = normalizeActivityTicketResponseBody(response.data);
        if (body != null) {
          final ticket = PmisActivityTicketDetail.fromJson(body);
          return ResponseResult.success(ticket, response.statusCode);
        }
        return ResponseResult.error(
          errorMessage: 'Unexpected response format',
          statusCode: response.statusCode,
        );
      }

      return ResponseResult.error(
        errorMessage: 'Request failed with status code: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('❌ PmisActivityTicketService.getActivityTicket: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }

  Future<ResponseResult<Map<String, dynamic>>> getActivityTicketRawBody({
    required int activityTicketId,
  }) async {
    try {
      final dio = _apiService.apiProvider.getClient();
      final response = await dio.get('$_pathPrefix/$activityTicketId');

      if (response.statusCode == 200) {
        final body = normalizeActivityTicketResponseBody(response.data);
        if (body != null) {
          final copy = Map<String, dynamic>.from(
            jsonDecode(jsonEncode(body)) as Map,
          );
          return ResponseResult.success(copy, response.statusCode);
        }
        return ResponseResult.error(
          errorMessage: 'Unexpected response format',
          statusCode: response.statusCode,
        );
      }

      return ResponseResult.error(
        errorMessage: 'Request failed with status code: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('❌ PmisActivityTicketService.getActivityTicketRawBody: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }

  /// Loads the ticket then warms `/api/v1/common/DocumentById/{id}` for every
  /// IMAGE / VIDEO / PDF attachment id (before opening the checker list).
  Future<ResponseResult<PmisActivityTicketDetail>>
      getActivityTicketWithDocumentWarmup({
    required int activityTicketId,
  }) async {
    final ticketRes = await getActivityTicket(
      activityTicketId: activityTicketId,
    );
    if (!ticketRes.isSuccess || ticketRes.data == null) {
      return ticketRes;
    }
    final ids = collectPmisActivityTicketDocumentIds(ticketRes.data!);
    if (ids.isEmpty) return ticketRes;

    await Future.wait(
      ids.map((id) async {
        try {
          await _apiService.get<Uint8List>(
            path: '/api/v1/common/DocumentById/$id',
            responseType: ResponseType.bytes,
          );
        } catch (e) {
          debugPrint(
            '⚠️ PmisActivityTicketService DocumentById warm-up failed ($id): $e',
          );
        }
      }),
    );
    return ticketRes;
  }

  Future<ResponseResult<Map<String, dynamic>?>> postActivityTicket({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final result = await _apiService.post<Map<String, dynamic>>(
        path: _pathPrefix,
        data: payload,
        useFormDataFormat: false,
      );

      if (!result.isSuccess) {
        return ResponseResult.error(
          errorMessage: result.errorMessage ?? 'Failed to post activity ticket',
          statusCode: result.statusCode,
          dioErrorType: result.dioErrorType,
        );
      }

      return ResponseResult.success(result.data, result.statusCode);
    } catch (e) {
      debugPrint('❌ PmisActivityTicketService.postActivityTicket: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
