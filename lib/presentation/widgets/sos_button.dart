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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _onPressStart(),
      onLongPressEnd: (_) => _onPressEnd(),
      onLongPressCancel: () => _onPressCancel(),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isPressed ? 1.0 : _pulseAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _isPressed ? AppColors.error : AppColors.coral,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (_isPressed ? AppColors.error : AppColors.coral)
                    .withValues(alpha: 0.3),
                blurRadius: 12,
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
