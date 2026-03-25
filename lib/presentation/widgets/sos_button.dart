/// SOS 按钮组件
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/constants.dart';
import '../../core/router/app_router.dart';

class SosButton extends StatefulWidget {
  const SosButton({super.key});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = AppColors.coral;

    return GestureDetector(
      onLongPressStart: (_) => _onPressStart(),
      onLongPressEnd: (_) => _onPressEnd(),
      onLongPressCancel: () => _onPressCancel(),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          // 呼吸外发光：模糊 12→28px，扩散 0→6px，透明度同步呼吸
          final glowBlur = _isPressed ? 12.0 : 12.0 + _glowAnimation.value * 16.0;
          final glowSpread = _isPressed ? 0.0 : _glowAnimation.value * 6.0;
          final glowOpacity = _isPressed ? 0.3 : 0.3 - _glowAnimation.value * 0.12;

          return Transform.scale(
            scale: _isPressed ? 1.0 : _pulseAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: _isPressed ? AppColors.error : buttonColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (_isPressed ? AppColors.error : buttonColor)
                        .withValues(alpha: glowOpacity),
                    blurRadius: glowBlur,
                    spreadRadius: glowSpread,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emergency,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPressed ? AppTexts.releaseToCancel : '紧急求助',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onPressStart() {
    HapticFeedback.heavyImpact();
    setState(() => _isPressed = true);
    _pulseController.stop();
    _startProgress();
  }

  int _count = 0;
  void _startProgress() {
    _count = 0;
    _progressLoop();
  }

  void _progressLoop() {
    if (!_isPressed) return;
    _count++;
    if (_count >= 30) {
      _triggerSos();
      return;
    }
    Future.delayed(const Duration(milliseconds: 100), _progressLoop);
  }

  void _onPressEnd() {
    HapticFeedback.lightImpact();
    setState(() => _isPressed = false);
    _count = 0;
    _pulseController.repeat(reverse: true);
  }

  void _onPressCancel() {
    setState(() => _isPressed = false);
    _count = 0;
    _pulseController.repeat(reverse: true);
  }

  void _triggerSos() {
    HapticFeedback.heavyImpact();
    context.push(AppRoutes.sos);
  }
}
