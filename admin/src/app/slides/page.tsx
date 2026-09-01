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
 *
 * Kullanıcı isteği (devam): "birden fazla slaytı aynı anda eklemekten
 * ve sırasını değiştirmekten bahsettim" — form artık birden çok dosya
 * seçmeye izin veriyor (hepsi arka arkaya yükleniyor) ve her slaytın
 * yanında yukarı/aşağı ok butonlarıyla sırasını değiştirebiliyorsunuz
 * (sürükle-bırak yerine — ek bir kütüphane gerektirmeyen, güvenilir bir
 * çözüm).
 */
export default function SlidesPage() {
  const { data: slides, error, isLoading, mutate } = useSWR('/slides/all', fetcher);
  const [files, setFiles] = useState<File[]>([]);
  const [linkUrl, setLinkUrl] = useState('');
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<{ done: number; total: number } | null>(null);

  async function handleUpload(e: React.FormEvent) {
    e.preventDefault();
    if (files.length === 0) {
      alert('Lütfen en az bir görsel veya video seçin.');
      return;
    }
    setUploading(true);
    setUploadProgress({ done: 0, total: files.length });
    try {
      // Mevcut slaytların en büyük sırasından devam ederek ekliyoruz —
      // böylece toplu eklenen yeni slaytlar listenin sonuna, doğru
      // sırayla ekleniyor (hepsi order=0 çakışmasın diye).
      const maxOrder = (slides || []).reduce((m: number, s: any) => Math.max(m, s.order ?? 0), -1);
      for (let i = 0; i < files.length; i++) {
        const formData = new FormData();
        formData.append('image', files[i]);
        if (linkUrl) formData.append('linkUrl', linkUrl);
        formData.append('order', String(maxOrder + 1 + i));
        await api.post('/slides', formData, { headers: { 'Content-Type': 'multipart/form-data' } });
        setUploadProgress({ done: i + 1, total: files.length });
      }
      setFiles([]);
      setLinkUrl('');
      (document.getElementById('slide-file-input') as HTMLInputElement | null)?.value &&
        ((document.getElementById('slide-file-input') as HTMLInputElement).value = '');
      mutate();
    } catch (err: any) {
      alert(`Yükleme başarısız: ${err.response?.data?.message || 'Bilinmeyen hata'}`);
    } finally {
      setUploading(false);
      setUploadProgress(null);
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

  // Sırayı değiştir: tıklanan slaytla komşusunun "order" değerini
  // birbirleriyle takas ediyoruz — bu, listedeki görünüm sırasını
  // anında değiştirir.
  async function moveSlide(index: number, direction: -1 | 1) {
    if (!slides) return;
    const target = index + direction;
    if (target < 0 || target >= slides.length) return;
    const a = slides[index];
    const b = slides[target];
    await Promise.all([
      api.patch(`/slides/${a.id}`, { order: b.order }),
      api.patch(`/slides/${b.id}`, { order: a.order }),
    ]);
    mutate();
  }

  return (
    <div className="admin-page">
      <div className="mb-7">
        <p className="admin-eyebrow">İÇERİK / MOBİL DENEYİM</p>
        <h2 className="admin-page-title">Ana Sayfa Slaytları</h2>
        <p className="admin-page-subtitle mb-7">
          Mobil uygulamanın ana sayfasındaki tanıtım slaytlarını, sıralamasını ve aktiflik durumunu yönetin.
        </p>
      </div>

      <Card className="mb-8 p-6">
        <CardHeader title="Yeni Slayt(lar) Ekle" />
        <form onSubmit={handleUpload} className="space-y-4 mt-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Görsel veya Video (birden fazla dosya seçebilirsiniz)
            </label>
            <input
              id="slide-file-input"
              type="file"
              accept="image/*,video/*"
              multiple
              onChange={(e) => setFiles(e.target.files ? Array.from(e.target.files) : [])}
              className="block w-full text-sm text-gray-600 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:bg-gray-100 file:text-sm file:font-medium hover:file:bg-gray-200"
            />
            {files.length > 0 && (
              <p className="text-xs text-gray-500 mt-1">{files.length} dosya seçildi — sırayla yüklenecek.</p>
            )}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Bağlantı URL (isteğe bağlı — hepsine uygulanır, dokununca açılır)
            </label>
            <input
              value={linkUrl}
              onChange={(e) => setLinkUrl(e.target.value)}
              className="w-full rounded-lg border border-gray-200 px-3 h-10 text-sm"
              placeholder="https://..."
            />
          </div>
          <button
            type="submit"
            disabled={uploading}
            className="bg-[var(--admin-navy)] text-white text-[12.5px] font-semibold rounded-xl px-4 h-10 hover:bg-slate-800 transition disabled:opacity-50"
          >
            {uploading
              ? uploadProgress
                ? `Yükleniyor... (${uploadProgress.done}/${uploadProgress.total})`
                : 'Yükleniyor...'
              : files.length > 1
                ? `${files.length} Slaytı Ekle`
                : 'Slaytı Ekle'}
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
          {slides.map((s: any, index: number) => (
            <Card key={s.id} className="p-4 flex items-center gap-4 hover:border-blue-200 transition-colors">
              <div className="flex flex-col gap-1">
                <button
                  onClick={() => moveSlide(index, -1)}
                  disabled={index === 0}
                  title="Yukarı taşı"
                  className="w-7 h-7 flex items-center justify-center rounded-md border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed"
                >
                  ↑
                </button>
                <button
                  onClick={() => moveSlide(index, 1)}
                  disabled={index === slides.length - 1}
                  title="Aşağı taşı"
                  className="w-7 h-7 flex items-center justify-center rounded-md border border-gray-200 text-gray-500 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed"
                >
                  ↓
                </button>
              </div>
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
                <div className="text-xs text-gray-400 mt-1">
                  Sıra: {s.order} {s.linkUrl ? `· Bağlantı: ${s.linkUrl}` : ''}
                </div>
              </div>
              <button
                onClick={() => toggleActive(s.id, s.isActive)}
                className={`text-xs font-semibold rounded-full px-3 h-7 flex items-center transition ${
                  s.isActive ? 'bg-green-50 text-green-700 hover:bg-green-100' : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                }`}
              >
                {s.isActive ? 'Aktif' : 'Pasif'}
              </button>
              <button onClick={() => handleDelete(s.id)} className="text-xs font-semibold text-red-600 hover:text-red-700 px-2">
                Sil
              </button>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
