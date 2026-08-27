'use client';

import Link from 'next/link';
import { Card, CardHeader, Badge } from '@/components/ui';
import { IconAlertTriangle, IconChart, IconReceipt } from '@/components/icons';

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

      <Card>
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

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-baseline gap-1 sm:gap-4 py-2 border-b border-gray-50 last:border-0">
      <span className="text-xs font-semibold text-gray-500 w-40 shrink-0">{label}</span>
      <span className="text-sm text-gray-700">{value}</span>
    </div>
  );
}
