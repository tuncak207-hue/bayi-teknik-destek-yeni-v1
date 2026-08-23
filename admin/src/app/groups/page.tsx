'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { PillButton } from '@/components/ui';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function GroupsPage() {
  const { data: groups, mutate } = useSWR('/groups', fetcher);
  const [name, setName] = useState('');
  const [selected, setSelected] = useState<any>(null);
  const [editing, setEditing] = useState(false);

  async function createGroup(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    await api.post('/groups', { name });
    setName('');
    mutate();
  }

  async function saveRename(newName: string) {
    await api.patch(`/groups/${selected.id}`, { name: newName });
    mutate();
    setSelected((s: any) => ({ ...s, name: newName }));
    setEditing(false);
  }

  async function remove(id: string) {
    if (!confirm('Bu grubu silmek istediğinize emin misiniz?')) return;
    await api.delete(`/groups/${id}`);
    mutate();
    setSelected(null);
  }

  return (
    <div>
      <form onSubmit={createGroup} className="flex gap-3 mb-6">
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Yeni grup adı (örn. Yangın Alarm)"
          className="flex-1 border border-gray-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-navy/10 focus:border-navy transition"
        />
        <PillButton type="submit" variant="primary">Grup Oluştur</PillButton>
      </form>

      <p className="text-[13px] text-gray-400 mb-4">Bir grup kartına tıklayarak adını değiştirebilir veya silebilirsiniz.</p>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {groups?.map((g: any) => (
          <button
            key={g.id}
            onClick={() => {
              setSelected(g);
              setEditing(false);
            }}
            className="text-left bg-white rounded-2xl border border-gray-100 shadow-sm shadow-gray-100/50 p-5 hover:shadow-md hover:shadow-gray-200/60 hover:-translate-y-0.5 transition-all"
          >
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center text-white mb-3 shadow-sm">👥</div>
            <p className="text-sm font-bold text-navy truncate">{g.name}</p>
            <p className="text-xs text-gray-400 mt-1">{g._count?.members ?? 0} üye</p>
          </button>
        ))}
      </div>
      {groups?.length === 0 && <p className="text-center text-gray-400 py-16">Henüz grup oluşturulmadı.</p>}

      {selected && (
        <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50 p-4" onClick={() => setSelected(null)}>
          <div className="bg-white rounded-2xl w-full max-w-sm overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="h-1.5 bg-brand" />
            <div className="p-6">
              {editing ? (
                <RenameForm currentName={selected.name} onCancel={() => setEditing(false)} onSave={saveRename} />
              ) : (
                <>
                  <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center text-lg mb-4 shadow-sm">👥</div>
                  <h3 className="text-base font-bold text-navy">{selected.name}</h3>
                  <p className="text-sm text-gray-400 mt-1">{selected._count?.members ?? 0} üye</p>
                  <div className="flex flex-wrap gap-2 mt-6">
                    <button onClick={() => setEditing(true)} className="text-sm font-medium text-navy border border-gray-200 rounded-xl px-4 py-2 hover:bg-gray-50 transition">
                      Adını Değiştir
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

function RenameForm({ currentName, onCancel, onSave }: { currentName: string; onCancel: () => void; onSave: (name: string) => void }) {
  const [name, setName] = useState(currentName);
  return (
    <div>
      <h3 className="text-sm font-bold text-navy mb-4">Grup Adını Değiştir</h3>
      <input value={name} onChange={(e) => setName(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" autoFocus />
      <div className="flex gap-2 mt-5">
        <button onClick={onCancel} className="flex-1 text-sm font-medium text-gray-600 border border-gray-200 rounded-xl py-2.5 hover:bg-gray-50 transition">
          Vazgeç
        </button>
        <button
          onClick={() => name.trim() && onSave(name.trim())}
          className="flex-1 text-sm font-medium text-white bg-brand rounded-xl py-2.5 hover:bg-brand-dark transition"
        >
          Kaydet
        </button>
      </div>
    </div>
  );
}
