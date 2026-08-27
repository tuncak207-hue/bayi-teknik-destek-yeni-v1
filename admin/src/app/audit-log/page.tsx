'use client';

import useSWR from 'swr';
import { api } from '@/lib/api';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const actionLabels: Record<string, string> = {
  dealer_approved: 'Bayi onaylandı',
  dealer_suspended: 'Bayi pasifleştirildi',
  dealer_removed: 'Bayi silindi',
};

export default function AuditLogPage() {
  const { data: logs } = useSWR('/audit-log', fetcher, { refreshInterval: 15000 });

  return (
    <div className="admin-page">
      <div className="mb-7"><p className="admin-eyebrow">GÜVENLİK / DENETİM</p><h2 className="admin-page-title">İşlem Günlüğü</h2><p className="admin-page-subtitle">Admin hesaplarının yaptığı kritik işlemleri izleyin; kayıtlar hesap verebilirlik için canlı olarak yenilenir.</p></div>

      <div className="admin-surface overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-slate-50/80 text-slate-500 text-left text-[11px] uppercase tracking-[0.08em]">
            <tr>
              <th className="px-4 py-3">İşlem</th>
              <th className="px-4 py-3">Yapan Admin</th>
              <th className="px-4 py-3">Detay</th>
              <th className="px-4 py-3">Zaman</th>
            </tr>
          </thead>
          <tbody>
            {logs?.map((log: any) => (
              <tr key={log.id} className="border-t border-slate-100 hover:bg-slate-50/60 transition-colors">
                <td className="px-4 py-3 font-medium">{actionLabels[log.action] ?? log.action}</td>
                <td className="px-4 py-3">
                  {log.admin?.firstName} {log.admin?.lastName}
                </td>
                <td className="px-4 py-3 text-gray-500">{log.detail ?? '—'}</td>
                <td className="px-4 py-3 text-gray-400">{new Date(log.createdAt).toLocaleString('tr-TR')}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {logs?.length === 0 && <p className="p-6 text-center text-gray-400">Henüz kaydedilmiş bir işlem yok.</p>}
      </div>
    </div>
  );
}
