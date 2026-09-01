'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function AnnouncementsPage() {
  const { data: announcements, mutate } = useSWR('/announcements', fetcher, { refreshInterval: 5000 });
  const [form, setForm] = useState({ title: '', body: '', isCritical: false });
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const { data: readStatus } = useSWR(
    expandedId ? `/announcements/${expandedId}/read-status` : null,
    fetcher,
  );

  async function create(e: React.FormEvent) {
    e.preventDefault();
    if (!form.title.trim() || !form.body.trim()) return;
    await api.post('/announcements', form);
    setForm({ title: '', body: '', isCritical: false });
    mutate();
  }

  async function remove(id: string) {
    if (!confirm('Bu duyuruyu silmek istediğinize emin misiniz?')) return;
    await api.delete(`/announcements/${id}`);
    mutate();
  }

  async function edit(a: any) {
    const newTitle = prompt('Başlık:', a.title);
    if (newTitle === null) return;
    const newBody = prompt('İçerik:', a.body);
    if (newBody === null) return;
    await api.patch(`/announcements/${a.id}`, { title: newTitle, body: newBody });
    mutate();
  }

  return (
    <div className="admin-page">
      <div className="mb-7"><p className="admin-eyebrow">İLETİŞİM / YAYIN</p><h2 className="admin-page-title">Duyurular</h2><p className="admin-page-subtitle">Bayi iletişimini yönetin, kritik bilgilendirmelerin okuma durumunu takip edin.</p></div>
      <form onSubmit={create} className="admin-surface p-6 mb-8 space-y-4">
        <input
          value={form.title}
          onChange={(e) => setForm({ ...form, title: e.target.value })}
          placeholder="Başlık"
          aria-label="Duyuru başlığı"
          className="w-full h-11 border border-slate-200 bg-slate-50 rounded-xl px-3.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-300"
        />
        <textarea
          value={form.body}
          onChange={(e) => setForm({ ...form, body: e.target.value })}
          placeholder="Duyuru içeriği"
          aria-label="Duyuru içeriği"
          rows={4}
          className="w-full border border-slate-200 bg-slate-50 rounded-xl px-3.5 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-300"
        />
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.isCritical}
            onChange={(e) => setForm({ ...form, isCritical: e.target.checked })}
          />
          <span>
            <strong>Kritik duyuru</strong> — bayiler uygulamayı açtığında kapatılamayan bir onay
            ekranı görür, &quot;Okudum, Anladım&quot; demeden geçemez.
          </span>
        </label>
        <button className="bg-[var(--admin-navy)] text-white rounded-xl px-4 h-10 font-semibold hover:bg-slate-800 transition">
          Duyuru Yayınla (tüm bayilere push gider)
        </button>
      </form>

      <div className="space-y-3">
        {announcements?.map((a: any) => (
          <div key={a.id} className={`bg-white rounded-2xl border p-5 shadow-sm ${a.isCritical ? 'border-blue-400 shadow-blue-100/50' : 'border-slate-200/80'}`}>
            <div className="flex justify-between">
              <div>
                <p className="font-medium flex items-center gap-2">
                  {a.isCritical && <span className="text-brand">⚠️</span>}
                  {a.title}
                </p>
                <p className="text-sm text-gray-600 mt-1">{a.body}</p>
              </div>
              <div className="flex flex-col items-end gap-2 shrink-0 ml-4">
                <button onClick={() => edit(a)} className="text-gray-700 hover:underline text-sm">
                  Düzenle
                </button>
                <button onClick={() => remove(a.id)} className="text-red-700 hover:underline text-sm">
                  Sil
                </button>
                <button
                  onClick={() => setExpandedId(expandedId === a.id ? null : a.id)}
                  className="text-brand hover:underline text-sm"
                >
                  {expandedId === a.id ? 'Kapat' : 'Okuma Durumu'}
                </button>
              </div>
            </div>
            {expandedId === a.id && readStatus && (
              <div className="mt-4 pt-4 border-t border-gray-100 grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="font-medium text-green-700 mb-2">
                    Okudu ({readStatus.read.length})
                  </p>
                  {readStatus.read.map((u: any) => (
                    <p key={u.id} className="text-gray-600">
                      {u.company} — {u.firstName} {u.lastName}
                    </p>
                  ))}
                </div>
                <div>
                  <p className="font-medium text-red-700 mb-2">
                    Henüz Okumadı ({readStatus.notRead.length})
                  </p>
                  {readStatus.notRead.map((u: any) => (
                    <p key={u.id} className="text-gray-600">
                      {u.company} — {u.firstName} {u.lastName}
                    </p>
                  ))}
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
