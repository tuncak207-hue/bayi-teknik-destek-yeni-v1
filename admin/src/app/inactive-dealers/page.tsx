'use client';

import useSWR from 'swr';
import { api } from '@/lib/api';
import { Badge } from '@/components/ui';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function InactiveDealersPage() {
  const { data: dealers } = useSWR('/users/inactive', fetcher);

  return (
    <div>
      <p className="text-[13px] text-gray-400 mb-6">30+ gündür giriş yapmamış aktif bayiler — bunlara ulaşmayı düşünebilirsiniz.</p>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {dealers?.map((d: any) => (
          <div key={d.id} className="bg-white rounded-lg border border-gray-100 shadow-[0_1px_2px_rgba(15,23,42,0.04)] shadow-gray-100/50 p-5">
            <div className="flex items-start justify-between mb-3">
              <div className="w-10 h-10 rounded-xl bg-navy/[0.06] flex items-center justify-center text-navy font-bold text-sm shrink-0">
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
