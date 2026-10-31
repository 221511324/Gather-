import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Every remote image in the app goes through here so caching, the loading
/// placeholder and the failure state look the same everywhere.
class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 0,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final image = url.isEmpty
        ? _placeholder(const Icon(Icons.restaurant_rounded, color: AppColors.inkFaint, size: 28))
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 220),
            placeholder: (_, _) => _placeholder(null),
            errorWidget: (_, _, _) => _placeholder(
              const Icon(Icons.image_not_supported_outlined, color: AppColors.inkFaint, size: 24),
            ),
          );

    if (radius <= 0) return image;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }

  Widget _placeholder(Widget? child) => Container(
        width: width,
        height: height,
        color: AppColors.primarySoft,
        alignment: Alignment.center,
        child: child,
      );
}
