import 'package:app/models/it_asset_code_model.dart';
import 'package:app/models/it_asset_type_model.dart';
import 'package:app/models/raise_it_ticket_detail_model.dart';
import 'package:app/models/raise_it_ticket_model.dart';
import 'package:app/models/raise_it_ticket_request_model.dart';
import 'package:app/models/raise_ticket_assigned_to_model.dart';
import 'package:app/services/raise_it_ticket_service.dart';
import 'package:app/utils/logger.dart';

class RaiseItTicketRepository {
  final RaiseItTicketService _service;

  RaiseItTicketRepository({required RaiseItTicketService service})
      : _service = service;

  Future<List<ItAssetType>> getAssetType() async {
    try {
      Logger.debugLog('[RaiseItTicketRepository] Fetching asset type dropdown');
      final result = await _service.getAssetType();

      if (result.isSuccess && result.data != null) {
        Logger.infoLog(
          '[RaiseItTicketRepository] Loaded ${result.data!.length} asset types',
        );
        return result.data!;
      }

      throw Exception(result.errorMessage ?? 'Failed to load asset types');
    } catch (e) {
      Logger.errorLog('[RaiseItTicketRepository] Exception in getAssetType: $e');
      rethrow;
    }
  }

  /// Asset codes for the selected asset type ([iatmId] from [getAssetType]).
  Future<ItAssetCodeDropdown> getAssetCode(int iatmId) async {
    try {
      Logger.debugLog(
        '[RaiseItTicketRepository] Fetching asset code dropdown for iatmId: $iatmId',
      );
      final result = await _service.getAssetCode(iatmId);

      if (result.isSuccess && result.data != null) {
        final count = result.data!.allAssets.length;
        Logger.infoLog(
          '[RaiseItTicketRepository] Loaded $count asset code(s) for iatmId $iatmId',
        );
        return result.data!;
      }

      throw Exception(result.errorMessage ?? 'Failed to load asset codes');
    } catch (e) {
      Logger.errorLog('[RaiseItTicketRepository] Exception in getAssetCode: $e');
      rethrow;
    }
  }

  Future<List<RaiseTicketAssignedTo>> getRaiseTicketAssignedTo() async {
    try {
      Logger.debugLog(
        '[RaiseItTicketRepository] Fetching raise ticket assigned-to dropdown',
      );
      final result = await _service.getRaiseTicketAssignedTo();

      if (result.isSuccess && result.data != null) {
        Logger.infoLog(
          '[RaiseItTicketRepository] Loaded ${result.data!.length} assignee(s)',
        );
        return result.data!;
      }

      throw Exception(
        result.errorMessage ?? 'Failed to load assigned-to list',
      );
    } catch (e) {
      Logger.errorLog(
        '[RaiseItTicketRepository] Exception in getRaiseTicketAssignedTo: $e',
      );
      rethrow;
    }
  }

  Future<List<RaiseItTicket>> getAllRaiseTickets() async {
    try {
      Logger.debugLog('[RaiseItTicketRepository] Fetching all raise IT tickets');
      final result = await _service.getAllRaiseTickets();

      if (result.isSuccess && result.data != null) {
        Logger.infoLog(
          '[RaiseItTicketRepository] Loaded ${result.data!.length} ticket(s)',
        );
        return result.data!;
      }

      throw Exception(
        result.errorMessage ?? 'Failed to load raise IT tickets',
      );
    } catch (e) {
      Logger.errorLog(
        '[RaiseItTicketRepository] Exception in getAllRaiseTickets: $e',
      );
      rethrow;
    }
  }

  Future<RaiseItTicketDetail> getRaiseTicketData(int iaitId) async {
    try {
      Logger.debugLog(
        '[RaiseItTicketRepository] Fetching raise IT ticket iaitId: $iaitId',
      );
      final result = await _service.getRaiseTicketData(iaitId);

      if (result.isSuccess && result.data != null) {
        Logger.infoLog(
          '[RaiseItTicketRepository] Loaded ticket ${result.data!.ticketNumber}',
        );
        return result.data!;
      }

      throw Exception(
        result.errorMessage ?? 'Failed to load raise IT ticket',
      );
    } catch (e) {
      Logger.errorLog(
        '[RaiseItTicketRepository] Exception in getRaiseTicketData: $e',
      );
      rethrow;
    }
  }

  Future<void> postRaiseITTicket(RaiseItTicketRequest request) async {
    try {
      Logger.debugLog(
        '[RaiseItTicketRepository] Posting raise IT ticket: ${request.toJson()}',
      );
      final result = await _service.postRaiseITTicket(request);

      if (result.success) {
        Logger.infoLog(
          '[RaiseItTicketRepository] Raise IT ticket created successfully',
        );
        return;
      }

      throw Exception(result.errorMessage ?? 'Failed to raise IT ticket');
    } catch (e) {
      Logger.errorLog(
        '[RaiseItTicketRepository] Exception in postRaiseITTicket: $e',
      );
      rethrow;
    }
  }
}
