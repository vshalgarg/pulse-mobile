// import 'package:flutter/material.dart';
// import '../constants/app_colors.dart';
//
// class OfflineIndicator extends StatelessWidget {
//   final bool isOffline;
//   final bool hasPendingSync;
//   final VoidCallback? onSyncTap;
//   final String? syncMessage;
//
//   const OfflineIndicator({
//     super.key,
//     required this.isOffline,
//     this.hasPendingSync = false,
//     this.onSyncTap,
//     this.syncMessage,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     if (!isOffline && !hasPendingSync) {
//       return const SizedBox.shrink();
//     }
//
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: isOffline ? AppColors.warningColor : AppColors.infoColor,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(
//           color: isOffline ? AppColors.warningColor : AppColors.infoColor,
//           width: 1,
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             isOffline ? Icons.cloud_off : Icons.sync,
//             color: Colors.white,
//             size: 16,
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               _getMessage(),
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//           if (hasPendingSync && onSyncTap != null)
//             GestureDetector(
//               onTap: onSyncTap,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: const Text(
//                   'Sync',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   String _getMessage() {
//     if (isOffline) {
//       return 'Working offline - Data saved locally';
//     } else if (hasPendingSync) {
//       return syncMessage ?? 'Pending sync - Tap to sync data';
//     }
//     return '';
//   }
// }
//
// class OfflineBadge extends StatelessWidget {
//   final bool isOffline;
//   final bool hasPendingSync;
//   final double size;
//
//   const OfflineBadge({
//     super.key,
//     required this.isOffline,
//     this.hasPendingSync = false,
//     this.size = 20,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     if (!isOffline && !hasPendingSync) {
//       return const SizedBox.shrink();
//     }
//
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(
//         color: isOffline ? AppColors.warningColor : AppColors.infoColor,
//         shape: BoxShape.circle,
//         border: Border.all(
//           color: Colors.white,
//           width: 1,
//         ),
//       ),
//       child: Icon(
//         isOffline ? Icons.cloud_off : Icons.sync,
//         color: Colors.white,
//         size: size * 0.6,
//       ),
//     );
//   }
// }
//
// class OfflineStatusBar extends StatelessWidget {
//   final bool isOffline;
//   final bool hasPendingSync;
//   final int pendingCount;
//   final VoidCallback? onSyncTap;
//
//   const OfflineStatusBar({
//     super.key,
//     required this.isOffline,
//     this.hasPendingSync = false,
//     this.pendingCount = 0,
//     this.onSyncTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     if (!isOffline && !hasPendingSync) {
//       return const SizedBox.shrink();
//     }
//
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: isOffline ? AppColors.warningColor : AppColors.infoColor,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Icon(
//             isOffline ? Icons.cloud_off : Icons.sync,
//             color: Colors.white,
//             size: 18,
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               _getStatusMessage(),
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//           if (hasPendingSync && onSyncTap != null)
//             GestureDetector(
//               onTap: onSyncTap,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(
//                       Icons.sync,
//                       color: Colors.white,
//                       size: 16,
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       'Sync ($pendingCount)',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   String _getStatusMessage() {
//     if (isOffline) {
//       return 'Working offline - All changes saved locally';
//     } else if (hasPendingSync) {
//       return 'You have $pendingCount pending changes to sync';
//     }
//     return '';
//   }
// }
//
// class OfflineFloatingButton extends StatelessWidget {
//   final bool isOffline;
//   final bool hasPendingSync;
//   final int pendingCount;
//   final VoidCallback? onSyncTap;
//
//   const OfflineFloatingButton({
//     super.key,
//     required this.isOffline,
//     this.hasPendingSync = false,
//     this.pendingCount = 0,
//     this.onSyncTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     if (!isOffline && !hasPendingSync) {
//       return const SizedBox.shrink();
//     }
//
//     return Positioned(
//       bottom: 16,
//       right: 16,
//       child: GestureDetector(
//         onTap: onSyncTap,
//         child: Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: isOffline ? AppColors.warningColor : AppColors.infoColor,
//             shape: BoxShape.circle,
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 blurRadius: 8,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Stack(
//             children: [
//               Icon(
//                 isOffline ? Icons.cloud_off : Icons.sync,
//                 color: Colors.white,
//                 size: 24,
//               ),
//               if (hasPendingSync && pendingCount > 0)
//                 Positioned(
//                   top: -2,
//                   right: -2,
//                   child: Container(
//                     padding: const EdgeInsets.all(4),
//                     decoration: const BoxDecoration(
//                       color: AppColors.errorColor,
//                       shape: BoxShape.circle,
//                     ),
//                     constraints: const BoxConstraints(
//                       minWidth: 16,
//                       minHeight: 16,
//                     ),
//                     child: Text(
//                       pendingCount > 99 ? '99+' : pendingCount.toString(),
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
