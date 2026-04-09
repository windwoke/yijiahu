/**
 * 添加/编辑照护对象页
 * - 无 id 参数：添加模式
 * - 有 id 参数：编辑模式（加载数据后用 PATCH 提交）
 */

import { useState, useEffect } from 'react';
import { View, Text, Input, ScrollView, Picker, Image } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { get, post, patch } from '../../services/api';
import { uploadFile } from '../../services/api';
import { getImageUrl } from '../../shared/utils/image';
import { Storage } from '../../services/storage';
import type { CareRecipient } from '../../shared/models/care-recipient';
import './add.scss';

const AVATAR_OPTIONS = ['👴', '👵', '👨', '👩', '🧓', '🧑', '👤'];
const BLOOD_TYPES = ['A', 'B', 'AB', 'O'];
const GENDERS = [
  { label: '男', value: 'male' },
  { label: '女', value: 'female' },
];

export default function AddCareRecipientPage() {
  const params = (Taro.getCurrentInstance().router?.params as any) || {};
  const editId = params.id as string | undefined;
  const isEdit = !!editId;
  const familyId = Storage.getCurrentFamilyId();

  const [name, setName] = useState('');
  const [loading, setLoading] = useState(isEdit);
  const [selectedAvatar, setSelectedAvatar] = useState('👴');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [isUploading, setIsUploading] = useState(false);
  const [gender, setGender] = useState('male');
  const [birthDate, setBirthDate] = useState('');
  const [phone, setPhone] = useState('');
  const [bloodType, setBloodType] = useState('');
  const [emergencyContact, setEmergencyContact] = useState('');
  const [emergencyPhone, setEmergencyPhone] = useState('');
  const [hospital, setHospital] = useState('');
  const [department, setDepartment] = useState('');
  const [doctorName, setDoctorName] = useState('');
  const [doctorPhone, setDoctorPhone] = useState('');
  const [medicalHistory, setMedicalHistory] = useState('');
  const [allergies, setAllergies] = useState<string[]>([]);
  const [chronicConditions, setChronicConditions] = useState<string[]>([]);
  const [allergyInput, setAllergyInput] = useState('');
  const [chronicInput, setChronicInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  // 编辑模式：加载已有数据
  useEffect(() => {
    if (!editId || !familyId) return;
    get<CareRecipient>(`/care-recipients/${editId}`, { familyId })
      .then((r) => {
        setName(r.name || '');
        setSelectedAvatar(r.avatarEmoji || '👴');
        setAvatarUrl(r.avatarUrl || '');
        setGender(r.gender || 'male');
        setBirthDate(r.birthDate ? String(r.birthDate).slice(0, 10) : '');
        setPhone(r.phone || '');
        setBloodType(r.bloodType || '');
        setEmergencyContact(r.emergencyContact || '');
        setEmergencyPhone(r.emergencyPhone || '');
        setHospital(r.hospital || '');
        setDepartment(r.department || '');
        setDoctorName(r.doctorName || '');
        setDoctorPhone(r.doctorPhone || '');
        setMedicalHistory(r.medicalHistory || '');
        setAllergies(Array.isArray(r.allergies) ? r.allergies : []);
        setChronicConditions(Array.isArray(r.chronicConditions) ? r.chronicConditions : []);
      })
      .catch((e) => {
        console.error('加载照护对象失败', e);
        Taro.showToast({ title: '加载失败', icon: 'none' });
      })
      .finally(() => setLoading(false));
  }, [editId, familyId]);

  const handleSubmit = async () => {
    if (!name.trim()) {
      Taro.showToast({ title: '请输入姓名', icon: 'none' });
      return;
    }
    setIsLoading(true);
    try {
      const payload: Record<string, any> = {
        name: name.trim(),
        avatarEmoji: selectedAvatar || null,
        avatarUrl: avatarUrl || null,
        gender: gender || null,
        birthDate: birthDate || null,
        phone: phone || null,
        bloodType: bloodType || null,
        emergencyContact: emergencyContact || null,
        emergencyPhone: emergencyPhone || null,
        hospital: hospital || null,
        department: department || null,
        doctorName: doctorName || null,
        doctorPhone: doctorPhone || null,
        medicalHistory: medicalHistory || null,
        allergies: allergies.length > 0 ? allergies : null,
        chronicConditions: chronicConditions.length > 0 ? chronicConditions : null,
      };

      if (isEdit) {
        await patch(`/care-recipients/${editId}`, payload, { params: { familyId } });
        Taro.showToast({ title: '保存成功', icon: 'success', duration: 1500 });
        setTimeout(() => {
          Taro.redirectTo({ url: `/pages/care-recipient/detail?id=${editId}` });
        }, 1600);
      } else {
        const created = await post<CareRecipient>('/care-recipients', payload, { params: { familyId } });
        Taro.showToast({ title: '添加成功', icon: 'success', duration: 1500 });
        setTimeout(() => {
          Taro.redirectTo({ url: `/pages/care-recipient/detail?id=${created.id}` });
        }, 1600);
      }
    } catch (e: any) {
      Taro.showToast({ title: e?.message || (isEdit ? '保存失败' : '添加失败'), icon: 'none' });
    } finally {
      setIsLoading(false);
    }
  };

  /** 上传头像（仅编辑模式） */
  const handleUploadAvatar = async () => {
    if (!isEdit) {
      Taro.showToast({ title: '创建后可上传真实头像', icon: 'none' });
      return;
    }
    try {
      const res = await Taro.chooseMedia({
        count: 1,
        mediaType: ['image'],
        sourceType: ['album', 'camera'],
        maxWidth: 512,
        maxHeight: 512,
      });
      if (!res.tempFiles?.length) return;
      setIsUploading(true);
      const tempFilePath = res.tempFiles[0].tempFilePath;
      const uploadRes = await uploadFile(
        `/upload/recipient-avatar?familyId=${familyId}&recipientId=${editId}`,
        tempFilePath,
        'file',
      );
      const url = uploadRes?.avatarUrl || '';
      if (url) {
        setAvatarUrl(url);
        setSelectedAvatar(''); // 有真实照片时清空 emoji
        Taro.showToast({ title: '头像上传成功', icon: 'success' });
      }
    } catch (e) {
      console.error('上传头像失败', e);
      Taro.showToast({ title: '上传失败', icon: 'none' });
    } finally {
      setIsUploading(false);
    }
  };

  // 加载中
  if (loading) {
    return (
      <View className="acr-page loading-state">
        <Text className="loading-text">加载中...</Text>
      </View>
    );
  }

  return (
    <View className="acr-page">
      {/* 导航栏 */}
      <View className="add-navbar">
        <Text className="add-navbar-back" onClick={() => Taro.navigateBack()}>‹</Text>
        <Text className="add-navbar-title">{isEdit ? '编辑照护对象' : '添加照护对象'}</Text>
      </View>

      <ScrollView className="acr-scroll" scrollY>
        {/* 头像选择 */}
        <View className="section">
          <Text className="section-title">头像</Text>
          {/* 已上传的头像 */}
          {avatarUrl ? (
            <View className="avatar-uploaded">
              <Image className="avatar-uploaded-img" src={getImageUrl(avatarUrl)} mode="aspectFill" />
              {isEdit && (
                <View className="avatar-upload-btn" onClick={handleUploadAvatar}>
                  <Text className="avatar-upload-btn-text">更换头像</Text>
                </View>
              )}
            </View>
          ) : (
            <View className="avatar-row">
              {/* Emoji 选择 */}
              <View className="avatar-grid">
                {AVATAR_OPTIONS.map((emoji) => (
                  <View
                    key={emoji}
                    className={`avatar-chip ${selectedAvatar === emoji ? 'selected' : ''}`}
                    onClick={() => setSelectedAvatar(emoji)}
                  >
                    <Text className="avatar-chip-text">{emoji}</Text>
                  </View>
                ))}
              </View>
              {/* 上传按钮（仅编辑模式） */}
              {isEdit && (
                <View
                  className={`avatar-upload-chip ${isUploading ? 'uploading' : ''}`}
                  onClick={isUploading ? undefined : handleUploadAvatar}
                >
                  {isUploading ? (
                    <Text className="avatar-chip-text">...</Text>
                  ) : (
                    <Text className="avatar-chip-text">📷</Text>
                  )}
                </View>
              )}
            </View>
          )}
        </View>

        {/* 基本信息 */}
        <View className="section">
          <Text className="section-title">基本信息</Text>

          <View className="field">
            <Text className="field-label">姓名 *</Text>
            <Input
              className="field-input"
              placeholder="请输入姓名"
              value={name}
              onInput={(e) => setName(e.detail.value)}
            />
          </View>

          <View className="field-row">
            <View className="field">
              <Text className="field-label">性别</Text>
              <View className="gender-chips">
                {GENDERS.map((g) => (
                  <View
                    key={g.value}
                    className={`gender-chip ${gender === g.value ? 'selected' : ''}`}
                    onClick={() => setGender(g.value)}
                  >
                    <Text className={`gender-chip-text ${gender === g.value ? 'selected' : ''}`}>{g.label}</Text>
                  </View>
                ))}
              </View>
            </View>
          </View>

          <View className="field">
            <Text className="field-label">出生日期</Text>
            <Picker
              mode="date"
              value={birthDate}
              onChange={(e) => setBirthDate(e.detail.value)}
            >
              <View className="field-picker">
                <Text className={birthDate ? 'field-picker-text' : 'field-picker-placeholder'}>
                  {birthDate || '选择出生日期'}
                </Text>
                <Text className="field-picker-arrow">›</Text>
              </View>
            </Picker>
          </View>

          <View className="field">
            <Text className="field-label">联系电话</Text>
            <Input
              className="field-input"
              placeholder="选填"
              type="phone"
              value={phone}
              onInput={(e) => setPhone(e.detail.value)}
            />
          </View>

          <View className="field">
            <Text className="field-label">血型</Text>
            <View className="blood-chips">
              {BLOOD_TYPES.map((bt) => (
                <View
                  key={bt}
                  className={`blood-chip ${bloodType === bt ? 'selected' : ''}`}
                  onClick={() => setBloodType(bloodType === bt ? '' : bt)}
                >
                  <Text className={`blood-chip-text ${bloodType === bt ? 'selected' : ''}`}>{bt}型</Text>
                </View>
              ))}
            </View>
          </View>
        </View>

        {/* 健康信息 */}
        <View className="section">
          <Text className="section-title">健康信息</Text>

          <View className="field">
            <Text className="field-label">过敏史</Text>
            {/* 已有标签 */}
            {allergies.length > 0 && (
              <View className="tag-chips">
                {allergies.map((tag, i) => (
                  <View key={i} className="tag-chip tag-chip-allergy">
                    <Text className="tag-chip-text">{tag}</Text>
                    <Text className="tag-chip-remove" onClick={() => setAllergies(allergies.filter((_, idx) => idx !== i))}>×</Text>
                  </View>
                ))}
              </View>
            )}
            {/* 输入框 */}
            <Input
              className="field-input tag-input"
              placeholder="输入后按回车添加"
              value={allergyInput}
              onInput={(e) => setAllergyInput(e.detail.value)}
              onConfirm={(e) => {
                const v = e.detail.value.trim();
                if (v && !allergies.includes(v)) setAllergies([...allergies, v]);
                setAllergyInput('');
              }}
            />
          </View>

          <View className="field">
            <Text className="field-label">既往病史</Text>
            <Input
              className="field-input"
              placeholder="选填"
              value={medicalHistory}
              onInput={(e) => setMedicalHistory(e.detail.value)}
            />
          </View>

          <View className="field">
            <Text className="field-label">慢性病</Text>
            {/* 已有标签 */}
            {chronicConditions.length > 0 && (
              <View className="tag-chips">
                {chronicConditions.map((tag, i) => (
                  <View key={i} className="tag-chip tag-chip-chronic">
                    <Text className="tag-chip-text">{tag}</Text>
                    <Text className="tag-chip-remove" onClick={() => setChronicConditions(chronicConditions.filter((_, idx) => idx !== i))}>×</Text>
                  </View>
                ))}
              </View>
            )}
            {/* 输入框 */}
            <Input
              className="field-input tag-input"
              placeholder="输入后按回车添加"
              value={chronicInput}
              onInput={(e) => setChronicInput(e.detail.value)}
              onConfirm={(e) => {
                const v = e.detail.value.trim();
                if (v && !chronicConditions.includes(v)) setChronicConditions([...chronicConditions, v]);
                setChronicInput('');
              }}
            />
          </View>
        </View>

        {/* 紧急联系人 */}
        <View className="section">
          <Text className="section-title">紧急联系人</Text>

          <View className="field">
            <Text className="field-label">联系人姓名</Text>
            <Input
              className="field-input"
              placeholder="选填"
              value={emergencyContact}
              onInput={(e) => setEmergencyContact(e.detail.value)}
            />
          </View>

          <View className="field">
            <Text className="field-label">联系人电话</Text>
            <Input
              className="field-input"
              placeholder="选填"
              type="phone"
              value={emergencyPhone}
              onInput={(e) => setEmergencyPhone(e.detail.value)}
            />
          </View>
        </View>

        {/* 就医信息 */}
        <View className="section">
          <Text className="section-title">就医信息</Text>

          <View className="field">
            <Text className="field-label">主治医院</Text>
            <Input
              className="field-input"
              placeholder="选填"
              value={hospital}
              onInput={(e) => setHospital(e.detail.value)}
            />
          </View>

          <View className="field">
            <Text className="field-label">科室</Text>
            <Input
              className="field-input"
              placeholder="选填"
              value={department}
              onInput={(e) => setDepartment(e.detail.value)}
            />
          </View>

          <View className="field">
            <Text className="field-label">主治医生</Text>
            <Input
              className="field-input"
              placeholder="选填"
              value={doctorName}
              onInput={(e) => setDoctorName(e.detail.value)}
            />
          </View>

          <View className="field">
            <Text className="field-label">医生电话</Text>
            <Input
              className="field-input"
              placeholder="选填"
              type="phone"
              value={doctorPhone}
              onInput={(e) => setDoctorPhone(e.detail.value)}
            />
          </View>
        </View>

        <View className="bottom-pad" />
      </ScrollView>

      {/* 底部提交按钮 */}
      <View className="acr-submit-bar">
        <View
          className={`acr-submit-btn ${isLoading ? 'loading' : ''}`}
          onClick={isLoading ? undefined : handleSubmit}
        >
          <Text className="acr-submit-text">
            {isLoading ? '保存中...' : isEdit ? '保存修改' : '保存'}
          </Text>
        </View>
      </View>
    </View>
  );
}
