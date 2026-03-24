/// SOS 紧急求助页
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> with SingleTickerProviderStateMixin {
  bool _isPressing = false;
  double _pressProgress = 0;
  bool _isTriggered = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isTriggered ? AppColors.error : AppColors.background,
      appBar: _isTriggered
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
            ),
      body: _isTriggered ? _buildTriggeredView() : _buildTriggerView(),
    );
  }

  Widget _buildTriggerView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🆘 紧急求助 🆘',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppTexts.sosDescription,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 60),
            // 长按按钮
            GestureDetector(
              onLongPressStart: (_) => _startPress(),
              onLongPressEnd: (_) => _endPress(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: _isPressing
                      ? AppColors.coral
                      : AppColors.coral.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.coral,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: _isPressing ? Colors.white : AppColors.coral,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isPressing
                  ? '保持按压中... ${(_pressProgress * 3).toInt()} 秒'
                  : '长按 3 秒触发',
              style: TextStyle(
                fontSize: 14,
                color: _isPressing ? AppColors.coral : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 60),
            // 紧急信息卡
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('👴', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      const Text(
                        '紧急信息',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('血型', 'A型'),
                  _buildInfoRow('过敏', '⚠️ 青霉素'),
                  _buildInfoRow('病史', '高血压10年、糖尿病5年'),
                  _buildInfoRow('主治医生', '王建国 138****8888'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggeredView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              '🆘 SOS 已发出 🆘',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '紧急求助已发送给所有家人',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 40),
            // 成员确认状态
            Expanded(
              child: ListView(
                children: [
                  _buildConfirmItem('大女儿', true),
                  _buildConfirmItem('儿子', false),
                  _buildConfirmItem('保姆（小梅）', false),
                  _buildConfirmItem('爷爷', false),
                ],
              ),
            ),
            // 紧急电话按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      // TODO: 拨打120
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('拨打 120'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('取消'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmItem(String name, bool confirmed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            confirmed ? Icons.check_circle : Icons.access_time,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const Spacer(),
          Text(
            confirmed ? '已确认' : '确认中...',
            style: TextStyle(
              color: confirmed ? Colors.white70 : Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _startPress() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isPressing = true;
      _pressProgress = 0;
    });
    _updateProgress();
  }

  void _updateProgress() {
    if (!_isPressing) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_isPressing) return;
      setState(() {
        _pressProgress += 0.033; // 约3秒完成
        if (_pressProgress >= 1) {
          _triggerSos();
        } else {
          _updateProgress();
        }
      });
    });
  }

  void _endPress() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPressing = false;
      _pressProgress = 0;
    });
  }

  void _triggerSos() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isTriggered = true;
    });
    // TODO: 调用 API 触发 SOS
  }
}
