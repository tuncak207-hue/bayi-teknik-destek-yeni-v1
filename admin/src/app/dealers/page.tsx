'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Badge } from '@/components/ui';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const statusTone: Record<string, 'pending' | 'success' | 'neutral'> = {
  PENDING: 'pending',
  ACTIVE: 'success',
  SUSPENDED: 'neutral',
};

const statusLabel: Record<string, string> = {
  PENDING: 'Onay Bekliyor',
  ACTIVE: 'Aktif',
  SUSPENDED: 'Pasif',
};

export default function DealersPage() {
  const { data: dealers, mutate } = useSWR('/users', fetcher);
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<any>(null);
  const [editing, setEditing] = useState(false);

  async function approve(id: string) {
    await api.patch(`/users/${id}/approve`);
    mutate();
    if (selected?.id === id) setSelected((s: any) => ({ ...s, status: 'ACTIVE' }));
  }
  async function suspend(id: string) {
    await api.patch(`/users/${id}/suspend`);
    mutate();
    if (selected?.id === id) setSelected((s: any) => ({ ...s, status: 'SUSPENDED' }));
  }
  async function remove(id: string) {
    if (!confirm('Bu bayiyi kalıcı olarak silmek istediğinize emin misiniz?')) return;
    await api.delete(`/users/${id}`);
    mutate();
    setSelected(null);
  }
  async function saveEdit(fields: { firstName: string; lastName: string; company: string; phone: string }) {
    await api.patch(`/users/${selected.id}`, fields);
    mutate();
    setSelected((s: any) => ({ ...s, ...fields }));
    setEditing(false);
  }

  const filtered = dealers?.filter((d: any) => {
    const q = search.trim().toLowerCase();
    if (!q) return true;
    return (
      d.company?.toLowerCase().includes(q) ||
      d.firstName?.toLowerCase().includes(q) ||
      d.lastName?.toLowerCase().includes(q) ||
      d.email?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="admin-page">
      <div className="mb-6"><p className="admin-eyebrow">BAYİ AĞI</p><h2 className="admin-page-title">Bayiler</h2><p className="admin-page-subtitle">Bayi kartını açarak detayları görüntüleyebilir, düzenleyebilir veya durumunu güncelleyebilirsiniz.</p></div>
      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Firma, isim veya e-posta ile ara..."
        aria-label="Bayi ara"
        className="w-full max-w-sm h-11 border border-slate-200 bg-white rounded-xl px-3.5 text-sm mb-6 shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition"
      />

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered?.map((d: any) => (
          <button
            key={d.id}
            onClick={() => {
              setSelected(d);
              setEditing(false);
            }}
            className="text-left bg-white rounded-2xl border border-slate-200/80 shadow-[0_10px_30px_rgba(15,23,42,0.035)] p-5 hover:border-blue-200 hover:shadow-[0_14px_30px_rgba(30,64,175,0.10)] hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500/30 transition-all"
          >
            <div className="flex items-start justify-between mb-3">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center text-white font-bold text-sm shrink-0 shadow-[0_1px_2px_rgba(15,23,42,0.04)]">
                {d.company?.[0]?.toUpperCase() || '?'}
              </div>
              <Badge label={statusLabel[d.status] || d.status} tone={statusTone[d.status] || 'neutral'} />
            </div>
            <p className="text-sm font-bold text-navy truncate">{d.company}</p>
            <p className="text-xs text-gray-500 mt-1 truncate">{d.firstName} {d.lastName}</p>
            <p className="text-xs text-gray-400 mt-0.5 truncate">{d.email}</p>
          </button>
        ))}
      </div>

      {filtered?.length === 0 && (
        <p className="text-center text-gray-400 py-16">{dealers?.length === 0 ? 'Henüz bayi yok.' : 'Aramayla eşleşen bayi yok.'}</p>
      )}

      {selected && (
                    <div className="fixed inset-0 bg-slate-950/45 backdrop-blur-[2px] flex items-center justify-center z-50 p-4" onClick={() => setSelected(null)}>
              <div className="bg-white rounded-2xl w-full max-w-md overflow-hidden shadow-2xl" onClick={(e) => e.stopPropagation()}>

            <div className="h-1.5 bg-brand" />
            <div className="p-6">
              {editing ? (
                <EditDealerForm dealer={selected} onCancel={() => setEditing(false)} onSave={saveEdit} />
              ) : (
                <>
                  <div className="flex items-start justify-between mb-4">
                    <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center text-white font-bold text-base shrink-0 shadow-[0_1px_2px_rgba(15,23,42,0.04)]">
                      {selected.company?.[0]?.toUpperCase() || '?'}
                    </div>
                    <Badge label={statusLabel[selected.status] || selected.status} tone={statusTone[selected.status] || 'neutral'} />
                  </div>
                  <h3 className="text-base font-bold text-navy">{selected.company}</h3>
                  <p className="text-sm text-gray-500 mt-0.5">{selected.firstName} {selected.lastName}</p>
                  <div className="mt-4 space-y-2 text-sm">
                    <DetailRow label="E-posta" value={selected.email} />
                    <DetailRow label="Telefon" value={selected.phone || '—'} />
                    <DetailRow label="Kayıt Tarihi" value={selected.createdAt ? new Date(selected.createdAt).toLocaleDateString('tr-TR') : '—'} />
                  </div>

                  <div className="flex flex-wrap gap-2 mt-6">
                    {selected.status === 'PENDING' && (
                      <button onClick={() => approve(selected.id)} className="text-sm font-medium text-white bg-emerald-600 rounded-xl px-4 py-2 hover:bg-emerald-700 transition">
                        Onayla
                      </button>
                    )}
                    {selected.status === 'ACTIVE' && (
                      <button onClick={() => suspend(selected.id)} className="text-sm font-medium text-white bg-amber-500 rounded-xl px-4 py-2 hover:bg-amber-600 transition">
                        Pasifleştir
                      </button>
                    )}
                    {selected.status === 'SUSPENDED' && (
                      <button onClick={() => approve(selected.id)} className="text-sm font-medium text-white bg-emerald-600 rounded-xl px-4 py-2 hover:bg-emerald-700 transition">
                        Aktifleştir
                      </button>
                    )}
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

function EditDealerForm({
  dealer,
  onCancel,
  onSave,
}: {
  dealer: any;
  onCancel: () => void;
  onSave: (fields: { firstName: string; lastName: string; company: string; phone: string }) => void;
}) {
  const [firstName, setFirstName] = useState(dealer.firstName || '');
  const [lastName, setLastName] = useState(dealer.lastName || '');
  const [company, setCompany] = useState(dealer.company || '');
  const [phone, setPhone] = useState(dealer.phone || '');

  return (
    <div>
      <h3 className="text-sm font-bold text-navy mb-4">Bayi Bilgilerini Düzenle</h3>
      <div className="space-y-3">
        <div>
          <label className="block text-xs text-gray-400 mb-1">Firma</label>
          <input value={company} onChange={(e) => setCompany(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
        </div>
        <div className="grid grid-cols-2 gap-2">
          <div>
            <label className="block text-xs text-gray-400 mb-1">Ad</label>
            <input value={firstName} onChange={(e) => setFirstName(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-gray-400 mb-1">Soyad</label>
            <input value={lastName} onChange={(e) => setLastName(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          </div>
        </div>
        <div>
          <label className="block text-xs text-gray-400 mb-1">Telefon</label>
          <input value={phone} onChange={(e) => setPhone(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
        </div>
      </div>
      <div className="flex gap-2 mt-5">
        <button onClick={onCancel} className="flex-1 text-sm font-medium text-gray-600 border border-gray-200 rounded-xl py-2.5 hover:bg-gray-50 transition">
          Vazgeç
        </button>
        <button
          onClick={() => onSave({ firstName, lastName, company, phone })}
          className="flex-1 text-sm font-medium text-white bg-brand rounded-xl py-2.5 hover:bg-brand-dark transition"
        >
          Kaydet
        </button>
      </div>
    </div>
  );
}
