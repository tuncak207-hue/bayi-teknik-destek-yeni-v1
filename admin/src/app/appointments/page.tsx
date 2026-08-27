'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const STATUS_LABEL: Record<string, string> = {
  PENDING: 'Onay Bekliyor',
  CONFIRMED: 'Onaylandı',
  CANCELLED: 'İptal Edildi',
  COMPLETED: 'Tamamlandı',
};

const STATUS_COLOR: Record<string, string> = {
  PENDING: 'bg-amber-100 text-amber-700',
  CONFIRMED: 'bg-green-100 text-green-700',
  CANCELLED: 'bg-gray-200 text-gray-600',
  COMPLETED: 'bg-blue-100 text-blue-700',
};

export default function AppointmentsPage() {
  const [filter, setFilter] = useState<string>('');
  const { data: appointments, mutate } = useSWR(
    `/appointments${filter ? `?status=${filter}` : ''}`,
    fetcher,
  );

  async function updateStatus(id: string, status: string) {
    let adminNote: string | undefined;
    if (status === 'CANCELLED') {
      adminNote = prompt('İptal notu (opsiyonel):') || undefined;
    }
    await api.patch(`/appointments/${id}/status`, { status, adminNote });
    mutate();
  }

  async function editAppointment(a: any) {
    const newSubject = prompt('Konu:', a.subject);
    if (newSubject === null) return; // vazgeçildi
    const currentDate = new Date(a.preferredStart);
    const isoHint = currentDate.toISOString().slice(0, 16); // YYYY-MM-DDTHH:mm
    const newDateStr = prompt('Tarih/Saat (YYYY-AA-GGTSS:DD formatında):', isoHint);
    if (newDateStr === null) return;

    const newDate = new Date(newDateStr);
    if (isNaN(newDate.getTime())) {
      alert('Geçersiz tarih formatı, değişiklik yapılmadı.');
      return;
    }

    await api.patch(`/appointments/${a.id}`, {
      subject: newSubject,
      preferredStart: newDate.toISOString(),
    });
    mutate();
  }

  async function deleteAppointment(id: string) {
    if (!confirm('Bu randevuyu kalıcı olarak silmek istediğinize emin misiniz? Bayiye bilgi gönderilecek.')) return;
    await api.delete(`/appointments/${id}/admin`);
    mutate();
  }

  return (
    <div className="admin-page">
      <div className="mb-6"><p className="admin-eyebrow">OPERASYON / PLANLAMA</p><h2 className="admin-page-title">Randevular</h2><p className="admin-page-subtitle">Bayi randevularını durumlarına göre izleyin ve operasyon adımlarını yönetin.</p></div>
      <div className="flex flex-wrap gap-2 mb-6">
        {['', 'PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED'].map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`px-3.5 h-9 rounded-xl text-[12.5px] font-semibold transition ${
              filter === s ? 'bg-[var(--admin-navy)] text-white shadow-sm' : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50 hover:border-slate-300'
            }`}
          >
            {s === '' ? 'Tümü' : STATUS_LABEL[s]}
          </button>
        ))}
      </div>

      <div className="admin-surface overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-slate-50/80 text-slate-500 text-left text-[11px] uppercase tracking-[0.08em]">
            <tr>
              <th className="px-4 py-3">Bayi</th>
              <th className="px-4 py-3">Konu</th>
              <th className="px-4 py-3">Tür</th>
              <th className="px-4 py-3">Tarih/Saat</th>
              <th className="px-4 py-3">Durum</th>
              <th className="px-4 py-3 text-right">İşlemler</th>
            </tr>
          </thead>
          <tbody>
            {appointments?.map((a: any) => (
              <tr key={a.id} className="border-t border-slate-100 align-top hover:bg-slate-50/60 transition-colors">
                <td className="px-4 py-3">
                  <div className="font-medium">{a.dealer?.company}</div>
                  <div className="text-xs text-gray-500">
                    {a.dealer?.firstName} {a.dealer?.lastName} · {a.dealer?.phone}
                  </div>
                </td>
                <td className="px-4 py-3">
                  <div>{a.subject}</div>
                  {a.description && <div className="text-xs text-gray-500 mt-1">{a.description}</div>}
                </td>
                <td className="px-4 py-3">{a.type === 'ON_SITE' ? 'Sahada Ziyaret' : 'Telefon/Görüntülü'}</td>
                <td className="px-4 py-3">{new Date(a.preferredStart).toLocaleString('tr-TR')}</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-1 rounded-full text-xs font-medium ${STATUS_COLOR[a.status]}`}>
                    {STATUS_LABEL[a.status]}
                  </span>
                </td>
                <td className="px-4 py-3 text-right space-x-2 whitespace-nowrap">
                  {a.status === 'PENDING' && (
                    <>
                      <button onClick={() => updateStatus(a.id, 'CONFIRMED')} className="text-green-700 hover:underline">
                        Onayla
                      </button>
                      <button onClick={() => updateStatus(a.id, 'CANCELLED')} className="text-red-700 hover:underline">
                        Reddet
                      </button>
                    </>
                  )}
                  {a.status === 'CONFIRMED' && (
                    <button onClick={() => updateStatus(a.id, 'COMPLETED')} className="text-blue-700 hover:underline">
                      Tamamlandı İşaretle
                    </button>
                  )}
                  <button onClick={() => editAppointment(a)} className="text-gray-700 hover:underline">
                    Düzenle
                  </button>
                  <button onClick={() => deleteAppointment(a.id)} className="text-red-700 hover:underline">
                    Sil
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {appointments?.length === 0 && <p className="p-6 text-center text-gray-400">Kayıt yok.</p>}
      </div>
    </div>
  );
}
