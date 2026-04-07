/**
 * 照护日志页
 * 温暖日记风时间线 — 与 Flutter 设计对齐
 */

import { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView, Image } from '@tarojs/components';
import Taro, { useDidShow } from '@tarojs/taro';
import { get, post, put, del, uploadFile } from '../../services/api';
import { Storage } from '../../services/storage';
import { getImageUrl } from '../../shared/utils/image';
import './index.scss';

/* ============================
   类型定义
   ============================ */

const CARE_LOG_TYPES = [
  { key: null, label: '全部', emoji: '📋', color: '#7B9E87' },
  { key: 'medication', label: '服药', emoji: '💊', color: '#4A90D9' },
  { key: 'health', label: '健康', emoji: '♥', color: '#7B9E87' },
  { key: 'emotion', label: '情绪', emoji: '☺', color: '#D4A855' },
  { key: 'activity', label: '活动', emoji: '🚶', color: '#6BA07E' },
  { key: 'meal', label: '饮食', emoji: '🍽', color: '#C88C50' },
  { key: 'other', label: '其他', emoji: '📝', color: '#6B6B6B' },
];

interface CareRecipient {
  id: string;
  name: string;
  displayAvatar: string;
}

interface Attachment {
  url: string;
  type: 'image' | 'video';
}

/** 待上传的附件（选图后立即开始后台上传） */
interface PendingAttachment {
  id: string;
  localPath: string;
  uploading: boolean;
  uploadedUrl?: string;
  uploadedId?: string;
  failed?: boolean;
}

interface CareLog {
  id: string;
  content: string;
  type: string;
  createdAt: string;
  authorName: string;
  authorAvatar?: string;
  recipientId?: string;
  recipientName?: string;
  attachments: Attachment[];
}

interface TimelineResponse {
  list: CareLog[];
  total: number;
}

/** 按日期分组 */
interface DayGroup {
  dateLabel: string;
  dateISO: string;
  logs: CareLog[];
}

/* ============================
   工具函数
   ============================ */

function getDateLabel(isoStr: string): string {
  const d = new Date(isoStr.replace(/-/g, '/'));
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(d);
  target.setHours(0, 0, 0, 0);
  const diff = Math.round((today.getTime() - target.getTime()) / 86400000);

  if (diff === 0) return '今天';
  if (diff === 1) return '昨天';

  const month = d.getMonth() + 1;
  const day = d.getDate();
  const weekday = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][d.getDay()];
  return `${month}月${day}日 ${weekday}`;
}

function groupByDate(logs: CareLog[]): DayGroup[] {
  const map = new Map<string, CareLog[]>();
  for (const log of logs) {
    const d = new Date(log.createdAt.replace(/-/g, '/'));
    const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    if (!map.has(iso)) map.set(iso, []);
    map.get(iso)!.push(log);
  }
  return Array.from(map.entries())
    .sort(([a], [b]) => b.localeCompare(a))
    .map(([iso, logs]) => ({
      dateLabel: getDateLabel(iso),
      dateISO: iso,
      logs,
    }));
}

function getTypeDef(type: string | null) {
  return CARE_LOG_TYPES.find((t) => t.key === type) ?? CARE_LOG_TYPES[0];
}

