import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';

class DashboardLoadingWidget extends StatelessWidget {
  const DashboardLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            _buildAuditSectionSkeleton("Asset Audit"),
            const SizedBox(height: 15),
            _buildAuditSectionSkeleton("Preventive Maintenance"),
            const SizedBox(height: 15),
            _buildAuditSectionSkeleton("Energy Reading"),
            const SizedBox(height: 15),
            _buildCorrectiveMaintenanceSkeleton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditSectionSkeleton(String title) {
    return Column(
      children: [
        // Header skeleton
        Container(
          height: 45,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.auditColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              fontFamily: dmSans,
              color: AppColors.white,
            ),
          ),
        ),
        const SizedBox(height: 5),
        // Status cards skeleton
        _buildStatusCardsSkeleton(),
      ],
    );
  }

  Widget _buildCorrectiveMaintenanceSkeleton() {
    return Column(
      children: [
        // Header with add button skeleton
        Row(
          children: [
            Expanded(
              child: Container(
                height: 45,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  color: AppColors.auditColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(5),
                    bottomLeft: Radius.circular(5),
                    bottomRight: Radius.circular(5),
                  ),
                ),
                child: Text(
                  "Corrective Maintenance",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    fontFamily: dmSans,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 45,
              width: 45,
              decoration: BoxDecoration(
                color: AppColors.auditColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  topLeft: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
              ),
              child: Icon(
                Icons.add,
                color: AppColors.white,
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Status cards skeleton (different layout for CM)
        _buildCorrectiveMaintenanceCardsSkeleton(),
      ],
    );
  }

  Widget _buildStatusCardsSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          // First row - All Tickets and In Progress
          Row(
            children: [
              Expanded(
                child: _buildStatusCardSkeleton(),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _buildStatusCardSkeleton(),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Second row - Completed and Closed
          Row(
            children: [
              Expanded(
                child: _buildStatusCardSkeleton(),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _buildStatusCardSkeleton(),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Third row - Missed Deadline (single card)
          Row(
            children: [
              Expanded(
                child: _buildStatusCardSkeleton(),
              ),
              const SizedBox(width: 5),
              Expanded(child: Container()),
            ],
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildCorrectiveMaintenanceCardsSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          // First row - All Tickets and In Progress
          Row(
            children: [
              Expanded(
                child: _buildStatusCardSkeleton(),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _buildStatusCardSkeleton(),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Second row - Assigned to Me and Closed
          Row(
            children: [
              Expanded(
                child: _buildStatusCardSkeleton(),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _buildStatusCardSkeleton(),
              ),
            ],
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildStatusCardSkeleton() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title skeleton
            Container(
              height: 12,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Count skeleton
            Container(
              height: 20,
              width: 30,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
