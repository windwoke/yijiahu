/**
 * 通知设置页
 * - 微信小程序订阅通知开关（顶部醒目区）
 * - 通知类型开关列表
 */
import { View, Text, Switch, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { useState, useEffect, useCallback } from 'react';
import { get, put } from '../../services/api';
import { store } from '../../store';
import './index.scss';

interface NotificationPref {
  medicationReminder: boolean;
  missedDose: boolean;
  appointmentReminder: boolean;
  taskReminder: boolean;
  taskAssigned: boolean;
  dailyCheckin: boolean;
  dailyCheckinCompleted: boolean;
  healthAlert: boolean;
  sosEnabled: boolean;
  memberJoined: boolean;
  careLog: boolean;
  dndEnabled: boolean;
  soundEnabled: boolean;
  vibrationEnabled: boolean;
  wechatEnabled: boolean;
}

interface PrefItem {
  key: keyof NotificationPref;
  label: string;
  desc?: string;
  group?: string;
}

const PREF_LIST: PrefItem[] = [
  // 核心提醒
  { key: 'medicationReminder', label: '用药提醒', desc: '药品临近服用时间时通知', group: '核心提醒' },
  { key: 'missedDose', label: '漏服提醒', desc: '超过30分钟未服药时通知', group: '核心提醒' },
  { key: 'appointmentReminder', label: '复诊提醒', desc: '复诊前24小时通知', group: '核心提醒' },
  { key: 'dailyCheckin', label: '护理打卡提醒', desc: '每日09:00提醒提交护理打卡', group: '核心提醒' },
  { key: 'dailyCheckinCompleted', label: '打卡完成通知', desc: '照护对象打卡完成时通知家人', group: '核心提醒' },
  // 任务
  { key: 'taskReminder', label: '任务到期提醒', desc: '任务临近到期时通知', group: '家庭任务' },
  { key: 'taskAssigned', label: '任务指派通知', desc: '被分配任务时通知', group: '家庭任务' },
  // 其他
  { key: 'healthAlert', label: '健康预警', desc: '血压/血糖异常时通知', group: '其他' },
  { key: 'sosEnabled', label: 'SOS 紧急求助', desc: '家人触发SOS时通知', group: '其他' },
  { key: 'memberJoined', label: '新成员加入', desc: '家庭有新成员时通知', group: '其他' },
  { key: 'careLog', label: '护理日志', desc: '新增护理日志时通知', group: '其他' },
  // 偏好
  { key: 'soundEnabled', label: '声音', desc: '通知时播放声音', group: '偏好' },
  { key: 'vibrationEnabled', label: '震动', desc: '通知时震动', group: '偏好' },
];

export default function NotificationPage() {
  const [prefs, setPrefs] = useState<NotificationPref | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [userPhone, setUserPhone] = useState<string | null>(null);

  useEffect(() => {
    const authUser = store.getState().auth.user;
    setUserPhone(authUser?.phone || null);
  }, []);

  const loadPrefs = useCallback(async () => {
    try {
      const data = await get<NotificationPref>('/notification-preferences');
      setPrefs(data as NotificationPref);
    } catch (err) {
      console.error('[notification] 加载偏好失败:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadPrefs();
  }, [loadPrefs]);

  // 保存单个偏好
  const savePref = useCallback(async (key: keyof NotificationPref, value: boolean) => {
    if (!prefs) return;

    // 先乐观更新 UI
    setPrefs((prev) => prev ? { ...prev, [key]: value } : prev);

    // 如果是开启微信订阅，先调微信授权
    if (key === 'wechatEnabled' && value) {
      if (!userPhone) {
        Taro.showModal({
          title: '请先绑定手机号',
          content: '微信订阅通知需要先绑定手机号',
          confirmText: '去绑定',
          success: (res) => {
            if (res.confirm) {
              Taro.navigateTo({ url: '/pages/auth/bind-phone/index' });
            }
          },
        });
        // 回滚
        setPrefs((prev) => prev ? { ...prev, [key]: false } : prev);
        return;
      }

      // 调起微信订阅授权弹窗
      const tmplIds = [
        'WECHAT_TMPL_MEDICATION', // 用户需替换为真实模板ID
        'WECHAT_TMPL_APPOINTMENT',
        'WECHAT_TMPL_SOS',
      ];

      try {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const result = await (Taro as any).requestSubscribeMessage({ tmplIds });
        const acceptAny = Object.values(result || {}).some((v) => v === 'accept');
        if (!acceptAny) {
          Taro.showToast({ title: '您拒绝了订阅授权', icon: 'none', duration: 2000 });
          setPrefs((prev) => prev ? { ...prev, [key]: false } : prev);
          return;
        }
      } catch (err) {
        console.warn('[notification] 订阅授权失败:', err);
        // 微信拒绝也算成功——用户已收到授权弹窗
      }
    }

    setSaving(true);
    try {
      await put('/notification-preferences', { [key]: value });
    } catch (err: any) {
      console.error('[notification] 保存偏好失败:', err);
      // 回滚
      setPrefs((prev) => prev ? { ...prev, [key]: !value } : prev);
      Taro.showToast({ title: err?.message || '保存失败', icon: 'none' });
    } finally {
      setSaving(false);
    }
  }, [prefs, userPhone]);

  if (loading) {
    return (
      <View className="notif-page">
        <View className="loading-state">
          <Text className="loading-text">加载中...</Text>
        </View>
      </View>
    );
  }

  // 按 group 分组
  const groups = PREF_LIST.reduce<Record<string, PrefItem[]>>((acc, item) => {
    const g = item.group || '其他';
    if (!acc[g]) acc[g] = [];
    acc[g].push(item);
    return acc;
  }, {});

  const wechatEnabled = prefs?.wechatEnabled ?? false;

  return (
    <View className="notif-page">
      <ScrollView className="notif-scroll" scrollY>
        {/* ── 微信订阅通知区（顶部醒目）────────────────────── */}
        <View className="wechat-section">
          <View className="wechat-header">
            <View className="wechat-icon-wrap">
              <Text className="wechat-icon">&#xe90b;</Text>
            </View>
            <View className="wechat-info">
              <Text className="wechat-title">微信订阅通知</Text>
              <Text className="wechat-desc">
                {wechatEnabled ? '已开启，将通过微信服务号推送重要提醒' : '开启后可在微信中接收重要通知提醒'}
              </Text>
            </View>
            <Switch
              className="wechat-switch"
              checked={wechatEnabled}
              color="#7B9E87"
              onChange={() => savePref('wechatEnabled', !wechatEnabled)}
            />
          </View>

          {!wechatEnabled && (
            <View className="wechat-tip">
              <Text className="wechat-tip-text">
                开启后，系统将通过微信服务号发送用药提醒、复诊提醒等到您的微信
              </Text>
            </View>
          )}

          {wechatEnabled && !userPhone && (
            <View className="wechat-warn">
              <Text className="wechat-warn-text">
                请先绑定手机号以接收订阅通知
              </Text>
              <Text
                className="wechat-warn-link"
                onClick={() => Taro.navigateTo({ url: '/pages/auth/bind-phone/index' })}
              >
                去绑定 ›
              </Text>
            </View>
          )}
        </View>

        {/* ── 通知类型开关 ─────────────────────────────────── */}
        {Object.entries(groups).map(([groupName, items]) => (
          <View key={groupName}>
            <Text className="section-title">{groupName}</Text>
            <View className="section-card">
              {items.map((item, idx) => {
                const val = prefs?.[item.key] ?? true;
                return (
                  <View key={item.key}>
                    {idx > 0 && <View className="setting-divider" />}
                    <View className="setting-item">
                      <View className="setting-text-wrap">
                        <Text className="setting-label">{item.label}</Text>
                        {item.desc && (
                          <Text className="setting-desc">{item.desc}</Text>
                        )}
                      </View>
                      <Switch
                        className="setting-switch"
                        checked={val}
                        color="#7B9E87"
                        onChange={() => savePref(item.key, !val)}
                      />
                    </View>
                  </View>
                );
              })}
            </View>
          </View>
        ))}

        {/* ── 底部说明 ─────────────────────────────────────── */}
        <View className="footer-note">
          <Text className="footer-note-text">
            通知开关仅影响应用内推送，微信订阅通知由微信服务号独立发送
          </Text>
        </View>

        <View className="bottom-pad" />
      </ScrollView>
    </View>
  );
}
