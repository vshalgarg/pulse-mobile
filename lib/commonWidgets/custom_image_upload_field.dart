import 'dart:convert';
import 'dart:io';

import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadField extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final bool isRequired;
  final bool isDisabled;
  final Function(File?) onImageSelected;
  final String? externalImageUrl;

  const ImageUploadField({
    super.key,
    this.label,
    this.placeholder,
    this.isRequired = false,
    this.isDisabled = false,
    required this.onImageSelected,
    this.externalImageUrl,
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  Widget? _externalImageWidget;
  String? _lastExternalUrl;

  bool _isLoading = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _loadExternalImage();
  }

  @override
  void didUpdateWidget(ImageUploadField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.externalImageUrl != oldWidget.externalImageUrl) {
      _loadExternalImage();
    }
  }

  void _loadExternalImage() {
    final url = widget.externalImageUrl;

    if (url == null || url.isEmpty) {
      _externalImageWidget = null;
      return;
    }

    if (_lastExternalUrl == url) return;

    _lastExternalUrl = url;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _externalImageWidget = _buildImageFromUrl(url);
      });
    });
  }

  Future<void> _pickImage() async {
    if (_isPickingImage || widget.isDisabled) return;

    _isPickingImage = true;

    try {
      setState(() {
        _isLoading = true;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,

        // VERY IMPORTANT FOR STABILITY
        imageQuality: 60,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (!mounted) return;

      if (image == null) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(image.path);

      if (!file.existsSync()) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _selectedImage = file;
        _isLoading = false;
      });

      widget.onImageSelected(file);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to open camera on this device"),
        ),
      );
    } finally {
      _isPickingImage = false;
    }
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, size: 22),
          const SizedBox(width: 6),
          Text(widget.placeholder ?? "Take Photo"),
        ],
      ),
    );
  }

  Widget _buildImageFromUrl(String url) {
    try {
      if (url.startsWith('data:image')) {
        final parts = url.split(',');
        if (parts.length < 2) return _buildPlaceholder();

        final bytes = base64Decode(parts[1]);

        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }

      if (url.startsWith('/data/') ||
          url.endsWith('.jpg') ||
          url.endsWith('.png')) {
        final file = File(url);

        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }
      }

      final bytes = base64Decode(url);

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } catch (_) {
      return _buildPlaceholder();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (_selectedImage != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    } else if (_externalImageWidget != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _externalImageWidget!,
      );
    } else {
      child = _buildPlaceholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label!,
                 style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: fontFamilyMontserrat,
                   
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isRequired)
                const Text(
                  " *",
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: widget.isDisabled ? null : _pickImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: widget.isDisabled ? Colors.grey.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}