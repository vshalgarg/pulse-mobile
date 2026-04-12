import 'dart:io';

import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays a local video file (e.g. temp file from `DocumentById`) in a dialog.
class ActivityTicketVideoPreviewDialog extends StatefulWidget {
  const ActivityTicketVideoPreviewDialog({
    super.key,
    required this.videoFile,
  });

  final File videoFile;

  @override
  State<ActivityTicketVideoPreviewDialog> createState() =>
      _ActivityTicketVideoPreviewDialogState();
}

class _ActivityTicketVideoPreviewDialogState
    extends State<ActivityTicketVideoPreviewDialog> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  Object? _error;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.file(widget.videoFile);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }

      final ar = c.value.aspectRatio;
      final safeAr = (ar > 0 && ar.isFinite) ? ar : (16 / 9);

      _videoPlayerController = c;
      _chewieController = ChewieController(
        videoPlayerController: c,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        aspectRatio: safeAr,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primaryGreen,
          handleColor: AppColors.primaryGreen,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white24,
        ),
      );
      if (mounted) {
        setState(() => _initializing = false);
      }
    } catch (e) {
      if (c != null) {
        await c.dispose();
      }
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = e;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * 0.42;
    final maxW = mq.size.width - 48;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH + 100),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Video preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: poppins,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: maxH,
                width: maxW,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: Colors.black,
                    child: _initializing
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                          )
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Could not play this video.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red.shade200,
                                      fontFamily: poppins,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              )
                            : _chewieController != null
                                ? Chewie(controller: _chewieController!)
                                : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
