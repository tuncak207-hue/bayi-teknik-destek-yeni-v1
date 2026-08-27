'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { PillButton } from '@/components/ui';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function SalesConsultantsPage() {
  const { data: consultants, mutate } = useSWR('/users/sales-consultants', fetcher);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ firstName: '', lastName: '', email: '', phone: '', password: '' });
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [selected, setSelected] = useState<any>(null);
  const [editing, setEditing] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setSubmitting(true);
    try {
      await api.post('/users/sales-consultants', form);
      setForm({ firstName: '', lastName: '', email: '', phone: '', password: '' });
      setShowForm(false);
      mutate();
    } catch (err: any) {
      setError(err.response?.data?.message || 'Danışman eklenemedi.');
    } finally {
      setSubmitting(false);
    }
  }

  async function remove(id: string) {
    if (!confirm('Bu satış danışmanı hesabını silmek istediğinize emin misiniz?')) return;
    await api.delete(`/users/sales-consultants/${id}`);
    mutate();
    setSelected(null);
  }

  async function saveEdit(fields: { firstName: string; lastName: string; phone: string }) {
    await api.patch(`/users/${selected.id}`, fields);
    mutate();
    setSelected((s: any) => ({ ...s, ...fields }));
    setEditing(false);
  }

  return (
    <div className="admin-page">
      <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between mb-7">
        <div><p className="admin-eyebrow">KULLANICI / SATIŞ</p><h2 className="admin-page-title">Satış Danışmanları</h2><p className="admin-page-subtitle">Bayilerin doğrudan iletişim kurabileceği satış danışmanı hesaplarını yönetin.</p></div>
      <div className="flex items-center justify-end mb-1">
        <PillButton onClick={() => setShowForm((v) => !v)} variant="primary">
          {showForm ? 'Vazgeç' : '+ Danışman Ekle'}
        </PillButton>
      </div>
      </div>
      <p className="text-sm text-gray-500 mb-6">
        Bayilerin mobil uygulamada &quot;Satış Danışmanına Sor&quot; ile doğrudan mesaj gönderebileceği hesaplar. Bir karta tıklayarak düzenleyebilir veya silebilirsiniz.
      </p>

      {showForm && (
        <form onSubmit={submit}         className="admin-surface p-6 mb-6 max-w-lg"
>
          {error && <p className="text-sm text-red-600 mb-4">{error}</p>}
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1.5">Ad</label>
              <input value={form.firstName} onChange={(e) => setForm({ ...form, firstName: e.target.value })} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" required />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1.5">Soyad</label>
              <input value={form.lastName} onChange={(e) => setForm({ ...form, lastName: e.target.value })} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" required />
            </div>
          </div>
          <div className="mb-4">
            <label className="block text-xs font-medium text-gray-500 mb-1.5">E-posta</label>
            <input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" required />
          </div>
          <div className="mb-4">
            <label className="block text-xs font-medium text-gray-500 mb-1.5">Telefon</label>
            <input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" required />
          </div>
          <div className="mb-5">
            <label className="block text-xs font-medium text-gray-500 mb-1.5">Şifre</label>
            <input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" required minLength={8} />
          </div>
          <PillButton type="submit" variant="primary" disabled={submitting}>
            {submitting ? 'Ekleniyor...' : 'Danışmanı Ekle'}
          </PillButton>
        </form>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {consultants?.map((c: any) => (
          <button
            key={c.id}
            onClick={() => {
              setSelected(c);
              setEditing(false);
            }}
            className="text-left bg-white rounded-2xl border border-slate-200/80 shadow-[0_10px_30px_rgba(15,23,42,0.035)] p-5 hover:border-blue-200 hover:shadow-[0_14px_30px_rgba(30,64,175,0.10)] hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500/30 transition-all"
          >
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center text-white font-bold text-sm mb-3 shadow-[0_1px_2px_rgba(15,23,42,0.04)]">
              {c.firstName?.[0]?.toUpperCase()}{c.lastName?.[0]?.toUpperCase()}
            </div>
            <p className="text-sm font-bold text-navy truncate">{c.firstName} {c.lastName}</p>
            <p className="text-xs text-gray-500 mt-1 truncate">{c.email}</p>
            <p className="text-xs text-gray-400 mt-0.5 truncate">{c.phone}</p>
          </button>
        ))}
      </div>
      {consultants?.length === 0 && <p className="text-center text-gray-400 py-16">Henüz satış danışmanı eklenmedi.</p>}

      {selected && (
        <div className="fixed inset-0 bg-slate-950/45 backdrop-blur-[2px] flex items-center justify-center z-50 p-4" onClick={() => setSelected(null)}>
          <div className="bg-white rounded-2xl w-full max-w-md overflow-hidden shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="h-1.5 bg-brand" />
            <div className="p-6">
              {editing ? (
                <EditConsultantForm consultant={selected} onCancel={() => setEditing(false)} onSave={saveEdit} />
              ) : (
                <>
                  <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center text-white font-bold text-base mb-4 shadow-[0_1px_2px_rgba(15,23,42,0.04)]">
                    {selected.firstName?.[0]?.toUpperCase()}{selected.lastName?.[0]?.toUpperCase()}
                  </div>
                  <h3 className="text-base font-bold text-navy">{selected.firstName} {selected.lastName}</h3>
                  <div className="mt-4 space-y-2 text-sm">
                    <DetailRow label="E-posta" value={selected.email} />
                    <DetailRow label="Telefon" value={selected.phone || '—'} />
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

function EditConsultantForm({
  consultant,
  onCancel,
  onSave,
}: {
  consultant: any;
  onCancel: () => void;
  onSave: (fields: { firstName: string; lastName: string; phone: string }) => void;
}) {
  const [firstName, setFirstName] = useState(consultant.firstName || '');
  const [lastName, setLastName] = useState(consultant.lastName || '');
  const [phone, setPhone] = useState(consultant.phone || '');

  return (
    <div>
      <h3 className="text-sm font-bold text-navy mb-4">Danışman Bilgilerini Düzenle</h3>
      <div className="space-y-3">
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
          onClick={() => onSave({ firstName, lastName, phone })}
          className="flex-1 text-sm font-medium text-white bg-brand rounded-xl py-2.5 hover:bg-brand-dark transition"
        >
          Kaydet
        </button>
      </div>
    </div>
  );
}
