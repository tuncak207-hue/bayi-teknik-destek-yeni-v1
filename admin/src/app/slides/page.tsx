'use client';

import Image from 'next/image';
import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Card, CardHeader, LoadingState, EmptyState, ErrorState } from '@/components/ui';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

/**
 * Kullanıcı isteği: "uygulama açılırken ekranda slayt dönsün, bu
 * slaytları sürekli değiştirebilir durumda olayım." Bu sayfa, mobil Ana
 * Sayfa'daki dönen tanıtım slaytlarını yönetmeyi sağlıyor — görsel
 * yükleme, sıralama, başlık/alt başlık, aktif/pasif yapma, silme.
 */
export default function SlidesPage() {
  const { data: slides, error, isLoading, mutate } = useSWR('/slides/all', fetcher);
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState('');
  const [subtitle, setSubtitle] = useState('');
  const [linkUrl, setLinkUrl] = useState('');
  const [order, setOrder] = useState('0');
  const [uploading, setUploading] = useState(false);

  async function handleUpload(e: React.FormEvent) {
    e.preventDefault();
    if (!file) {
      alert('Lütfen bir görsel seçin.');
      return;
    }
    setUploading(true);
    try {
      const formData = new FormData();
      formData.append('image', file);
      if (title) formData.append('title', title);
      if (subtitle) formData.append('subtitle', subtitle);
      if (linkUrl) formData.append('linkUrl', linkUrl);
      formData.append('order', order);
      await api.post('/slides', formData, { headers: { 'Content-Type': 'multipart/form-data' } });
      setFile(null);
      setTitle('');
      setSubtitle('');
      setLinkUrl('');
      setOrder('0');
      (document.getElementById('slide-file-input') as HTMLInputElement | null)?.value && ((document.getElementById('slide-file-input') as HTMLInputElement).value = '');
      mutate();
    } catch (err: any) {
      alert(`Yükleme başarısız: ${err.response?.data?.message || 'Bilinmeyen hata'}`);
    } finally {
      setUploading(false);
    }
  }

  async function toggleActive(id: string, isActive: boolean) {
    await api.patch(`/slides/${id}`, { isActive: !isActive });
    mutate();
  }

  async function handleDelete(id: string) {
    if (!confirm('Bu slaytı silmek istediğinize emin misiniz?')) return;
    await api.delete(`/slides/${id}`);
    mutate();
  }

  return (
          <div className="admin-page">
        <div className="mb-7"><p className="admin-eyebrow">İÇERİK / MOBİL DENEYİM</p><h2 className="admin-page-title">Ana Sayfa Slaytları</h2>

              <p className="admin-page-subtitle mb-7">Mobil uygulamanın ana sayfasındaki tanıtım slaytlarını, sıralamasını ve aktiflik durumunu yönetin.</p></div>

        <Card className="mb-8 p-6">

        <CardHeader title="Yeni Slayt Ekle" />
        <form onSubmit={handleUpload} className="space-y-4 mt-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Görsel</label>
            <input
              id="slide-file-input"
              type="file"
              accept="image/*"
              onChange={(e) => setFile(e.target.files?.[0] || null)}
              className="block w-full text-sm text-gray-600 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:bg-gray-100 file:text-sm file:font-medium hover:file:bg-gray-200"
            />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Başlık (isteğe bağlı)</label>
              <input value={title} onChange={(e) => setTitle(e.target.value)} className="w-full rounded-lg border border-gray-200 px-3 h-10 text-sm" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Alt Başlık (isteğe bağlı)</label>
              <input value={subtitle} onChange={(e) => setSubtitle(e.target.value)} className="w-full rounded-lg border border-gray-200 px-3 h-10 text-sm" />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Bağlantı URL (isteğe bağlı — dokununca açılır)</label>
              <input value={linkUrl} onChange={(e) => setLinkUrl(e.target.value)} className="w-full rounded-lg border border-gray-200 px-3 h-10 text-sm" placeholder="https://..." />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Sıra (küçük sayı önce gösterilir)</label>
              <input type="number" value={order} onChange={(e) => setOrder(e.target.value)} className="w-full rounded-lg border border-gray-200 px-3 h-10 text-sm" />
            </div>
          </div>
          <button
            type="submit"
            disabled={uploading}
            className="bg-[var(--admin-navy)] text-white text-[12.5px] font-semibold rounded-xl px-4 h-10 hover:bg-slate-800 transition disabled:opacity-50"
          >
            {uploading ? 'Yükleniyor...' : 'Slaytı Ekle'}
          </button>
        </form>
      </Card>

      {isLoading ? (
        <LoadingState />
      ) : error ? (
        <ErrorState onRetry={() => mutate()} />
      ) : !slides || slides.length === 0 ? (
        <EmptyState title="Henüz slayt eklenmedi" description="Yukarıdaki formdan ilk slaytınızı ekleyin." />
      ) : (
        <div className="space-y-3">
          {slides.map((s: any) => (
            <Card key={s.id} className="p-4 flex items-center gap-4 hover:border-blue-200 transition-colors">
              <Image
                src={s.imageUrl}
                alt={s.title || 'Slayt'}
                width={112}
                height={64}
                unoptimized
                loader={({ src }) => src}
                className="w-28 h-16 object-cover rounded-lg bg-gray-100 flex-shrink-0"
              />
              <div className="flex-1 min-w-0">
                <div className="font-semibold text-gray-900 truncate">{s.title || '(Başlıksız)'}</div>
                <div className="text-sm text-gray-500 truncate">{s.subtitle || '—'}</div>
                <div className="text-xs text-gray-400 mt-1">Sıra: {s.order} {s.linkUrl ? `· Bağlantı: ${s.linkUrl}` : ''}</div>
              </div>
              <button
                onClick={() => toggleActive(s.id, s.isActive)}
                className={`text-xs font-semibold rounded-full px-3 h-7 flex items-center transition ${
                  s.isActive ? 'bg-green-50 text-green-700 hover:bg-green-100' : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                }`}
              >
                {s.isActive ? 'Aktif' : 'Pasif'}
              </button>
              <button
                onClick={() => handleDelete(s.id)}
                className="text-xs font-semibold text-red-600 hover:text-red-700 px-2"
              >
                Sil
              </button>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