function formatTime(isoStr: string): string {
  const d = new Date(isoStr.replace(/-/g, '/'));
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function getAttachmentUrl(url: string): string {
  return getImageUrl(url);
}

function getDefaultAvatarUrl(): string {
  // 返回默认头像的路径（与后端一致）
  return '';
}

/* ============================
   主组件
   ============================ */

export default function CareLogPage() {
  const [filterType, setFilterType] = useState<string | null>(null);
  const [selectedRecipientId, setSelectedRecipientId] = useState<string | null>(null);
  const [recipients, setRecipients] = useState<CareRecipient[]>([]);
  const [dayGroups, setDayGroups] = useState<DayGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [hasMore, setHasMore] = useState(false);
  const [page, setPage] = useState(1);
  const [showAddSheet, setShowAddSheet] = useState(false);
  const [addContent, setAddContent] = useState('');
  const [addType, setAddType] = useState<string>('other');
  const [addRecipientId, setAddRecipientId] = useState<string>('');
  const [submitting, setSubmitting] = useState(false);
  const [pendingAttachments, setPendingAttachments] = useState<PendingAttachment[]>([]);

  const uploadAttachment = async (id: string, localPath: string) => {
    if (!familyId) return;
    try {
      const res = await uploadFile(`/upload/attachments?familyId=${familyId}`, localPath, 'files');
      console.log('[care-log] upload res:', JSON.stringify(res));
      // 后端返回 { attachments: [{ id, url, filename, ... }] }
      const attachments = res?.attachments || res?.data?.attachments || [];
      const first = attachments[0] || {};
      const uploadedId = first.id || '';
      const uploadedUrl = first.url || '';
      console.log('[care-log] upload parsed:', { uploadedId, uploadedUrl });
      setPendingAttachments((prev) =>
        prev.map((a) => a.id === id ? { ...a, uploading: false, uploadedUrl, uploadedId } : a)
      );
    } catch (err: any) {
      console.error('[care-log] upload failed:', err?.message);
      setPendingAttachments((prev) =>
        prev.map((a) => a.id === id ? { ...a, uploading: false, failed: true } : a)
      );
    }
  };

  const handleChooseImages = () => {
    Taro.chooseImage({ count: 9, sizeType: ['compressed'], sourceType: ['album', 'camera'] })
      .then((res) => {
        const newOnes: PendingAttachment[] = res.tempFilePaths.map((path: string) => ({
          id: `local-${Date.now()}-${Math.random()}`,
          localPath: path,
          uploading: true,
        }));
        setPendingAttachments((prev) => [...prev, ...newOnes]);
        newOnes.forEach((a) => uploadAttachment(a.id, a.localPath));
      });
  };

  const removeAttachment = (id: string) => {
    setPendingAttachments((prev) => prev.filter((a) => a.id !== id));
  };

  const hasUploading = pendingAttachments.some((a) => a.uploading);

  const uploadedAttachments = pendingAttachments
    .filter((a) => !a.uploading && a.uploadedId && !a.failed)
    .map((a) => a.uploadedId!);

  const familyId = Storage.getCurrentFamilyId();

  const loadRecipients = useCallback(async () => {
    if (!familyId) return;
    try {
      const data = await get<CareRecipient[]>(`/care-recipients?familyId=${familyId}`);
      setRecipients(data ?? []);
      if (data && data.length > 0 && !addRecipientId) {
        setAddRecipientId(data[0].id);
      }
    } catch (err) {
      console.error('加载照护对象失败', err);
    }
  }, [familyId, addRecipientId]);

  const loadTimeline = useCallback(async (reset = false) => {
    const currentPage = reset ? 1 : page;
    if (reset) setLoading(true);
    try {
      const params: Record<string, string | number> = {
        familyId,
        page: currentPage,
        limit: 20,
      };
      if (filterType) params['type'] = filterType;
      if (selectedRecipientId) params['recipientId'] = selectedRecipientId;

      const data = await get<any[]>('/care-logs', params);
      const logs = data ?? [];

      if (reset) {
        setDayGroups(groupByDate(logs));
        setPage(1);
      } else {
        setDayGroups((prev) => {
          const existing = new Map(prev.map((g) => [g.dateISO, g]));
          for (const g of groupByDate(logs)) {
            if (existing.has(g.dateISO)) {
              existing.get(g.dateISO)!.logs.push(...g.logs);
            } else {
              existing.set(g.dateISO, g);
            }
          }
          return Array.from(existing.values()).sort((a, b) => b.dateISO.localeCompare(a.dateISO));
        });
      }
      setHasMore(logs.length === 20);
    } catch (err) {
      console.error('加载时间线失败', err);
    } finally {
      setLoading(false);
    }
  }, [familyId, filterType, selectedRecipientId, page]);

  useEffect(() => {
    loadRecipients();
  }, [loadRecipients]);

  useEffect(() => {
    if (!familyId) {
      setDayGroups([]);
      setLoading(false);
      return;
    }
    loadTimeline(true);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [familyId, filterType, selectedRecipientId]);

  useDidShow(() => {
    if (familyId) {
      loadTimeline(true);
      loadRecipients();
    }
  });

  const onScrollToLower = useCallback(() => {
    if (!hasMore || loading) return;
    setPage((p) => p + 1);
  }, [hasMore, loading]);

  useEffect(() => {
    if (page > 1) loadTimeline(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);

  const handleTypeChange = (type: string | null) => {
    setFilterType(type);
  };

  const handleRecipientChange = (id: string | null) => {
    setSelectedRecipientId(id);
  };

  const handleAddLog = async () => {
    if (!addContent.trim()) {
      Taro.showToast({ title: '请输入日志内容', icon: 'none' });
      return;
    }
    if (!familyId) {
      Taro.showToast({ title: '请先加入家庭', icon: 'none' });
      return;
    }
    if (!addRecipientId) {
      Taro.showToast({ title: '请选择照护对象', icon: 'none' });
      return;
    }

    setSubmitting(true);
    try {
      const attachmentIds = pendingAttachments
        .filter((a) => !a.uploading && a.uploadedId && !a.failed)
        .map((a) => a.uploadedId!);
      const payload: Record<string, any> = {
        recipientId: addRecipientId,
        content: addContent.trim(),
        type: addType,
      };
      if (attachmentIds.length > 0) {
        payload.attachmentIds = attachmentIds;
      }
      console.log('[care-log] submit payload:', JSON.stringify(payload));
      await post(`/care-logs?familyId=${familyId}`, payload);
      Taro.showToast({ title: '记录成功', icon: 'success' });
      setShowAddSheet(false);
      setAddContent('');
      setAddType('other');
      setPendingAttachments([]);
      loadTimeline(true);
    } catch (err) {
      console.error('提交日志失败', err);
      Taro.showToast({ title: '提交失败，请重试', icon: 'none' });
    } finally {
      setSubmitting(false);
    }
  };

  const closeSheet = () => {
    setShowAddSheet(false);
    setPendingAttachments([]);
    setAddContent('');
    setAddType('other');
  };

  const titleLabel = selectedRecipientId
    ? (recipients.find((r) => r.id === selectedRecipientId)?.name ?? '照护对象') + '的日志'
    : '照护日志';

  return (
    <View className="care-log-page">
      {/* 顶部留白（状态栏） */}
      <View className="status-bar" />

      {/* 页面标题 */}
      <View className="page-header">
        <Text className="page-title">{titleLabel}</Text>
        <View className="timeline-badge">
          <Text className="timeline-badge-text">时间线</Text>
        </View>
      </View>

      {/* 照护对象切换（横向滚动） */}
      {recipients.length > 1 && (
        <ScrollView className="recipient-switcher" scrollX>
          <View className="recipient-chips">
            <View
              className={`recipient-chip ${selectedRecipientId === null ? 'selected' : ''}`}
              onClick={() => handleRecipientChange(null)}
            >
              <Text className="chip-emoji">👨‍👩‍👧‍👦</Text>
              <Text className={`chip-name ${selectedRecipientId === null ? 'selected' : ''}`}>全部</Text>
            </View>
            {recipients.map((r) => (
              <View
                key={r.id}
                className={`recipient-chip ${selectedRecipientId === r.id ? 'selected' : ''}`}
                onClick={() => handleRecipientChange(r.id)}
              >
                <Text className="chip-emoji">{r.displayAvatar || '👤'}</Text>
                <Text className={`chip-name ${selectedRecipientId === r.id ? 'selected' : ''}`}>{r.name}</Text>
              </View>
            ))}
          </View>
        </ScrollView>
      )}

      {/* 类型筛选行 — 使用图标 + 文字 */}
      <ScrollView className="type-filter-row" scrollX>
        <View className="type-chips">
          {CARE_LOG_TYPES.map((t) => (
            <View
              key={t.key ?? 'all'}
              className={`type-chip ${filterType === t.key ? 'active' : ''}`}
              style={filterType === t.key && t.color ? { backgroundColor: t.color, borderColor: t.color } : {}}
              onClick={() => handleTypeChange(t.key)}
            >
              <Text className="type-chip-emoji">{t.emoji}</Text>
              <Text
                className={`type-chip-label ${filterType === t.key ? 'active' : ''}`}
              >
                {t.label}
              </Text>
            </View>
          ))}
        </View>
      </ScrollView>

      {/* 时间线列表 */}
      {!familyId ? (
        <View className="empty-state">
          <Image className="empty-icon-img" src={require('../../assets/icons/info.png')} mode="aspectFit" />
          <Text className="empty-title">请先加入家庭</Text>
          <Text className="empty-desc">在设置页加入或创建家庭后查看日志</Text>
        </View>
      ) : dayGroups.length === 0 && !loading ? (
        <View className="empty-state">
          <Image className="empty-icon-img" src={require('../../assets/icons/doc.png')} mode="aspectFit" />
          <Text className="empty-title">还没有日志</Text>
          <Text className="empty-desc">记下第一条吧</Text>
        </View>
      ) : (
        <ScrollView
          className="timeline-scroll"
          scrollY
          onScrollToLower={onScrollToLower}
          scrollWithAnimation
        >
          {dayGroups.map((group) => (
            <View key={group.dateISO} className="day-group">
              {/* 日期头：pill 标签 + 横向分隔线 */}
              <View className="date-header">
                <View
                  className={`date-label-wrap ${
                    group.dateLabel === '今天' ? 'today' :
                    group.dateLabel === '昨天' ? 'yesterday' : 'past'
                  }`}
                >
                  <Text className={`date-label ${
                    group.dateLabel === '今天' ? 'today' :
                    group.dateLabel === '昨天' ? 'yesterday' : 'past'
                  }`}>
                    {group.dateLabel}
                  </Text>
                </View>
                <View className="date-line" />
              </View>

              {/* 日志卡片列表 */}
              {group.logs.map((log) => {
                const typeDef = getTypeDef(log.type);
                return (
                  <View key={log.id} className="log-item-row">
                    {/* 左侧：32×32 圆形 emoji 指示器 */}
                    <View className="log-indicator">
                      <View
                        className="log-indicator-circle"
                        style={{ backgroundColor: `${typeDef.color}1A`, borderColor: `${typeDef.color}4D` }}
                      >
                        <Text className="log-indicator-emoji">{typeDef.emoji}</Text>
                      </View>
                    </View>

                    {/* 右侧：卡片 */}
                    <View className="log-card">
                      {/* 卡片顶部行：时间 + 类型标签 + Spacer + 头像 + 名字 */}
                      <View className="log-card-top-row">
                        <Text className="log-time">{formatTime(log.createdAt)}</Text>
                        <View
                          className="log-type-badge"
                          style={{ backgroundColor: `${typeDef.color}1A` }}
                        >
                          <Text className="log-type-badge-emoji">{typeDef.emoji}</Text>
                          <Text className="log-type-badge-text" style={{ color: typeDef.color }}>{typeDef.label}</Text>
                        </View>
                        <View className="log-card-top-right">
                          {/* 头像（24px 圆形） */}
                          {log.authorAvatar ? (
                            <Image
                              className="log-author-avatar"
                              src={getImageUrl(log.authorAvatar || '')}
                              mode="aspectFill"
                            />
                          ) : (
                            <View className="log-author-avatar-placeholder">
                              <Text className="log-author-avatar-text">{(log.authorName || '家')[0]}</Text>
                            </View>
                          )}
                          <Text className="log-author-name">{log.authorName || '家庭成员'}</Text>
                        </View>
                      </View>

                      {/* 日志内容 */}
                      <Text className="log-content">{log.content}</Text>

                      {/* 附件图片 */}
                      {log.attachments && log.attachments.length > 0 && (
                        <View className="attachment-grid">
                          {log.attachments.slice(0, 4).map((att, idx) => (
                            <View
                              key={idx}
                              className={`attachment-item ${log.attachments.length === 1 ? 'single' : ''}`}
                              onClick={() => {
                                Taro.previewImage({
                                  urls: log.attachments.map((a) => getAttachmentUrl(a.url)),
                                  current: getAttachmentUrl(att.url),
                                });
                              }}
                            >
                              <Image
                                className="attachment-img"
                                src={getAttachmentUrl(att.url)}
                                mode="aspectFill"
                              />
                              {idx === 3 && log.attachments.length > 4 && (
                                <View className="attachment-more">
                                  <Text className="attachment-more-text">+{log.attachments.length - 4}</Text>
                                </View>
                              )}
                            </View>
                          ))}
                        </View>
                      )}
                    </View>
                  </View>
                );
              })}
            </View>
          ))}

          {loading && (
            <View className="loading-more">
              <Text className="loading-text">加载中...</Text>
            </View>
          )}

          {!hasMore && dayGroups.length > 0 && (
            <View className="end-tip">
              <Text className="end-tip-text">没有更多了</Text>
            </View>
          )}

          <View className="bottom-pad" />
        </ScrollView>
      )}

      {/* FAB 记一笔 — 使用图标 */}
      {familyId && (
        <View className="fab" onClick={() => setShowAddSheet(true)}>
          <Image className="fab-icon" src={require('../../assets/icons/care-add.png')} mode="aspectFit" />
          <Text className="fab-label">记一笔</Text>
        </View>
      )}

      {/* 添加日志底部弹窗 */}
      {showAddSheet && (
        <View className="sheet-overlay" onClick={closeSheet}>
          <View className="add-sheet" onClick={(e) => e.stopPropagation()}>
            {/* 拖拽条 */}
            <View className="sheet-handle" />

            {/* 头部：标题 + 关闭按钮 */}
            <View className="sheet-header">
              <Text className="sheet-title">记一笔</Text>
              <View className="sheet-close-btn" onClick={closeSheet}>
                <Image
                  className="sheet-close-icon"
                  src={require('../../assets/icons/care-close.png')}
                  mode="aspectFit"
                />
              </View>
            </View>

            {/* 照护对象选择 */}
            {recipients.length > 0 && (
              <View className="sheet-section">
                <Text className="sheet-label">照护对象</Text>
                <ScrollView className="sheet-recipients" scrollX>
                  <View className="sheet-recipient-chips">
                    {recipients.map((r) => (
                      <View
                        key={r.id}
                        className={`sheet-recipient-chip ${addRecipientId === r.id ? 'selected' : ''}`}
                        onClick={() => setAddRecipientId(r.id)}
                      >
                        <Text className="chip-emoji">{r.displayAvatar || '👤'}</Text>
                        <Text className="chip-name">{r.name}</Text>
                      </View>
                    ))}
                  </View>
                </ScrollView>
              </View>
            )}

            {/* 类型选择：Wrap 排列，带图标 + 文字 */}
            <View className="sheet-section">
              <Text className="sheet-label">类型</Text>
              <View className="sheet-type-chips-wrap">
                {CARE_LOG_TYPES.filter((t) => t.key !== null).map((t) => (
                  <View
                    key={t.key}
                    className={`sheet-type-chip ${addType === t.key ? 'active' : ''}`}
                    style={addType === t.key && t.color ? { backgroundColor: t.color } : {}}
                    onClick={() => setAddType(t.key!)}
                  >
                    <Text className="sheet-type-emoji">{t.emoji}</Text>
                    <Text className={`sheet-type-label ${addType === t.key ? 'active' : ''}`}>{t.label}</Text>
                  </View>
                ))}
              </View>
            </View>

            {/* 内容输入 */}
            <View className="sheet-section">
              <Text className="sheet-label">内容</Text>
              <View className="content-input-wrap">
                <textarea
                  className="content-input"
                  placeholder="记录今天发生了什么..."
                  value={addContent}
                  onInput={(e: any) => setAddContent(e.detail.value)}
                  maxLength={1000}
                />
              </View>
            </View>

            {/* 发送按钮 */}
            <View className="sheet-footer">
              <View
                className={`send-btn ${submitting || hasUploading ? 'disabled' : ''}`}
                onClick={hasUploading || submitting ? undefined : handleAddLog}
              >
                <Text className="send-btn-text">
                  {submitting ? '发送中...' : hasUploading ? '上传中...' : '发送'}
                </Text>
              </View>
            </View>

            {/* 图片附件（底部） */}
            <View className="sheet-section attach-section">
              <Text className="sheet-label">图片（选填）</Text>
              <View className="attach-row">
                {pendingAttachments.map((att) => (
                  <View key={att.id} className="attach-thumb">
                    <Image
                      className="attach-img"
                      src={att.localPath}
                      mode="aspectFill"
                    />
                    {att.uploading && (
                      <View className="attach-uploading">
                        <Text className="attach-uploading-text">上传中</Text>
                      </View>
                    )}
                    {att.failed && (
                      <View className="attach-failed">
                        <Text className="attach-failed-text">失败</Text>
                      </View>
                    )}
                    <View
                      className="attach-remove"
                      onClick={() => removeAttachment(att.id)}
                    >
                      <Image
                        className="attach-remove-icon"
                        src={require('../../assets/icons/care-close.png')}
                        mode="aspectFit"
                      />
                    </View>
                  </View>
                ))}
                {pendingAttachments.length < 9 && (
                  <View className="attach-add-btn" onClick={handleChooseImages}>
                    <Image
                      className="attach-add-icon-img"
                      src={require('../../assets/icons/care-add.png')}
                      mode="aspectFit"
                    />
                  </View>
                )}
              </View>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}
