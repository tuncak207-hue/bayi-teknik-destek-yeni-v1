'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { IconVideo, IconFileText, IconUpload, IconLink } from '@/components/icons';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const categoryOptions = ['Yangın Alarm', 'Kamera Sistemleri', 'Genel'];

export default function TrainingPage() {
  const { data: contents, mutate } = useSWR('/training', fetcher);
  const [showForm, setShowForm] = useState(false);
  const [type, setType] = useState<'VIDEO' | 'DOCUMENT'>('VIDEO');
  const [sourceMode, setSourceMode] = useState<'file' | 'url'>('file');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('');
  const [url, setUrl] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [editingContent, setEditingContent] = useState<any>(null);
  const [completionsForId, setCompletionsForId] = useState<string | null>(null);

  // Kullanıcı isteği: "eğitimi tamamlamak için 1 gün verelim, geri sayaç
  // işlesin... admin panelinde kim izledi kim izlemedi bilelim." Her
  // eğitim için zorunlu değil — admin burada isteğe bağlı açıyor.
  const [requiresCompletion, setRequiresCompletion] = useState(false);
  const [deadlineHours, setDeadlineHours] = useState(24);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    if (sourceMode === 'file' && !file) {
      setError('Lütfen bir dosya seçin.');
      return;
    }
    if (sourceMode === 'url' && !url.trim()) {
      setError('Lütfen bir bağlantı girin.');
      return;
    }
    setSubmitting(true);
    try {
      const formData = new FormData();
      formData.append('title', title);
      formData.append('description', description);
      formData.append('type', type);
      formData.append('category', category);
      formData.append('requiresCompletion', String(requiresCompletion));
      formData.append('deadlineHours', String(deadlineHours));
      if (sourceMode === 'file' && file) formData.append('file', file);
      if (sourceMode === 'url') formData.append('url', url.trim());

      // ÖNEMLİ: Content-Type başlığı elle ayarlanmamalı — axios FormData
      // gönderdiğimizi algılayıp boundary'yi otomatik ekliyor.
      await api.post('/training', formData);

      setTitle('');
      setDescription('');
      setCategory('');
      setUrl('');
      setFile(null);
      setRequiresCompletion(false);
      setDeadlineHours(24);
      setShowForm(false);
      mutate();
    } catch (err: any) {
      setError(err.response?.data?.message || 'İçerik eklenemedi.');
    } finally {
      setSubmitting(false);
    }
  }

  async function remove(id: string) {
    if (!confirm('Bu içeriği silmek istediğinize emin misiniz?')) return;
    await api.delete(`/training/${id}`);
    mutate();
  }

  async function saveEdit(fields: { title: string; description: string; category: string }) {
    await api.patch(`/training/${editingContent.id}`, fields);
    mutate();
    setEditingContent(null);
  }

  return (
    <div className="admin-page">
      <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between mb-7">
        <div><p className="admin-eyebrow">İÇERİK / EĞİTİM</p><h2 className="admin-page-title">Eğitim İçerikleri</h2><p className="admin-page-subtitle">Bayilerin uygulama içinde kullanacağı eğitim video ve dokümanlarını yönetin.</p></div>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="bg-[var(--admin-navy)] text-white text-[12.5px] font-semibold px-4 h-10 rounded-xl hover:bg-slate-800 transition shadow-sm shrink-0 ml-4"
        >
          {showForm ? 'Vazgeç' : '+ İçerik Ekle'}
        </button>
      </div>

      {showForm && (
        <form onSubmit={submit} className="admin-surface p-6 mb-8 max-w-xl">
          {error && (
            <div className="mb-5 px-3.5 py-2.5 bg-red-50 border border-red-100 rounded-lg">
              <p className="text-[13px] text-red-600">{error}</p>
            </div>
          )}

          <div className="mb-5">
            <label className="block text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-2">İçerik Türü</label>
            <div className="flex gap-2 p-1 bg-[#F2F3F5] rounded-xl">
              <SegmentButton active={type === 'VIDEO'} onClick={() => setType('VIDEO')} icon={<IconVideo width={15} height={15} />} label="Video" />
              <SegmentButton
                active={type === 'DOCUMENT'}
                onClick={() => setType('DOCUMENT')}
                icon={<IconFileText width={15} height={15} />}
                label="Doküman"
              />
            </div>
          </div>

          <div className="mb-5">
            <label className="block text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-1.5">Başlık</label>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full border border-slate-200 bg-slate-50 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-300 transition"
              required
            />
          </div>

          <div className="mb-5">
            <label className="block text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-1.5">Açıklama (opsiyonel)</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full border border-slate-200 bg-slate-50 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-300 transition"
              rows={2}
            />
          </div>

          <div className="mb-5">
            <label className="block text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-2">Kategori (opsiyonel)</label>
            <div className="flex flex-wrap gap-2">
              {categoryOptions.map((c) => (
                <button
                  key={c}
                  type="button"
                  onClick={() => setCategory(category === c ? '' : c)}
                  className={`px-3 py-1.5 rounded-full text-xs font-medium border transition ${
                    category === c ? 'bg-brand text-white border-brand' : 'border-gray-200 text-gray-500 hover:border-gray-300'
                  }`}
                >
                  {c}
                </button>
              ))}
            </div>
          </div>

          {/* Tamamlama Takibi */}
          <div className="mb-5 p-4 bg-amber-50/60 border border-amber-100 rounded-xl">
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={requiresCompletion}
                onChange={(e) => setRequiresCompletion(e.target.checked)}
                className="w-4 h-4"
              />
              <span className="text-[13px] font-semibold text-gray-700">Tamamlama takibi gereksin</span>
            </label>
            <p className="text-[11.5px] text-gray-500 mt-1 ml-6">
              Açarsanız, bayiler belirlediğiniz süre içinde &quot;Tamamladım&quot; demeli. Süre dolarsa ve tamamlamamışsa, burada
              &quot;tamamlanmadı&quot; olarak görünür.
            </p>
            {requiresCompletion && (
              <div className="mt-3 ml-6">
                <label className="block text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-1.5">Süre (saat)</label>
                <input
                  type="number"
                  min={1}
                  value={deadlineHours}
                  onChange={(e) => setDeadlineHours(Number(e.target.value) || 24)}
                  className="w-28 border border-slate-200 bg-white rounded-lg px-3 py-1.5 text-sm"
                />
                <span className="text-[11.5px] text-gray-400 ml-2">(varsayılan 24 saat = 1 gün)</span>
              </div>
            )}
          </div>

          <div className="mb-5">
            <label className="block text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-2">Kaynak</label>
            <div className="flex gap-2 p-1 bg-[#F2F3F5] rounded-xl mb-3">
              <SegmentButton
                active={sourceMode === 'file'}
                onClick={() => setSourceMode('file')}
                icon={<IconUpload width={15} height={15} />}
                label="Dosya Yükle"
              />
              <SegmentButton
                active={sourceMode === 'url'}
                onClick={() => setSourceMode('url')}
                icon={<IconLink width={15} height={15} />}
                label="Bağlantı (URL)"
              />
            </div>

            {sourceMode === 'file' ? (
              <label className="flex flex-col items-center justify-center gap-2 border-2 border-dashed border-gray-200 rounded-xl py-8 cursor-pointer hover:border-navy/30 hover:bg-navy/[0.02] transition">
                <IconUpload width={22} height={22} className="text-gray-400" />
                <span className="text-[13px] text-gray-500 font-medium">{file ? file.name : 'Dosya seçmek için tıklayın'}</span>
                <span className="text-[11px] text-gray-400">Her format kabul edilir (mp4, mov, pdf, docx, xlsx, pptx, jpg...)</span>
                <input type="file" onChange={(e) => setFile(e.target.files?.[0] ?? null)} className="hidden" />
              </label>
            ) : (
              <input
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                placeholder="https://..."
                className="w-full border border-slate-200 bg-slate-50 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-300 transition"
              />
            )}
          </div>

          <button
            type="submit"
            disabled={submitting}
            className="w-full bg-brand text-white text-sm font-semibold px-4 py-2.5 rounded-xl hover:bg-brand-dark transition disabled:opacity-60"
          >
            {submitting ? 'Ekleniyor...' : 'İçeriği Ekle'}
          </button>
        </form>
      )}

      {contents?.length === 0 ? (
        <div className="bg-white rounded-lg border border-gray-100 p-8 text-center">
          <p className="text-gray-400 text-sm">Henüz eğitim içeriği eklenmedi.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {contents?.map((c: any) => {
            const isVideo = c.type === 'VIDEO';
            return (
              <div
                key={c.id}
                className="group bg-white rounded-lg border border-gray-100 shadow-[0_1px_2px_rgba(15,23,42,0.04)] shadow-gray-100/50 overflow-hidden hover:shadow-md hover:shadow-gray-200/60 transition-shadow"
              >
                <div
                  className="h-28 flex items-center justify-center relative"
                  style={{
                    background: isVideo
                      ? 'linear-gradient(135deg, #9B1C2E 0%, #6E1420 100%)'
                      : 'linear-gradient(135deg, #1D3A56 0%, #0B1B2B 100%)',
                  }}
                >
                  <div className="w-14 h-14 rounded-lg bg-white/15 backdrop-blur-sm flex items-center justify-center group-hover:scale-105 transition-transform">
                    {isVideo ? (
                      <IconVideo width={26} height={26} className="text-white" />
                    ) : (
                      <IconFileText width={26} height={26} className="text-white" />
                    )}
                  </div>
                  <span className="absolute top-3 right-3 text-[9.5px] font-bold text-white/90 bg-white/15 backdrop-blur-sm px-2 py-1 rounded-full tracking-wide">
                    {isVideo ? 'VİDEO' : 'DOKÜMAN'}
                  </span>
                  {c.requiresCompletion && (
                    <span className="absolute top-3 left-3 text-[9.5px] font-bold text-amber-900 bg-amber-300 px-2 py-1 rounded-full tracking-wide">
                      TAKİPLİ
                    </span>
                  )}
                </div>
                <div className="p-4">
                  <p className="font-semibold text-[14px] text-gray-800 leading-snug line-clamp-2 min-h-[36px]">{c.title}</p>
                  {c.description && <p className="text-[12px] text-gray-400 mt-1.5 line-clamp-2">{c.description}</p>}
                  <div className="flex items-center justify-between mt-3 pt-3 border-t border-gray-50">
                    {c.category ? (
                      <span className="text-[10.5px] font-medium text-gray-500 bg-gray-100 px-2 py-1 rounded-full">{c.category}</span>
                    ) : (
                      <span className="text-[10.5px] text-gray-300">{new Date(c.createdAt).toLocaleDateString('tr-TR')}</span>
                    )}
                    <div className="flex gap-2">
                      {c.requiresCompletion && (
                        <button onClick={() => setCompletionsForId(c.id)} className="text-blue-500 hover:text-blue-700 transition text-xs font-medium">
                          Kim İzledi?
                        </button>
                      )}
                      <button onClick={() => setEditingContent(c)} className="text-gray-300 hover:text-navy transition text-xs font-medium">
                        Düzenle
                      </button>
                      <button onClick={() => remove(c.id)} className="text-gray-300 hover:text-red-500 transition text-xs font-medium">
                        Sil
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {editingContent && (
        <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50 p-4" onClick={() => setEditingContent(null)}>
          <div className="bg-white rounded-lg w-full max-w-md p-6" onClick={(e) => e.stopPropagation()}>
            <EditContentForm content={editingContent} onCancel={() => setEditingContent(null)} onSave={saveEdit} />
          </div>
        </div>
      )}

      {completionsForId && (
        <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50 p-4" onClick={() => setCompletionsForId(null)}>
          <div className="bg-white rounded-lg w-full max-w-lg p-6 max-h-[80vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <CompletionsView trainingId={completionsForId} onClose={() => setCompletionsForId(null)} />
          </div>
        </div>
      )}
    </div>
  );
}

/** Kullanıcı isteği: "admin panelinde kim izledi kim izlemedi bilelim" */
function CompletionsView({ trainingId, onClose }: { trainingId: string; onClose: () => void }) {
  const { data } = useSWR(`/training/${trainingId}/completions`, fetcher, { refreshInterval: 5000 });

  if (!data) return <p className="text-sm text-gray-400">Yükleniyor...</p>;

  const statusLabel: Record<string, { label: string; className: string }> = {
    COMPLETED: { label: 'Tamamladı', className: 'bg-green-50 text-green-700' },
    PENDING: { label: 'Süresi Devam Ediyor', className: 'bg-amber-50 text-amber-700' },
    EXPIRED: { label: 'Tamamlanmadı (süre doldu)', className: 'bg-red-50 text-red-700' },
  };

  return (
    <div>
      <h3 className="text-sm font-bold text-navy mb-1">{data.training.title}</h3>
      <p className="text-xs text-gray-400 mb-4">
        Süre: {data.training.deadlineHours} saat · Toplam {data.rows.length} bayi
      </p>
      <div className="space-y-2">
        {data.rows.map((r: any) => {
          const s = statusLabel[r.status] || { label: r.status, className: 'bg-gray-50 text-gray-500' };
          return (
            <div key={r.id} className="flex items-center justify-between p-3 rounded-lg border border-gray-100">
              <div>
                <p className="text-[13px] font-semibold text-gray-800">
                  {r.firstName} {r.lastName}
                </p>
                <p className="text-[11.5px] text-gray-400">{r.company}</p>
              </div>
              <span className={`text-[11px] font-semibold px-2.5 py-1 rounded-full ${s.className}`}>{s.label}</span>
            </div>
          );
        })}
      </div>
      <button onClick={onClose} className="w-full mt-5 text-sm font-medium text-gray-600 border border-gray-200 rounded-xl py-2.5 hover:bg-gray-50 transition">
        Kapat
      </button>
    </div>
  );
}

function EditContentForm({
  content,
  onCancel,
  onSave,
}: {
  content: any;
  onCancel: () => void;
  onSave: (fields: { title: string; description: string; category: string }) => void;
}) {
  const [title, setTitle] = useState(content.title || '');
  const [description, setDescription] = useState(content.description || '');
  const [category, setCategory] = useState(content.category || '');

  return (
    <div>
      <h3 className="text-sm font-bold text-navy mb-4">İçeriği Düzenle</h3>
      <p className="text-xs text-gray-400 mb-4">Dosyanın/videonun kendisi değişmez, sadece bilgileri güncellenir.</p>
      <div className="space-y-3">
        <div>
          <label className="block text-xs text-gray-400 mb-1">Başlık</label>
          <input value={title} onChange={(e) => setTitle(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label className="block text-xs text-gray-400 mb-1">Açıklama</label>
          <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={2} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label className="block text-xs text-gray-400 mb-1">Kategori</label>
          <div className="flex flex-wrap gap-2">
            {categoryOptions.map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => setCategory(category === c ? '' : c)}
                className={`px-3 py-1.5 rounded-full text-xs font-medium border transition ${
                  category === c ? 'bg-brand text-white border-brand' : 'border-gray-200 text-gray-500 hover:border-gray-300'
                }`}
              >
                {c}
              </button>
            ))}
          </div>
        </div>
      </div>
      <div className="flex gap-2 mt-5">
        <button onClick={onCancel} className="flex-1 text-sm font-medium text-gray-600 border border-gray-200 rounded-xl py-2.5 hover:bg-gray-50 transition">
          Vazgeç
        </button>
        <button
          onClick={() => onSave({ title, description, category })}
          className="flex-1 text-sm font-medium text-white bg-brand rounded-xl py-2.5 hover:bg-brand-dark transition"
        >
          Kaydet
        </button>
      </div>
    </div>
  );
}

function SegmentButton({
  active,
  onClick,
  icon,
  label,
}: {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex-1 flex items-center justify-center gap-1.5 py-2 rounded-lg text-[13px] font-semibold transition ${
        active ? 'bg-white text-navy shadow-[0_1px_2px_rgba(15,23,42,0.04)]' : 'text-gray-400 hover:text-gray-600'
      }`}
    >
      {icon}
      {label}
    </button>
  );
}
