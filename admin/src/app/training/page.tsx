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
    <div>
      <div className="flex items-center justify-between mb-6">
        <p className="text-[13px] text-gray-400">
          Bayilerin uygulama içinden görüntüleyebileceği eğitim videoları ve dokümanları. Her formatta dosya kabul edilir.
        </p>
        <button
          onClick={() => setShowForm((v) => !v)}
          className="bg-navy text-white text-sm font-medium px-4 py-2.5 rounded-xl hover:bg-navy-light transition shadow-sm shrink-0 ml-4"
        >
          {showForm ? 'Vazgeç' : '+ İçerik Ekle'}
        </button>
      </div>

      {showForm && (
        <form onSubmit={submit} className="bg-white rounded-2xl border border-gray-100 shadow-sm shadow-gray-100/50 p-6 mb-8 max-w-xl">
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
              className="w-full border border-gray-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-navy/10 focus:border-navy transition"
              required
            />
          </div>

          <div className="mb-5">
            <label className="block text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-1.5">Açıklama (opsiyonel)</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full border border-gray-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-navy/10 focus:border-navy transition"
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
                {/* ÖNEMLİ: "accept" özelliği kaldırıldı — kullanıcı isteği:
                    hem video hem doküman TÜM formatlarda kabul edilmeli.
                    Backend zaten hiçbir mimetype kısıtlaması yapmıyor,
                    burada sadece dosya seçici penceresini kısıtlayan
                    "accept" ipucunu tamamen açık bıraktık. */}
                <span className="text-[11px] text-gray-400">Her format kabul edilir (mp4, mov, pdf, docx, xlsx, pptx, jpg...)</span>
                <input type="file" onChange={(e) => setFile(e.target.files?.[0] ?? null)} className="hidden" />
              </label>
            ) : (
              <input
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                placeholder="https://..."
                className="w-full border border-gray-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-navy/10 focus:border-navy transition"
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
        <div className="bg-white rounded-2xl border border-gray-100 p-12 text-center">
          <p className="text-gray-400 text-sm">Henüz eğitim içeriği eklenmedi.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
          {contents?.map((c: any) => {
            const isVideo = c.type === 'VIDEO';
            return (
              <div
                key={c.id}
                className="group bg-white rounded-2xl border border-gray-100 shadow-sm shadow-gray-100/50 overflow-hidden hover:shadow-md hover:shadow-gray-200/60 transition-shadow"
              >
                {/* Kurs/kütüphane kartı gibi renkli, büyük bir "kapak" alanı
                    — önceki tasarımda sadece küçük bir ikon rozeti vardı,
                    bu haliyle çok daha görsel ve "premium" duruyor. */}
                <div
                  className="h-28 flex items-center justify-center relative"
                  style={{
                    background: isVideo
                      ? 'linear-gradient(135deg, #9B1C2E 0%, #6E1420 100%)'
                      : 'linear-gradient(135deg, #1D3A56 0%, #0B1B2B 100%)',
                  }}
                >
                  <div className="w-14 h-14 rounded-2xl bg-white/15 backdrop-blur-sm flex items-center justify-center group-hover:scale-105 transition-transform">
                    {isVideo ? (
                      <IconVideo width={26} height={26} className="text-white" />
                    ) : (
                      <IconFileText width={26} height={26} className="text-white" />
                    )}
                  </div>
                  <span className="absolute top-3 right-3 text-[9.5px] font-bold text-white/90 bg-white/15 backdrop-blur-sm px-2 py-1 rounded-full tracking-wide">
                    {isVideo ? 'VİDEO' : 'DOKÜMAN'}
                  </span>
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
          <div className="bg-white rounded-2xl w-full max-w-md p-6" onClick={(e) => e.stopPropagation()}>
            <EditContentForm content={editingContent} onCancel={() => setEditingContent(null)} onSave={saveEdit} />
          </div>
        </div>
      )}
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
        active ? 'bg-white text-navy shadow-sm' : 'text-gray-400 hover:text-gray-600'
      }`}
    >
      {icon}
      {label}
    </button>
  );
}
