'use client';

import useSWR from 'swr';
import { api } from '@/lib/api';
import { Badge } from '@/components/ui';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function InactiveDealersPage() {
  const { data: dealers } = useSWR('/users/inactive', fetcher);

  return (
    <div className="admin-page">
      <div className="mb-7"><p className="admin-eyebrow">BAYİ AĞI / TAKİP</p><h2 className="admin-page-title">Pasif Bayiler</h2><p className="admin-page-subtitle">30 günden uzun süredir giriş yapmayan aktif bayileri takip edin.</p></div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {dealers?.map((d: any) => (
          <div key={d.id} className="bg-white rounded-2xl border border-slate-200/80 shadow-[0_10px_30px_rgba(15,23,42,0.035)] p-5 hover:border-blue-200 hover:shadow-[0_14px_30px_rgba(30,64,175,0.10)] transition-all">
            <div className="flex items-start justify-between mb-3">
              <div className="w-10 h-10 rounded-xl bg-blue-50 border border-blue-100 flex items-center justify-center text-blue-700 font-bold text-sm shrink-0">
                {d.company?.[0]?.toUpperCase() || '?'}
              </div>
              <Badge label="Pasif" tone="pending" />
            </div>
            <p className="text-sm font-bold text-navy truncate">{d.company}</p>
            <p className="text-xs text-gray-500 mt-1 truncate">{d.firstName} {d.lastName}</p>
            <p className="text-xs text-gray-400 mt-0.5 truncate">{d.email}</p>
            <p className="text-xs text-amber-600 font-medium mt-2">
              {d.lastLoginAt ? `Son giriş: ${new Date(d.lastLoginAt).toLocaleDateString('tr-TR')}` : 'Hiç giriş yapmadı'}
            </p>
          </div>
        ))}
      </div>
      {dealers?.length === 0 && <p className="text-center text-gray-400 py-16">Tüm bayiler aktif — pasif bayi yok. 🎉</p>}
    </div>
  );
}
