import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'widgets/scan_frame_overlay.dart';

/// Camera screen (Screen 1B) — capture or pick a hearing aid photo.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (image != null && context.mounted) {
      context.push('/scan/analysing', extra: image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
        title: const Text('Scan Hearing Aid'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Viewfinder area ──────────────────────────────────────
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Placeholder — will show live camera feed in Phase 2
                  Container(color: Colors.grey[900]),
                  const ScanFrameOverlay(),
                  Positioned(
                    bottom: 48,
                    child: Text(
                      'Position the hearing aid inside the frame',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ── Capture controls ─────────────────────────────────────
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery pick
                  IconButton(
                    onPressed: () => _pickImage(context, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined,
                        color: AppColors.white, size: 28),
                  ),
                  // Shutter button
                  GestureDetector(
                    onTap: () => _pickImage(context, ImageSource.camera),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  // Spacer for symmetry
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
