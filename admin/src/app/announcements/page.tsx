'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function AnnouncementsPage() {
  const { data: announcements, mutate } = useSWR('/announcements', fetcher);
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
    <div>
      <form onSubmit={create} className="bg-white rounded-xl border border-gray-200 p-6 mb-8 space-y-4">
        <input
          value={form.title}
          onChange={(e) => setForm({ ...form, title: e.target.value })}
          placeholder="Başlık"
          className="w-full border border-gray-300 rounded-lg px-3 py-2"
        />
        <textarea
          value={form.body}
          onChange={(e) => setForm({ ...form, body: e.target.value })}
          placeholder="Duyuru içeriği"
          rows={4}
          className="w-full border border-gray-300 rounded-lg px-3 py-2"
        />
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.isCritical}
            onChange={(e) => setForm({ ...form, isCritical: e.target.checked })}
          />
          <span>
            <strong>Kritik duyuru</strong> — bayiler uygulamayı açtığında kapatılamayan bir onay
            ekranı görür, "Okudum, Anladım" demeden geçemez.
          </span>
        </label>
        <button className="bg-brand text-white rounded-lg px-4 py-2 font-medium hover:bg-brand-dark transition">
          Duyuru Yayınla (tüm bayilere push gider)
        </button>
      </form>

      <div className="space-y-3">
        {announcements?.map((a: any) => (
          <div key={a.id} className={`bg-white rounded-xl border p-4 ${a.isCritical ? 'border-brand' : 'border-gray-200'}`}>
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
