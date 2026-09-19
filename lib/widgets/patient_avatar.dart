import 'dart:io';

import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:btih_andriod_app/utils/doctor_image_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular profile avatar — photo when available, otherwise name initial.
class PatientAvatar extends StatelessWidget {
  final String displayName;
  final String? imageUrl;
  final File? localFile;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool showBorder;
  final Color? borderColor;

  const PatientAvatar({
    super.key,
    required this.displayName,
    this.imageUrl,
    this.localFile,
    this.size = 40,
    this.backgroundColor = AppColors.blush,
    this.foregroundColor = AppColors.primaryRed,
    this.showBorder = false,
    this.borderColor,
  });

  String get _initial {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'P';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DoctorImageHelper.resolve(imageUrl);
    final hasNetwork = resolved != null && resolved.isNotEmpty;
    final hasLocal = localFile != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppColors.white.withValues(alpha: 0.35),
                width: 2,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasLocal
          ? Image.file(
              localFile!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
          : hasNetwork
              ? CachedNetworkImage(
                  imageUrl: resolved!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _Initial(
                    initial: _initial,
                    size: size,
                    color: foregroundColor,
                  ),
                  errorWidget: (_, __, ___) => _Initial(
                    initial: _initial,
                    size: size,
                    color: foregroundColor,
                  ),
                )
              : _Initial(
                  initial: _initial,
                  size: size,
                  color: foregroundColor,
                ),
    );
  }
}

class _Initial extends StatelessWidget {
  final String initial;
  final double size;
  final Color color;

  const _Initial({
    required this.initial,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: AppTypography.montserrat(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}
