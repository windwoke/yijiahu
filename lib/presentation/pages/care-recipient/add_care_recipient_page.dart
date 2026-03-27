/// 添加/编辑照护对象页
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart' show AppRoutes;
import '../../../core/env/env_config.dart' show ApiConfig;
import '../../../data/models/models.dart' as models;
import '../../providers/family_provider.dart';

class AddCareRecipientPage extends ConsumerStatefulWidget {
  final models.CareRecipient? recipient;

  const AddCareRecipientPage({super.key, this.recipient});

  @override
  ConsumerState<AddCareRecipientPage> createState() => _AddCareRecipientPageState();
}

class _AddCareRecipientPageState extends ConsumerState<AddCareRecipientPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _departmentController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _doctorPhoneController = TextEditingController();
  final _medicalHistoryController = TextEditingController();

  String _gender = '';
  DateTime? _birthDate;
  String? _bloodType;
  bool _isLoading = false;

  final List<String> _avatarOptions = ['👴', '👵', '👨', '👩', '🧓', '🧑', '👤'];
  String _selectedAvatar = '👴';
  String? _avatarUrl; // 上传后的真实头像URL
  bool _isUploadingAvatar = false;

  bool get isEditing => widget.recipient != null;

  @override
  void initState() {
    super.initState();
    if (widget.recipient != null) {
      final r = widget.recipient!;
      _nameController.text = r.name;
      _phoneController.text = r.phone ?? '';
      _selectedAvatar = r.avatarEmoji ?? '👴';
      _avatarUrl = r.avatarUrl;
      _gender = r.gender ?? '';
      _birthDate = r.birthDate;
      _bloodType = r.bloodType;
      _emergencyContactController.text = r.emergencyContact ?? '';
      _emergencyPhoneController.text = r.emergencyPhone ?? '';
      _hospitalController.text = r.hospital ?? '';
      _departmentController.text = r.department ?? '';
      _doctorNameController.text = r.doctorName ?? '';
      _doctorPhoneController.text = r.doctorPhone ?? '';
      _medicalHistoryController.text = r.medicalHistory ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _hospitalController.dispose();
    _departmentController.dispose();
    _doctorNameController.dispose();
    _doctorPhoneController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path),
      });
      final resp = await dio.post('/upload/avatar', data: formData);
      final url = resp.data['avatarUrl'] as String?;
      if (url != null) {
        setState(() {
          _avatarUrl = url;
          _selectedAvatar = ''; // 有真实照片时清空 emoji 选择
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像上传失败'), duration: Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _selectBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1970),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _birthDate = date);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'avatarEmoji': _selectedAvatar,
        if (_avatarUrl != null) 'avatarUrl': _avatarUrl,
        if (_phoneController.text.isNotEmpty) 'phone': _phoneController.text.trim(),
        'gender': _gender,
        if (_birthDate != null)
          'birthDate':
              '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
        if (_bloodType != null) 'bloodType': _bloodType,
        'emergencyContact': _emergencyContactController.text.trim(),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        if (_hospitalController.text.isNotEmpty)
          'hospital': _hospitalController.text.trim(),
        if (_departmentController.text.isNotEmpty)
          'department': _departmentController.text.trim(),
        if (_doctorNameController.text.isNotEmpty)
          'doctorName': _doctorNameController.text.trim(),
        if (_doctorPhoneController.text.isNotEmpty)
          'doctorPhone': _doctorPhoneController.text.trim(),
        if (_medicalHistoryController.text.isNotEmpty)
          'medicalHistory': _medicalHistoryController.text.trim(),
      };

      if (isEditing) {
        final familyId = ref.read(currentFamilyProvider)?.id ?? '';
        await dio.patch(
          '/care-recipients/${widget.recipient!.id}',
          queryParameters: {'familyId': familyId},
          data: data,
        );
      } else {
        // 新增
        var family = ref.read(currentFamilyProvider);
        if (family == null) {
          final familyResponse = await dio.post('/families', data: {'name': '我的家庭'});
          family = models.Family.fromJson(familyResponse.data as Map<String, dynamic>);
          ref.read(currentFamilyProvider.notifier).state = family;
        }
        final fid = family.id;
        final resp = await dio.post(
          '/care-recipients',
          queryParameters: {'familyId': fid},
          data: data,
        );
        final newRecipient = models.CareRecipient.fromJson(
            resp.data as Map<String, dynamic>);

        ref.invalidate(careRecipientsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加成功'), duration: const Duration(seconds: 3)),
          );
          // 跳转到详情页
          context.pushReplacement(
            AppRoutes.careRecipientDetail,
            extra: newRecipient,
          );
        }
        return;
      }

      ref.invalidate(careRecipientsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? '修改成功' : '添加成功'), duration: const Duration(seconds: 3)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String displayMsg = '操作失败，请稍后重试';
        bool shouldUpgrade = false;

        if (e is DioException && e.response != null) {
          final data = e.response!.data;
          if (data is Map<String, dynamic>) {
            displayMsg = data['message']?.toString() ?? displayMsg;
          }
        }

        if (displayMsg.contains('请升级会员') || displayMsg.contains('最多添加')) {
          shouldUpgrade = true;
        }

        if (shouldUpgrade) {
          final pageContext = context;
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.local_offer_outlined, color: AppColors.coral, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayMsg,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx); // 关闭弹层
                        // 等动画结束后：关闭添加页 + 跳转个人中心
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          pageContext.pop();
                          GoRouter.of(pageContext).go(AppRoutes.profile);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral, foregroundColor: Colors.white,
                        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('立即升级'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消', style: TextStyle(color: AppColors.grey500)),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(displayMsg), duration: const Duration(seconds: 10)),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? '编辑照护对象' : '添加照护对象'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 头像选择
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _uploadAvatar,
                        child: Stack(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: _isUploadingAvatar
                                    ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                                    : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                        ? Image.network(
                                            _avatarUrl!.startsWith('http') ? _avatarUrl! : '${ApiConfig.staticRoot}/$_avatarUrl',
                                            fit: BoxFit.cover,
                                            width: 72,
                                            height: 72,
                                            errorBuilder: (_, __, ___) => Text(_selectedAvatar, style: const TextStyle(fontSize: 40)),
                                          )
                                        : Center(
                                            child: Text(_selectedAvatar, style: const TextStyle(fontSize: 40)),
                                          ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: _avatarOptions.map((emoji) {
                          final isSelected = emoji == _selectedAvatar;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedAvatar = emoji),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(color: AppColors.primary, width: 2)
                                    : Border.all(color: AppColors.border),
                              ),
                              child: Center(
                                child: Text(emoji, style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 基本信息卡片
                _buildSectionCard([
                  _buildTextField(
                    controller: _nameController,
                    label: '姓名 *',
                    hint: '如：爷爷、奶奶',
                    icon: Icons.person_outline,
                    validator: (v) => v == null || v.isEmpty ? '请输入姓名' : null,
                  ),
                  _buildDivider(),
                  _buildTextField(
                    controller: _phoneController,
                    label: '手机号码',
                    hint: '照护对象本人的手机号',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  _buildDivider(),
                  _buildGenderSelector(),
                  _buildDivider(),
                  _buildDateField(),
                ]),
                const SizedBox(height: 16),

                // 健康信息卡片
                _buildSectionCard([
                  _buildBloodTypeSelector(),
                ]),
                const SizedBox(height: 16),

                // 就医信息卡片
                _buildSectionCard([
                  _buildTextField(
                    controller: _hospitalController,
                    label: '就诊医院',
                    hint: '如：市立医院',
                    icon: Icons.local_hospital_rounded,
                  ),
                  _buildDivider(),
                  _buildTextField(
                    controller: _departmentController,
                    label: '科室',
                    hint: '如：心内科',
                    icon: Icons.medical_services_rounded,
                  ),
                  _buildDivider(),
                  _buildTextField(
                    controller: _doctorNameController,
                    label: '主治医生',
                    hint: '如：王建国',
                    icon: Icons.person_pin_rounded,
                  ),
                  _buildDivider(),
                  _buildTextField(
                    controller: _doctorPhoneController,
                    label: '医生电话',
                    hint: '手机号',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                ]),
                const SizedBox(height: 16),

                // 病史卡片
                _buildSectionCard([
                  _buildTextField(
                    controller: _medicalHistoryController,
                    label: '病史备注',
                    hint: '过往病史、手术史等',
                    icon: Icons.history_rounded,
                    maxLines: 3,
                  ),
                ]),
                const SizedBox(height: 16),

                // 紧急联系人卡片
                _buildSectionCard([
                  _buildTextField(
                    controller: _emergencyContactController,
                    label: '紧急联系人',
                    hint: '如：儿子张三',
                    icon: Icons.contacts_rounded,
                  ),
                  _buildDivider(),
                  _buildTextField(
                    controller: _emergencyPhoneController,
                    label: '紧急联系电话',
                    hint: '手机号',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                ]),
                const SizedBox(height: 32),

                FilledButton(
                  onPressed: _isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEditing ? '保存修改' : '保存', style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 0.5),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          labelStyle: const TextStyle(color: AppColors.primary, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('性别', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(width: 24),
          _genderChip('男', 'male'),
          const SizedBox(width: 12),
          _genderChip('女', 'female'),
        ],
      ),
    );
  }

  Widget _genderChip(String label, String value) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectBirthDate,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.cake_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '出生日期',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _birthDate != null
                        ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
                        : '选填',
                    style: TextStyle(
                      fontSize: 15,
                      color: _birthDate != null ? AppColors.textPrimary : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodTypeSelector() {
    final bloodTypes = ['A', 'B', 'AB', 'O'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('血型', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              ...bloodTypes.map((type) {
                final isSelected = _bloodType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _bloodType = isSelected ? null : type),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
