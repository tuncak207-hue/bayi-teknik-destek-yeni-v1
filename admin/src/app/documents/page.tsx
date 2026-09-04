'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Badge, LoadingState, EmptyState, ErrorState } from '@/components/ui';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

type UploadItem = {
  file: File;
  status: 'pending' | 'uploading' | 'done' | 'error';
  error?: string;
};

export default function DocumentsPage() {
  const { data: documents, error, isLoading, mutate } = useSWR('/documents', fetcher);
  const [form, setForm] = useState({ brand: '', model: '', version: '', isDatasheet: false });
  const [items, setItems] = useState<UploadItem[]>([]);
  const [uploading, setUploading] = useState(false);
  const [reprocessing, setReprocessing] = useState(false);

  // Kullanıcı isteği: "her seferinde neden tüm belgeleri işlesin ki" —
  // artık iki ayrı buton var: biri sadece eksik/başarısız olanları
  // işler (varsayılan, hızlı), diğeri gerçekten HERKESİ sıfırdan
  // yeniden işler (force=true, sadece embedding sağlayıcı değiştiğinde
  // gerekli).
  async function handleReprocess(force: boolean) {
    const message = force
      ? 'TÜM dokümanlar (zaten işlenmiş olanlar dahil) sıfırdan yeniden işlenecek. Bu, doküman sayısına göre uzun sürebilir. Devam edilsin mi?'
      : 'Sadece henüz işlenmemiş veya daha önce başarısız olmuş dokümanlar işlenecek. Devam edilsin mi?';
    if (!confirm(message)) return;
    setReprocessing(true);
    try {
      const res = await api.post(`/rag/reprocess-all${force ? '?force=true' : ''}`);
      const skippedText = res.data.skipped > 0 ? ` (${res.data.skipped} doküman zaten işlenmiş olduğu için atlandı)` : '';
      alert(`Tamamlandı: ${res.data.processed}/${res.data.total} doküman yeniden işlendi.${skippedText}`);
      // ÖNEMLİ DÜZELTME: "hata olanların durumu yine hata görünüyor" —
      // backend durumu doğru güncelliyordu ama liste hiç yeniden
      // çekilmiyordu, bu yüzden ekranda eski (bayat) veri kalıyordu.
      mutate();
    } catch (e: any) {
      alert(`Hata: ${e.response?.data?.message || 'Yeniden işleme başarısız oldu.'}`);
    } finally {
      setReprocessing(false);
    }
  }
  const [selected, setSelected] = useState<any>(null);
  const [editing, setEditing] = useState(false);

  function handleFilesSelected(fileList: FileList | null) {
    if (!fileList) return;
    setItems(Array.from(fileList).map((file) => ({ file, status: 'pending' })));
  }

  function titleFromFileName(name: string) {
    return name.replace(/\.[^/.]+$/, ''); // uzantıyı at
  }

  async function handleUpload(e: React.FormEvent) {
    e.preventDefault();
    if (items.length === 0) return;
    setUploading(true);

    for (let i = 0; i < items.length; i++) {
      setItems((prev) => prev.map((it, idx) => (idx === i ? { ...it, status: 'uploading' } : it)));
      try {
        const data = new FormData();
        data.append('brand', form.brand);
        data.append('model', form.model);
        data.append('version', form.version);
        data.append('isDatasheet', String(form.isDatasheet));
        data.append('title', titleFromFileName(items[i].file.name));
        data.append('file', items[i].file);
        // ÖNEMLİ: Content-Type başlığını burada ELLE ayarlamıyoruz.
        // FormData gönderirken axios/tarayıcı, doğru multipart boundary'yi
        // kendisi otomatik ekler — elle "multipart/form-data" yazmak bu
        // boundary'yi bozar ve backend dosyayı hiç okuyamaz. Önceki
        // sürümdeki yükleme hatasının kök sebebi buydu.
        await api.post('/documents/upload', data);
        setItems((prev) => prev.map((it, idx) => (idx === i ? { ...it, status: 'done' } : it)));
      } catch (err: any) {
        setItems((prev) =>
          prev.map((it, idx) =>
            idx === i ? { ...it, status: 'error', error: err?.response?.data?.message || 'Yükleme başarısız.' } : it,
          ),
        );
      }
    }

    setUploading(false);
    mutate();
  }

  function resetForm() {
    setForm({ brand: '', model: '', version: '' });
    setItems([]);
  }

  async function remove(id: string) {
    if (!confirm('Bu dokümanı silmek istediğinize emin misiniz?')) return;
    await api.delete(`/documents/${id}`);
    mutate();
    setSelected(null);
  }

  async function saveEdit(fields: { title: string; brand: string; model: string }) {
    await api.patch(`/documents/${selected.id}`, fields);
    mutate();
    setSelected((s: any) => ({ ...s, ...fields }));
    setEditing(false);
  }

  const allDone = items.length > 0 && items.every((it) => it.status === 'done' || it.status === 'error');

  return (
    <div className="admin-page">
      <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between mb-7">
        <div><p className="admin-eyebrow">İÇERİK / BİLGİ BANKASI</p><h2 className="admin-page-title">Dokümanlar</h2><p className="admin-page-subtitle">Teknik dokümanları yükleyin, işleme durumunu izleyin ve bilgi bankasını güncel tutun.</p></div>
      <div className="flex flex-wrap justify-end gap-2">
        <button
          onClick={() => handleReprocess(false)}
          disabled={reprocessing}
          className="text-[12.5px] font-semibold text-slate-700 border border-slate-200 bg-white rounded-xl px-3.5 h-10 hover:bg-slate-50 transition disabled:opacity-50"
          title="Sadece henüz işlenmemiş veya başarısız olmuş dokümanları işler — zaten işlenmiş dokümanları atlar, çok daha hızlıdır."
        >
          {reprocessing ? '⏳ İşleniyor...' : '🔄 Eksik/Başarısız Olanları İşle'}
        </button>
        <button
          onClick={() => handleReprocess(true)}
          disabled={reprocessing}
          className="text-[12.5px] font-semibold text-amber-800 border border-amber-200 bg-amber-50 rounded-xl px-3.5 h-10 hover:bg-amber-100 transition disabled:opacity-50"
          title="AI/embedding sağlayıcısını değiştirdiyseniz (örn. Voyage AI'dan Ollama'ya geçiş), TÜM dokümanları (zaten işlenmiş olanlar dahil) sıfırdan yeniden işlemeniz gerekir."
        >
          {reprocessing ? '⏳ İşleniyor...' : '⚠️ Tümünü Zorla Yeniden İşle'}
        </button>
      </div>
      </div>
      <form onSubmit={handleUpload} className="admin-surface p-6 mb-8 space-y-5">
        <div className="grid grid-cols-3 gap-4">
          <Input label="Marka" value={form.brand} onChange={(v) => setForm({ ...form, brand: v })} placeholder="Honeywell" />
          <Input label="Model" value={form.model} onChange={(v) => setForm({ ...form, model: v })} placeholder="MA8000" />
          <Input label="Versiyon" value={form.version} onChange={(v) => setForm({ ...form, version: v })} placeholder="V3" />
        </div>

        {/* Kullanıcı isteği (Manus önerisi): "Datasheet-First RAG" — resmi
            datasheet olarak işaretlenen dokümanlar, AI cevap üretirken
            öncelikli olarak aranır. */}
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={form.isDatasheet}
            onChange={(e) => setForm({ ...form, isDatasheet: e.target.checked })}
            className="w-4 h-4"
          />
          <span className="text-sm text-gray-700">Bu resmi bir datasheet / teknik döküman (AI cevap üretirken öncelikli kullanılır)</span>
        </label>

        <div>
          <label className="block text-sm text-gray-600 mb-1">
            Dosyalar (PDF, DOCX, XLSX, TXT, JPG, PNG) — birden fazla dosya seçebilirsiniz
          </label>
          <input
            type="file"
            multiple
            accept=".pdf,.docx,.xlsx,.txt,.jpg,.jpeg,.png"
            onChange={(e) => handleFilesSelected(e.target.files)}
            aria-label="Doküman dosyaları seç"
            className="w-full border border-slate-200 bg-slate-50 rounded-xl px-3 py-2.5 text-sm"
          />
          <p className="text-xs text-gray-400 mt-1">
            Her dosyanın başlığı, dosya adından otomatik alınır. Marka/model/versiyon tüm dosyalara uygulanır.
          </p>
        </div>

        {items.length > 0 && (
          <div className="border border-gray-100 rounded-lg divide-y">
            {items.map((it, idx) => (
              <div key={idx} className="flex items-center justify-between px-3.5 py-3 text-sm hover:bg-slate-50/70">
                <span className="truncate">{it.file.name}</span>
                <span>
                  {it.status === 'pending' && <span className="text-gray-400">Bekliyor</span>}
                  {it.status === 'uploading' && <span className="text-amber-600">Yükleniyor...</span>}
                  {it.status === 'done' && <span className="text-green-600">✓ Yüklendi</span>}
                  {it.status === 'error' && <span className="text-red-600">✗ {it.error}</span>}
                </span>
              </div>
            ))}
          </div>
        )}

        <div className="flex gap-3">
          <button
            type="submit"
            disabled={uploading || items.length === 0 || !form.brand || !form.model || !form.version}
            className="bg-[var(--admin-navy)] text-white rounded-xl px-4 h-10 font-semibold hover:bg-slate-800 transition disabled:opacity-60"
          >
            {uploading ? 'Yükleniyor...' : `${items.length > 1 ? `${items.length} Dokümanı Yükle` : 'Doküman Yükle'}`}
          </button>
          {allDone && (
            <button type="button" onClick={resetForm} className="text-gray-600 hover:underline">
              Temizle
            </button>
          )}
        </div>
      </form>

      {/* Kullanıcı isteği: "AI teknik asistan sadece dokümana değil, bu
          URL linkine de baksın" — web sayfaları da dokümanlarla AYNI
          bilgi bankasına (RAG) eklenir, AI cevap verirken otomatik olarak
          ikisine de bakar. */}
      <UrlLinkForm onAdded={() => mutate()} />

      <p className="text-[13px] text-gray-400 mb-3">Bir doküman kartına tıklayarak detaylarını görüntüleyip düzenleyebilir veya silebilirsiniz.</p>
      {isLoading && <LoadingState />}
      {error && <ErrorState onRetry={() => mutate()} />}
      {!isLoading && !error && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {documents?.map((d: any) => (
            <button
              key={d.id}
              onClick={() => {
                setSelected(d);
                setEditing(false);
              }}
              className="text-left bg-white rounded-lg border border-gray-100 shadow-[0_1px_2px_rgba(15,23,42,0.04)] shadow-gray-100/50 p-5 hover:shadow-md hover:shadow-gray-200/60 hover:-translate-y-0.5 transition-all"
            >
              <div className="flex items-start justify-between mb-3">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center text-white shrink-0 shadow-[0_1px_2px_rgba(15,23,42,0.04)]">
                  📄
                </div>
                <StatusBadge status={d.status} />
              </div>
              <p className="text-sm font-bold text-navy truncate">{d.title}</p>
              <p className="text-xs text-gray-500 mt-1 truncate">{d.brand} / {d.model}</p>
              <p className="text-xs text-gray-400 mt-0.5">v{d.versions?.find((v: any) => v.isCurrent)?.version ?? '—'}</p>
            </button>
          ))}
        </div>
      )}
      {!isLoading && documents?.length === 0 && <EmptyState title="Henüz doküman yok" description="Aşağıdaki alandan ilk dokümanı yükleyebilirsiniz." />}

      {selected && (
        <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50 p-4" onClick={() => setSelected(null)}>
          <div className="bg-white rounded-lg w-full max-w-md overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="h-1.5 bg-brand" />
            <div className="p-6">
              {editing ? (
                <EditDocumentForm document={selected} onCancel={() => setEditing(false)} onSave={saveEdit} />
              ) : (
                <>
                  <div className="flex items-start justify-between mb-4">
                    <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center text-lg shrink-0 shadow-[0_1px_2px_rgba(15,23,42,0.04)]">📄</div>
                    <StatusBadge status={selected.status} />
                  </div>
                  <h3 className="text-base font-bold text-navy">{selected.title}</h3>
                  <p className="text-sm text-gray-500 mt-0.5">{selected.brand} / {selected.model}</p>
                  <div className="mt-4 space-y-2 text-sm">
                    <DetailRow label="Güncel Versiyon" value={`v${selected.versions?.find((v: any) => v.isCurrent)?.version ?? '—'}`} />
                    <DetailRow label="Toplam Versiyon" value={String(selected.versions?.length ?? 0)} />
                  </div>
                  <div className="flex flex-wrap gap-2 mt-6">
                    <button onClick={() => setEditing(true)} className="text-sm font-medium text-navy border border-gray-200 rounded-xl px-4 py-2 hover:bg-gray-50 transition">
                      Düzenle
                    </button>
                    <button onClick={() => remove(selected.id)} className="text-sm font-medium text-red-600 border border-red-200 rounded-xl px-4 py-2 hover:bg-red-50 transition">
                      Sil
                    </button>
                  </div>
                  <button onClick={() => setSelected(null)} className="text-xs text-gray-400 hover:text-gray-600 mt-4 block mx-auto">
                    Kapat
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between border-b border-gray-50 pb-2">
      <span className="text-gray-400">{label}</span>
      <span className="text-gray-700 font-medium">{value}</span>
    </div>
  );
}

function EditDocumentForm({
  document,
  onCancel,
  onSave,
}: {
  document: any;
  onCancel: () => void;
  onSave: (fields: { title: string; brand: string; model: string }) => void;
}) {
  const [title, setTitle] = useState(document.title || '');
  const [brand, setBrand] = useState(document.brand || '');
  const [model, setModel] = useState(document.model || '');

  return (
    <div>
      <h3 className="text-sm font-bold text-navy mb-4">Dokümanı Düzenle</h3>
      <div className="space-y-3">
        <div>
          <label className="block text-xs text-gray-400 mb-1">Başlık</label>
          <input value={title} onChange={(e) => setTitle(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
        </div>
        <div className="grid grid-cols-2 gap-2">
          <div>
            <label className="block text-xs text-gray-400 mb-1">Marka</label>
            <input value={brand} onChange={(e) => setBrand(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-gray-400 mb-1">Model</label>
            <input value={model} onChange={(e) => setModel(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          </div>
        </div>
      </div>
      <div className="flex gap-2 mt-5">
        <button onClick={onCancel} className="flex-1 text-sm font-medium text-gray-600 border border-gray-200 rounded-xl py-2.5 hover:bg-gray-50 transition">
          Vazgeç
        </button>
        <button
          onClick={() => onSave({ title, brand, model })}
          className="flex-1 text-sm font-medium text-white bg-brand rounded-xl py-2.5 hover:bg-brand-dark transition"
        >
          Kaydet
        </button>
      </div>
    </div>
  );
}

function Input({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <div>
      <label className="block text-sm text-gray-600 mb-1">{label}</label>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full border border-gray-300 rounded-lg px-3 py-2"
        required
      />
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const tone: Record<string, 'pending' | 'success' | 'danger'> = { PROCESSING: 'pending', READY: 'success', ERROR: 'danger' };
  const label: Record<string, string> = { PROCESSING: 'İşleniyor', READY: 'Hazır', ERROR: 'Hata' };
  return <Badge label={label[status] || status} tone={tone[status] || 'neutral' as any} />;
}

/**
 * Kullanıcı isteği: "admin paneline url adresleri ekleyip AI teknik
 * asistan sadece dokümana değil, bu URL linkine de baksın" — bir web
 * sayfası eklenince backend onu indirip AYNI bilgi bankasına (chunk +
 * embed) katıyor, AI'nin dokümanlara baktığı yerde otomatik olarak
 * bu içeriğe de bakması sağlanıyor.
 */
function UrlLinkForm({ onAdded }: { onAdded: () => void }) {
  const [form, setForm] = useState({ url: '', brand: '', model: '', title: '', version: 'V1', isDatasheet: false });
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setMessage(null);
    try {
      await api.post('/documents/from-url', form);
      setMessage({ type: 'success', text: 'Link eklendi, içerik işleniyor — birkaç dakika içinde bilgi bankasında hazır olacak.' });
      setForm({ url: '', brand: '', model: '', title: '', version: 'V1', isDatasheet: false });
      onAdded();
    } catch (err: any) {
      setMessage({ type: 'error', text: err.response?.data?.message || 'Link eklenemedi.' });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="admin-surface p-6 mb-8 space-y-4">
      <div>
        <p className="text-[13.5px] font-semibold text-slate-800">Web Linki Ekle</p>
        <p className="text-xs text-gray-400 mt-0.5">
          Bir ürün sayfası, teknik döküman linki ya da destek makalesi ekleyin — AI, dokümanlarla birlikte bu sayfanın
          içeriğine de bakarak cevap verecek.
        </p>
      </div>
      <Input label="URL" value={form.url} onChange={(v) => setForm({ ...form, url: v })} placeholder="https://ornek.com/urun-sayfasi" />
      <div className="grid grid-cols-3 gap-4">
        <Input label="Marka" value={form.brand} onChange={(v) => setForm({ ...form, brand: v })} placeholder="Honeywell" />
        <Input label="Model" value={form.model} onChange={(v) => setForm({ ...form, model: v })} placeholder="MA8000" />
        <Input label="Versiyon" value={form.version} onChange={(v) => setForm({ ...form, version: v })} placeholder="V1" />
      </div>
      <Input label="Başlık" value={form.title} onChange={(v) => setForm({ ...form, title: v })} placeholder="Ürün Sayfası — MA8000" />
      <label className="flex items-center gap-2 cursor-pointer">
        <input
          type="checkbox"
          checked={form.isDatasheet}
          onChange={(e) => setForm({ ...form, isDatasheet: e.target.checked })}
          className="w-4 h-4"
        />
        <span className="text-sm text-gray-700">Bu resmi bir datasheet / teknik döküman (AI cevap üretirken öncelikli kullanılır)</span>
      </label>
      {message && (
        <p className={`text-xs ${message.type === 'success' ? 'text-green-700' : 'text-red-600'}`}>{message.text}</p>
      )}
      <button
        type="submit"
        disabled={submitting || !form.url || !form.brand || !form.model || !form.title}
        className="bg-[var(--admin-navy)] text-white rounded-xl px-4 h-10 font-semibold hover:bg-slate-800 transition disabled:opacity-60 text-sm"
      >
        {submitting ? 'Ekleniyor...' : 'Linki Ekle'}
      </button>
    </form>
  );
}
