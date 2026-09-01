'use client';

import Link from 'next/link';
import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Card, CardHeader, Badge } from '@/components/ui';
import { IconAlertTriangle, IconChart, IconReceipt } from '@/components/icons';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const settingsLinks = [
  {
    title: 'SLA Süreleri',
    description: 'Öncelik bazında yanıt ve çözüm süre hedeflerini ayarlayın.',
    href: '/support-tickets',
    Icon: IconAlertTriangle,
  },
  {
    title: 'Ölçüm Türleri',
    description: 'Sahada girilebilecek teknik ölçüm türlerini ve kabul aralıklarını tanımlayın.',
    href: '/support-tickets',
    Icon: IconChart,
  },
  {
    title: 'Fiyat / Malzeme Listesi',
    description: 'Teklif Al ekranında kullanılan katalog ve referans PDF\'i yönetin.',
    href: '/quotes',
    Icon: IconReceipt,
  },
];

export default function SettingsPage() {
  return (
    <div className="admin-page">
      <div className="mb-7"><p className="admin-eyebrow">YÖNETİM / KONFİGÜRASYON</p><h2 className="admin-page-title">Ayarlar</h2><p className="admin-page-subtitle">Uygulama genelindeki operasyonel yapılandırmaları ve sistem bilgisini yönetin.</p></div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        {settingsLinks.map((s) => (
          <Link key={s.title} href={s.href}>
                          <Card className="p-5 h-full hover:-translate-y-0.5 hover:border-blue-200 hover:shadow-[0_14px_30px_rgba(30,64,175,0.10)] transition-all cursor-pointer">

              <div className="w-11 h-11 rounded-2xl bg-blue-50 border border-blue-100 flex items-center justify-center text-blue-700 mb-4">
                <s.Icon width={18} height={18} />
              </div>
              <h3 className="text-[14px] font-bold tracking-[-0.015em] text-slate-900 mb-1">{s.title}</h3>
              <p className="text-[12.5px] text-slate-500 leading-relaxed">{s.description}</p>
            </Card>
          </Link>
        ))}
      </div>

      <AccountSettingsCard />

      <Card className="mt-8">
        <CardHeader title="Sistem Bilgisi" subtitle="AI ve altyapı yapılandırması" />
        <div className="px-5 pb-5 space-y-3">
          <InfoRow label="AI Sağlayıcı" value="Backend .env dosyasındaki AI_PROVIDER değişkeni ile belirlenir (anthropic / ollama)." />
          <InfoRow label="Embedding Sağlayıcı" value="Backend .env dosyasındaki EMBEDDING_PROVIDER değişkeni ile belirlenir." />
          <InfoRow label="Dosya Depolama" value="Cloudflare R2 üzerinde, backend .env yapılandırmasıyla bağlanır." />
        </div>
        <div className="px-5 pb-5">
          <div className="flex items-center gap-2 text-xs text-gray-400 bg-gray-50 rounded-xl px-4 py-3">
            <Badge label="Bilgi" tone="neutral" />
            <span>Bu değerler güvenlik nedeniyle backend&apos;deki <code className="bg-gray-100 px-1 py-0.5 rounded">.env</code> dosyası üzerinden yönetilir, bu panelden değiştirilemez.</span>
          </div>
        </div>
      </Card>
    </div>
  );
}

/**
 * Kullanıcı isteği: "admin panel kullanıcı adı ve şifremi değiştirmek
 * istiyorum" — kendi hesabınızın giriş e-postasını (kullanıcı adı) ve
 * şifresini buradan değiştirebilirsiniz. İkisi de ayrı formlar: e-posta
 * değişikliği anında uygulanır, şifre değişikliği mevcut şifrenizi
 * doğrulamanızı ister (güvenlik için).
 */
