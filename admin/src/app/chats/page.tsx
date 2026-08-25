'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const BAN_OPTIONS = [
  { label: '1 Saat', hours: 1 },
  { label: '3 Saat', hours: 3 },
  { label: '1 Gün', hours: 24 },
  { label: '7 Gün', hours: 24 * 7 },
];

export default function ChatsPage() {
  const { data: conversations, mutate } = useSWR('/chat/admin/conversations', fetcher);
  const [openId, setOpenId] = useState<string | null>(null);

  async function deleteConversation(id: string) {
    if (!confirm('Bu sohbeti (tüm mesajlarıyla birlikte) kalıcı olarak silmek istediğinize emin misiniz?')) return;
    await api.delete(`/chat/admin/conversations/${id}`);
    if (openId === id) setOpenId(null);
    mutate();
  }

  function participantsLabel(c: any) {
    if (c.type === 'GROUP') return c.title ?? 'Grup';
    return c.participants.map((p: any) => p.user.company || `${p.user.firstName} ${p.user.lastName}`).join(' ↔ ');
  }

  return (
    <div>
      <p className="text-[13px] text-gray-400 mb-6">
        Bayiler arası ve grup sohbetlerini görüntüleyin, uygunsuz mesajları veya tüm sohbeti silin, kullanıcılara
        süreli mesajlaşma yasağı verin.
      </p>

      <div className="bg-white rounded-lg border border-gray-100 shadow-[0_1px_2px_rgba(15,23,42,0.04)] shadow-gray-100/50 divide-y divide-gray-50 overflow-hidden">
        {conversations?.map((c: any) => (
          <div key={c.id}>
            <div className="flex items-center justify-between px-5 py-4 hover:bg-gray-50/60 transition-colors">
              <div className="min-w-0">
                <div className="text-sm font-bold text-navy truncate">{participantsLabel(c)}</div>
                <div className="text-xs text-gray-400 mt-0.5 truncate">
                  {c._count.messages} mesaj · Son: {c.messages[0]?.content?.slice(0, 60) || '—'}
                </div>
              </div>
              <div className="flex gap-3 items-center whitespace-nowrap shrink-0 ml-4">
                <button
                  onClick={() => setOpenId(openId === c.id ? null : c.id)}
                  className="text-sm font-medium text-navy border border-gray-200 rounded-xl px-3.5 py-1.5 hover:bg-gray-50 transition"
                >
                  {openId === c.id ? 'Kapat' : 'Görüntüle'}
                </button>
                <button onClick={() => deleteConversation(c.id)} className="text-sm font-medium text-red-600 hover:underline">
                  Sil
                </button>
              </div>
            </div>
            {openId === c.id && <ConversationMessages conversationId={c.id} onChanged={mutate} />}
          </div>
        ))}
        {conversations?.length === 0 && <p className="p-6 text-center text-gray-400">Henüz bir sohbet yok.</p>}
      </div>
    </div>
  );
}

function ConversationMessages({ conversationId, onChanged }: { conversationId: string; onChanged: () => void }) {
  const { data: messages, mutate } = useSWR(`/chat/admin/conversations/${conversationId}/messages`, fetcher);
  const [banMenuFor, setBanMenuFor] = useState<string | null>(null);

  async function deleteMessage(id: string) {
    if (!confirm('Bu mesajı silmek istediğinize emin misiniz?')) return;
    await api.delete(`/chat/admin/messages/${id}`);
    mutate();
    onChanged();
  }

  async function banUser(userId: string, hours: number, label: string) {
    if (!confirm(`Bu kullanıcıya ${label} süreyle mesajlaşma yasağı vermek istediğinize emin misiniz?`)) return;
    await api.post(`/users/${userId}/chat-ban`, { hours });
    setBanMenuFor(null);
    alert(`Kullanıcı ${label} süreyle susturuldu.`);
  }

  return (
    <div className="bg-gray-50 px-4 py-3 space-y-2 border-t border-gray-100">
      {messages?.map((m: any) => (
        <div key={m.id} className="flex items-start justify-between bg-white rounded-lg px-3 py-2 border border-gray-100">
          <div className="flex-1 min-w-0">
            <div className="text-xs text-gray-500">
              {m.sender ? `${m.sender.firstName} ${m.sender.lastName} (${m.sender.company})` : 'AI'} ·{' '}
              {new Date(m.createdAt).toLocaleString('tr-TR')}
            </div>
            <div className="text-sm mt-0.5 break-words">{m.content}</div>
          </div>
          <div className="flex gap-2 items-center relative shrink-0 ml-3">
            {m.sender && (
              <div className="relative">
                <button
                  onClick={() => setBanMenuFor(banMenuFor === m.id ? null : m.id)}
                  className="text-amber-700 hover:underline text-xs whitespace-nowrap"
                >
                  Kullanıcıyı Sustur
                </button>
                {banMenuFor === m.id && (
                  <div className="absolute right-0 mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-10 py-1 w-32">
                    {BAN_OPTIONS.map((opt) => (
                      <button
                        key={opt.hours}
                        onClick={() => banUser(m.sender.id, opt.hours, opt.label)}
                        className="block w-full text-left px-3 py-1.5 text-xs hover:bg-gray-50"
                      >
                        {opt.label}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
            <button onClick={() => deleteMessage(m.id)} className="text-red-700 hover:underline text-xs">
              Sil
            </button>
          </div>
        </div>
      ))}
      {messages?.length === 0 && <p className="text-center text-gray-400 text-sm py-2">Mesaj yok.</p>}
    </div>
  );
}
