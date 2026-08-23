'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const statusLabels: Record<string, string> = {
  DRAFT: 'Taslak',
  SENT: 'Gönderildi',
  ACCEPTED: 'Kabul Edildi',
  REJECTED: 'Reddedildi',
};

export default function QuotesPage() {
  const { data: priceItems, mutate: mutatePriceItems } = useSWR('/quotes/price-list', fetcher);
  const { data: quotes, mutate: mutateQuotes } = useSWR('/quotes/all', fetcher);
  const [showForm, setShowForm] = useState(false);
  const [showBulkImport, setShowBulkImport] = useState(false);
  const [bulkText, setBulkText] = useState('');
  const [importing, setImporting] = useState(false);
  const [importResult, setImportResult] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [brand, setBrand] = useState('');
  const [code, setCode] = useState('');
  const [category, setCategory] = useState('');
  const [unit, setUnit] = useState('adet');
  const [unitPrice, setUnitPrice] = useState('');
  const [uploading, setUploading] = useState(false);

  async function addPriceItem(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim() || !unitPrice) return;
    await api.post('/quotes/price-list', {
      name: name.trim(),
      brand: brand.trim(),
      code: code.trim(),
      category: category.trim(),
      unit: unit.trim(),
      unitPrice: Number(unitPrice),
    });
    setName('');
    setBrand('');
    setCode('');
    setCategory('');
    setUnitPrice('');
    mutatePriceItems();
  }

  async function deletePriceItem(id: string) {
    if (!confirm('Bu kalemi fiyat listesinden silmek istediğinize emin misiniz?')) return;
    await api.delete(`/quotes/price-list/${id}`);
    mutatePriceItems();
  }

  async function runBulkImport() {
    if (!bulkText.trim()) return;
    setImporting(true);
    setImportResult(null);
    try {
      const res = await api.post('/quotes/price-list/bulk-import', { rawText: bulkText });
      setImportResult(res.data.imported ? `${res.data.imported} ürün başarıyla eklendi.` : res.data.message || 'Hiçbir ürün eklenemedi.');
      setBulkText('');
      mutatePriceItems();
    } finally {
      setImporting(false);
    }
  }

  async function clearAllPriceItems() {
    if (!confirm('TÜM fiyat listesi silinecek. Bu işlem geri alınamaz. Emin misiniz?')) return;
    await api.delete('/quotes/price-list');
    mutatePriceItems();
  }

  async function uploadPriceListPdf(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const formData = new FormData();
      formData.append('file', file);
      await api.post('/quotes/price-list-document', formData);
    } finally {
      setUploading(false);
    }
  }

  return (
    <div>
      <p className="text-sm text-gray-500 mb-6">
        Bayilerin &quot;Teklif Al&quot; ekranında kullandığı fiyat/malzeme kataloğunu ve referans fiyat listesi PDF&apos;ini buradan yönetin.
      </p>

      <div className="bg-white rounded-2xl border border-gray-100 p-6 mb-8 max-w-2xl">
        <h3 className="text-sm font-bold text-gray-700 mb-1">Excel&apos;den Toplu İçe Aktar</h3>
        <p className="text-xs text-gray-400 mb-3">
          Excel dosyanızdaki tabloyu (Seri / Ürün Kodu / Açıklama / Adet / Fiyat sütunlarıyla) seçip kopyalayın (Ctrl+C), aşağıya yapıştırın.
        </p>
        <button
          onClick={() => setShowBulkImport((v) => !v)}
          className="text-sm font-medium text-navy border border-gray-200 px-4 py-2 rounded-xl hover:bg-gray-50 transition mb-3"
        >
          {showBulkImport ? 'Kapat' : 'Yapıştırma Alanını Aç'}
        </button>
        {showBulkImport && (
          <div>
            <textarea
              value={bulkText}
              onChange={(e) => setBulkText(e.target.value)}
              placeholder="Excel'den kopyaladığınız tabloyu buraya yapıştırın (Ctrl+V)..."
              rows={8}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-xs font-mono mb-3"
            />
            <div className="flex items-center gap-3">
              <button
                onClick={runBulkImport}
                disabled={importing || !bulkText.trim()}
                className="text-sm font-medium text-white bg-brand px-4 py-2 rounded-lg hover:bg-brand-dark transition disabled:opacity-50"
              >
                {importing ? 'İçe Aktarılıyor...' : 'İçe Aktar'}
              </button>
              {importResult && <p className="text-xs text-gray-500">{importResult}</p>}
            </div>
          </div>
        )}
      </div>

      <div className="bg-white rounded-2xl border border-gray-100 p-6 mb-8 max-w-xl">
        <h3 className="text-sm font-bold text-gray-700 mb-3">Referans Fiyat Listesi PDF</h3>
        <p className="text-xs text-gray-400 mb-3">Bayilerin &quot;Teklif Al&quot; ekranından görüntüleyebileceği tam fiyat listesi dokümanı.</p>
        <label className="inline-block text-sm font-medium text-white bg-navy px-4 py-2 rounded-xl hover:bg-navy-light transition cursor-pointer">
          {uploading ? 'Yükleniyor...' : 'PDF Yükle / Güncelle'}
          <input type="file" accept="application/pdf" onChange={uploadPriceListPdf} className="hidden" disabled={uploading} />
        </label>
      </div>

      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-bold text-gray-700">Fiyat/Malzeme Kataloğu ({priceItems?.length ?? 0} kalem)</h3>
        <div className="flex gap-2">
          {priceItems?.length > 0 && (
            <button onClick={clearAllPriceItems} className="text-sm font-medium text-red-600 border border-red-200 px-4 py-2 rounded-xl hover:bg-red-50 transition">
              Tümünü Sil
            </button>
          )}
          <button onClick={() => setShowForm((v) => !v)} className="text-sm font-medium text-navy border border-gray-200 px-4 py-2 rounded-xl hover:bg-gray-50 transition">
            {showForm ? 'Kapat' : '+ Tek Tek Ekle'}
          </button>
        </div>
      </div>

      {showForm && (
        <form onSubmit={addPriceItem} className="bg-white rounded-2xl border border-gray-100 p-6 mb-6 flex items-end gap-2 flex-wrap">
          <div className="w-32">
            <label className="block text-xs text-gray-400 mb-1">Marka</label>
            <input value={brand} onChange={(e) => setBrand(e.target.value)} className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" placeholder="Honeywell" />
          </div>
          <div className="w-28">
            <label className="block text-xs text-gray-400 mb-1">Ürün Kodu</label>
            <input value={code} onChange={(e) => setCode(e.target.value)} className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" placeholder="PL-1000" />
          </div>
          <div className="flex-1 min-w-[160px]">
            <label className="block text-xs text-gray-400 mb-1">Açıklama</label>
            <input value={name} onChange={(e) => setName(e.target.value)} className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" placeholder="Örn: Duman Dedektörü" />
          </div>
          <div className="w-32">
            <label className="block text-xs text-gray-400 mb-1">Kategori</label>
            <input value={category} onChange={(e) => setCategory(e.target.value)} className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" placeholder="Dedektör" />
          </div>
          <div className="w-20">
            <label className="block text-xs text-gray-400 mb-1">Birim</label>
            <input value={unit} onChange={(e) => setUnit(e.target.value)} className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" />
          </div>
          <div className="w-28">
            <label className="block text-xs text-gray-400 mb-1">Fiyat (€)</label>
            <input type="number" value={unitPrice} onChange={(e) => setUnitPrice(e.target.value)} className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" />
          </div>
          <button type="submit" className="text-sm font-medium text-white bg-brand px-4 py-2 rounded-lg hover:bg-brand-dark transition shrink-0">
            Ekle
          </button>
        </form>
      )}

      <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden mb-8 max-h-[500px] overflow-y-auto">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-left sticky top-0">
            <tr>
              <th className="px-4 py-3">Marka</th>
              <th className="px-4 py-3">Kod</th>
              <th className="px-4 py-3">Açıklama</th>
              <th className="px-4 py-3">Kategori</th>
              <th className="px-4 py-3">Fiyat</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {priceItems?.map((p: any) => (
              <tr key={p.id} className="border-t border-gray-100">
                <td className="px-4 py-3 text-gray-500">{p.brand || '—'}</td>
                <td className="px-4 py-3 text-gray-500 font-mono text-xs">{p.code || '—'}</td>
                <td className="px-4 py-3 font-medium max-w-xs truncate">{p.name}</td>
                <td className="px-4 py-3 text-gray-400 text-xs">{p.category || '—'}</td>
                <td className="px-4 py-3 font-bold">{p.unitPrice} €</td>
                <td className="px-4 py-3 text-right">
                  <button onClick={() => deletePriceItem(p.id)} className="text-red-700 hover:underline text-xs">
                    Sil
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!priceItems || priceItems.length === 0) && <p className="p-6 text-center text-gray-400">Henüz fiyat listesi kalemi eklenmedi.</p>}
      </div>

      <h3 className="text-sm font-bold text-gray-700 mb-4">Bayilerin Oluşturduğu Teklifler</h3>
      <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th className="px-4 py-3">Bayi</th>
              <th className="px-4 py-3">Müşteri</th>
              <th className="px-4 py-3">Başlık</th>
              <th className="px-4 py-3">Tutar</th>
              <th className="px-4 py-3">Durum</th>
              <th className="px-4 py-3">Tarih</th>
            </tr>
          </thead>
          <tbody>
            {quotes?.map((q: any) => (
              <tr key={q.id} className="border-t border-gray-100">
                <td className="px-4 py-3">{q.dealer?.firstName} {q.dealer?.lastName} <span className="text-gray-400">({q.dealer?.company})</span></td>
                <td className="px-4 py-3">{q.customerName || '—'}</td>
                <td className="px-4 py-3">{q.title}</td>
                <td className="px-4 py-3 font-bold">{q.totalAmount} ₺</td>
                <td className="px-4 py-3">
                  <select
                    value={q.status}
                    onChange={async (e) => {
                      await api.put(`/quotes/${q.id}/status`, { status: e.target.value });
                      mutateQuotes();
                    }}
                    className="border border-gray-200 rounded-lg px-2 py-1 text-xs"
                  >
                    {Object.entries(statusLabels).map(([k, v]) => (
                      <option key={k} value={k}>{v}</option>
                    ))}
                  </select>
                </td>
                <td className="px-4 py-3 text-gray-400">{new Date(q.createdAt).toLocaleDateString('tr-TR')}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!quotes || quotes.length === 0) && <p className="p-6 text-center text-gray-400">Henüz oluşturulmuş bir teklif yok.</p>}
      </div>
    </div>
  );
}
