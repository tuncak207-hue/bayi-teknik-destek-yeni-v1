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
    <div>
      <p className="text-[13px] text-gray-400 mb-6">Admin hesaplarının yaptığı kritik işlemlerin kaydı — hesap verebilirlik için.</p>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th className="px-4 py-3">İşlem</th>
              <th className="px-4 py-3">Yapan Admin</th>
              <th className="px-4 py-3">Detay</th>
              <th className="px-4 py-3">Zaman</th>
            </tr>
          </thead>
          <tbody>
            {logs?.map((log: any) => (
              <tr key={log.id} className="border-t border-gray-100">
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
