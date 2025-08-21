import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/dashboard_model.dart';

void main() {
  group('DashboardModel Tests', () {
    test('should create DashboardModel from JSON', () {
      final json = {
        "Energy Readiing": [
          {
            "activity_type": "Energy Readiing",
            "ticket_code": "All Tickets",
            "ticket_cnt": 5
          },
          {
            "activity_type": "Energy Readiing",
            "ticket_code": "Due",
            "ticket_cnt": 2
          }
        ],
        "Preventive Maintenance": [
          {
            "activity_type": "Preventive Maintenance",
            "ticket_code": "All Tickets",
            "ticket_cnt": 3
          }
        ]
      };

      final dashboardModel = DashboardModel.fromJson(json);

      expect(dashboardModel.data, isNotNull);
      expect(dashboardModel.data!.length, 2);
      expect(dashboardModel.data!["Energy Readiing"]!.length, 2);
      expect(dashboardModel.data!["Preventive Maintenance"]!.length, 1);
      
      final energyReadingData = dashboardModel.data!["Energy Readiing"]!;
      expect(energyReadingData[0].activityType, "Energy Readiing");
      expect(energyReadingData[0].ticketCode, "All Tickets");
      expect(energyReadingData[0].ticketCnt, 5);
    });

    test('should handle empty JSON', () {
      final dashboardModel = DashboardModel.fromJson({});
      expect(dashboardModel.data, isNotNull);
      expect(dashboardModel.data!.isEmpty, true);
    });

    test('should handle null JSON', () {
      final dashboardModel = DashboardModel.fromJson(null);
      expect(dashboardModel.data, isNotNull);
      expect(dashboardModel.data!.isEmpty, true);
    });
  });

  group('TicketData Tests', () {
    test('should create TicketData from JSON', () {
      final json = {
        "activity_type": "Asset Audit",
        "ticket_code": "Completed",
        "ticket_cnt": 10
      };

      final ticketData = TicketData.fromJson(json);

      expect(ticketData.activityType, "Asset Audit");
      expect(ticketData.ticketCode, "Completed");
      expect(ticketData.ticketCnt, 10);
    });

    test('should convert to JSON', () {
      final ticketData = TicketData(
        activityType: "Test Activity",
        ticketCode: "Test Code",
        ticketCnt: 15,
      );

      final json = ticketData.toJson();

      expect(json["activity_type"], "Test Activity");
      expect(json["ticket_code"], "Test Code");
      expect(json["ticket_cnt"], 15);
    });
  });
}