function AccountSettingsCard() {
  const { data: me, mutate } = useSWR('/users/me', fetcher);

  const [email, setEmail] = useState('');
  const [emailSaving, setEmailSaving] = useState(false);
  const [emailMsg, setEmailMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newPasswordRepeat, setNewPasswordRepeat] = useState('');
  const [passwordSaving, setPasswordSaving] = useState(false);
  const [passwordMsg, setPasswordMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  async function handleEmailSave(e: React.FormEvent) {
    e.preventDefault();
    if (!email.trim()) return;
    setEmailSaving(true);
    setEmailMsg(null);
    try {
      await api.patch('/users/me', { email: email.trim() });
      setEmailMsg({ type: 'success', text: 'E-posta güncellendi. Bir sonraki girişte yeni e-postanızı kullanın.' });
      setEmail('');
      mutate();
    } catch (err: any) {
      setEmailMsg({ type: 'error', text: err.response?.data?.message || 'E-posta güncellenemedi.' });
    } finally {
      setEmailSaving(false);
    }
  }

  async function handlePasswordSave(e: React.FormEvent) {
    e.preventDefault();
    setPasswordMsg(null);
    if (newPassword.length < 8) {
      setPasswordMsg({ type: 'error', text: 'Yeni şifre en az 8 karakter olmalı.' });
      return;
    }
    if (newPassword !== newPasswordRepeat) {
      setPasswordMsg({ type: 'error', text: 'Yeni şifreler birbiriyle eşleşmiyor.' });
      return;
    }
    setPasswordSaving(true);
    try {
      await api.patch('/users/me/password', { currentPassword, newPassword });
      setPasswordMsg({ type: 'success', text: 'Şifreniz güncellendi.' });
      setCurrentPassword('');
      setNewPassword('');
      setNewPasswordRepeat('');
    } catch (err: any) {
      setPasswordMsg({ type: 'error', text: err.response?.data?.message || 'Şifre güncellenemedi.' });
    } finally {
      setPasswordSaving(false);
    }
  }

  return (
    <Card>
      <CardHeader title="Hesap Ayarları" subtitle="Giriş e-postanızı (kullanıcı adı) ve şifrenizi buradan değiştirebilirsiniz." />
      <div className="px-5 pb-5 grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* E-posta değiştirme */}
        <form onSubmit={handleEmailSave} className="space-y-3">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mevcut e-posta</label>
            <div className="text-sm text-gray-500 h-10 flex items-center px-3 bg-gray-50 rounded-lg border border-gray-100">
              {me?.email || '—'}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Yeni e-posta (kullanıcı adı)</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-lg border border-gray-200 px-3 h-10 text-sm"
              placeholder="yeni-eposta@ornek.com"
            />
          </div>
          {emailMsg && (
            <p className={`text-xs ${emailMsg.type === 'success' ? 'text-green-700' : 'text-red-600'}`}>{emailMsg.text}</p>
          )}
          <button
            type="submit"
            disabled={emailSaving || !email.trim()}
            className="bg-[var(--admin-navy)] text-white text-[12.5px] font-semibold rounded-xl px-4 h-10 hover:bg-slate-800 transition disabled:opacity-50"
          >
            {emailSaving ? 'Kaydediliyor...' : 'E-postayı Güncelle'}
          </button>
        </form>

        {/* Şifre değiştirme */}
        <form onSubmit={handlePasswordSave} className="space-y-3">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mevcut şifre</label>
            <input
              type="password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              className="w-full rounded-lg border border-gray-200 px-3 h-10 text-sm"
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Yeni şifre</label>
              <input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="w-full rounded-lg border border-gray-200 px-3 h-10 text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Yeni şifre (tekrar)</label>
              <input
                type="password"
                value={newPasswordRepeat}
                onChange={(e) => setNewPasswordRepeat(e.target.value)}
                className="w-full rounded-lg border border-gray-200 px-3 h-10 text-sm"
              />
            </div>
          </div>
          {passwordMsg && (
            <p className={`text-xs ${passwordMsg.type === 'success' ? 'text-green-700' : 'text-red-600'}`}>{passwordMsg.text}</p>
          )}
          <button
            type="submit"
            disabled={passwordSaving || !currentPassword || !newPassword}
            className="bg-[var(--admin-navy)] text-white text-[12.5px] font-semibold rounded-xl px-4 h-10 hover:bg-slate-800 transition disabled:opacity-50"
          >
            {passwordSaving ? 'Kaydediliyor...' : 'Şifreyi Güncelle'}
          </button>
        </form>
      </div>
    </Card>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-baseline gap-1 sm:gap-4 py-2 border-b border-gray-50 last:border-0">
      <span className="text-xs font-semibold text-gray-500 w-40 shrink-0">{label}</span>
      <span className="text-sm text-gray-700">{value}</span>
    </div>
  );
}
