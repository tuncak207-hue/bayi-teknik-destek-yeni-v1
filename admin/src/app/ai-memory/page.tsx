'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Badge, IconBadge, LoadingState, EmptyState, ErrorState } from '@/components/ui';
import { IconBrain } from '@/components/icons';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function AiMemoryPage() {
  const [productFilter, setProductFilter] = useState('');
  const [onlyNeedsReview, setOnlyNeedsReview] = useState(false);
  const queryParams = new URLSearchParams({
    ...(productFilter && { productName: productFilter }),
    ...(onlyNeedsReview && { needsReverification: 'true' }),
  }).toString();
  const { data: entries, error, isLoading, mutate } = useSWR(`/ai/technical-memory?${queryParams}`, fetcher);

  const [selected, setSelected] = useState<any>(null);

  async function verify(id: string) {
    await api.patch(`/ai/technical-memory/${id}/verify`);
    mutate();
    setSelected(null);
  }

  async function setActive(id: string, isActive: boolean) {
    await api.patch(`/ai/technical-memory/${id}/active`, { isActive });
    mutate();
    setSelected((s: any) => (s?.id === id ? { ...s, isActive } : s));
  }

  async function saveEdit(id: string, answerMarkdown: string) {
    await api.patch(`/ai/technical-memory/${id}`, { answerMarkdown });
    mutate();
    setSelected(null);
  }

  return (
    <div>
      <p className="text-[13px] text-gray-400 mb-4 max-w-2xl">
        AI, benzer bir teknik soru daha önce sorulup güvenilir bir cevap oluşturulduysa dokümanları yeniden taramak yerine
        buradaki kayıtlı cevapları kullanır. Bir kaydı <strong>doğrulanmış</strong> olarak işaretlemeden, AI o cevabı
        otomatik/kesin olarak tekrar kullanmaz.
      </p>

      <div className="bg-white rounded-xl border border-gray-200/70 p-3 mb-4 flex flex-wrap gap-2 items-center">
        <input
          value={productFilter}
          onChange={(e) => setProductFilter(e.target.value)}
          placeholder="Ürün adına göre filtrele..."
          className="h-8 flex-1 min-w-[200px] bg-gray-50 border border-gray-200/70 rounded-lg px-3 text-[12.5px] focus:outline-none focus:ring-2 focus:ring-gray-200"
        />
        <label className="flex items-center gap-1.5 text-[12.5px] text-gray-600 h-8 px-2">
          <input type="checkbox" checked={onlyNeedsReview} onChange={(e) => setOnlyNeedsReview(e.target.checked)} />
          Sadece yeniden doğrulama gerekenler
        </label>
      </div>

      {isLoading && <LoadingState />}
      {error && <ErrorState onRetry={() => mutate()} />}
      {!isLoading && !error && entries?.length === 0 && (
        <EmptyState
          title="Henüz kayıtlı cevap yok"
          description="Bayiler AI'a teknik sorular sordukça, güvenilir cevaplar burada otomatik birikmeye başlayacak."
        />
      )}

      {!isLoading && entries?.length > 0 && (
        <div className="space-y-2">
          {entries.map((e: any) => {
            const isVerified = !!e.lastVerifiedAt && !e.needsReverification;
            return (
              <button
                key={e.id}
                onClick={() => setSelected(e)}
                className={`w-full text-left bg-white rounded-xl border p-4 hover:shadow-[0_1px_2px_rgba(15,23,42,0.04)] transition-all flex items-center gap-3 ${
                  e.needsReverification ? 'border-amber-200' : 'border-gray-200/70'
                } ${!e.isActive ? 'opacity-50' : ''}`}
              >
                <IconBadge icon={<IconBrain width={16} height={16} />} color={isVerified ? 'emerald' : e.needsReverification ? 'amber' : 'blue'} size="md" />
                <div className="flex-1 min-w-0 grid grid-cols-1 sm:grid-cols-4 gap-2 items-center">
                  <div className="min-w-0 sm:col-span-2">
                    <p className="text-[13px] font-semibold text-gray-900 truncate">{e.question}</p>
                    <p className="text-[11.5px] text-gray-400 mt-0.5 truncate">
                      {e.productName || 'Ürün belirtilmedi'} {e.productModel ? `/ ${e.productModel}` : ''}
                    </p>
                  </div>
                  <div className="text-[12px] text-gray-500">{e.usageCount} kez kullanıldı</div>
                  <div className="flex items-center gap-1.5 justify-start sm:justify-end flex-wrap">
                    {e.needsReverification ? (
                      <Badge label="Yeniden Doğrulama Gerekli" tone="pending" />
                    ) : isVerified ? (
                      <Badge label="🟢 Doğrulanmış" tone="success" />
                    ) : (
                      <Badge label="🔴 Doğrulanmamış" tone="neutral" />
                    )}
                    {!e.isActive && <Badge label="Pasif" tone="danger" />}
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      )}

      {selected && (
        <MemoryDetailDrawer
          entry={selected}
          onClose={() => setSelected(null)}
          onVerify={() => verify(selected.id)}
          onToggleActive={() => setActive(selected.id, !selected.isActive)}
          onSaveEdit={(text) => saveEdit(selected.id, text)}
        />
      )}
    </div>
  );
}

function MemoryDetailDrawer({
  entry,
  onClose,
  onVerify,
  onToggleActive,
  onSaveEdit,
}: {
  entry: any;
  onClose: () => void;
  onVerify: () => void;
  onToggleActive: () => void;
  onSaveEdit: (text: string) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [text, setText] = useState(entry.answerMarkdown);
  const isVerified = !!entry.lastVerifiedAt && !entry.needsReverification;
  const citations = Array.isArray(entry.citations) ? entry.citations : [];

  return (
    <div className="fixed inset-0 bg-black/30 flex justify-end z-50" onClick={onClose}>
      <div className="bg-white w-full max-w-lg h-full overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between mb-1">
          <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide">Teknik Hafıza Kaydı</p>
          <button onClick={onClose} className="text-gray-300 hover:text-gray-600">✕</button>
        </div>
        <h2 className="text-base font-bold text-gray-900">{entry.question}</h2>
        <div className="flex items-center gap-2 mt-2 flex-wrap">
          {entry.needsReverification ? (
            <Badge label="Yeniden Doğrulama Gerekli" tone="pending" />
          ) : isVerified ? (
            <Badge label="🟢 Doğrulanmış" tone="success" />
          ) : (
            <Badge label="🔴 Doğrulanmamış" tone="neutral" />
          )}
          <span className="text-[12px] text-gray-400">{entry.usageCount} kez kullanıldı</span>
        </div>

        {(entry.productName || entry.productModel) && (
          <div className="mt-4 pt-4 border-t border-gray-100">
            <h3 className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-2">Ürün Bilgisi</h3>
            <p className="text-[12.5px] text-gray-700">{entry.productName} {entry.productModel && `/ ${entry.productModel}`}</p>
          </div>
        )}

        <div className="mt-4 pt-4 border-t border-gray-100">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide">Cevap</h3>
            {!editing && (
              <button onClick={() => setEditing(true)} className="text-[12px] text-navy hover:underline font-medium">
                Düzenle
              </button>
            )}
          </div>
          {editing ? (
            <div>
              <textarea
                value={text}
                onChange={(e) => setText(e.target.value)}
                rows={10}
                className="w-full border border-gray-200 rounded-lg px-3 py-2 text-[12.5px] font-mono"
              />
              <p className="text-[11px] text-amber-600 mt-1.5">Not: Cevabı düzenlemek doğrulama durumunu sıfırlar, tekrar doğrulamanız gerekir.</p>
              <div className="flex gap-2 mt-3">
                <button onClick={() => setEditing(false)} className="flex-1 text-sm font-medium text-gray-600 border border-gray-200 rounded-xl py-2 hover:bg-gray-50 transition">
                  Vazgeç
                </button>
                <button
                  onClick={() => {
                    onSaveEdit(text);
                    setEditing(false);
                  }}
                  className="flex-1 text-sm font-medium text-white bg-brand rounded-xl py-2 hover:bg-brand-dark transition"
                >
                  Kaydet
                </button>
              </div>
            </div>
          ) : (
            <p className="text-[12.5px] text-gray-700 leading-relaxed whitespace-pre-wrap">{entry.answerMarkdown}</p>
          )}
        </div>

        {citations.length > 0 && (
          <div className="mt-4 pt-4 border-t border-gray-100">
            <h3 className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-2">Kaynak Dokümanlar</h3>
            <div className="space-y-1.5">
              {citations.map((c: any, i: number) => (
                <div key={i} className="text-[12px] text-gray-600">
                  📄 {c.documentTitle} (v{c.version}) — Sayfa {c.page}
                </div>
              ))}
            </div>
          </div>
        )}

        {!editing && (
          <div className="flex flex-wrap gap-2 mt-6">
            {!isVerified && (
              <button onClick={onVerify} className="text-sm font-medium text-white bg-emerald-600 rounded-xl px-4 py-2 hover:bg-emerald-700 transition">
                Doğrulanmış Olarak İşaretle
              </button>
            )}
            <button onClick={onToggleActive} className="text-sm font-medium text-gray-700 border border-gray-200 rounded-xl px-4 py-2 hover:bg-gray-50 transition">
              {entry.isActive ? 'Pasifleştir' : 'Aktifleştir'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
