'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Badge } from '@/components/ui';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const statusLabels: Record<string, string> = {
  OPEN: 'Açık',
  IN_PROGRESS: 'İşlemde',
  RESOLVED: 'Çözüldü',
  CLOSED: 'Kapatıldı',
  ESCALATED: 'Yükseltildi',
};

export default function SupportTicketsPage() {
  const { data: tickets, mutate } = useSWR('/support-tickets', fetcher);
  const { data: slaSettings, mutate: mutateSla } = useSWR('/support-tickets/settings/sla', fetcher);
  const { data: measurementTypes, mutate: mutateTypes } = useSWR('/support-tickets/measurement-types', fetcher);
  const { data: spareParts, mutate: mutateSpareParts } = useSWR('/support-tickets/spare-part-requests', fetcher);
  const { data: costReport } = useSWR('/support-tickets/reports/cost', fetcher);
  const [showSlaSettings, setShowSlaSettings] = useState(false);
  const [showMeasurementTypes, setShowMeasurementTypes] = useState(false);
  const [showSpareParts, setShowSpareParts] = useState(false);
  const [showCostReport, setShowCostReport] = useState(false);
  const [editingTicket, setEditingTicket] = useState<any>(null);
  const [newTypeName, setNewTypeName] = useState('');
  const [newTypeUnit, setNewTypeUnit] = useState('');
  const [newTypeMin, setNewTypeMin] = useState('');
  const [newTypeMax, setNewTypeMax] = useState('');

  const emergency = tickets?.filter((t: any) => t.isEmergency) ?? [];
  const normal = tickets?.filter((t: any) => !t.isEmergency) ?? [];

  async function updateStatus(id: string, status: string) {
    await api.patch(`/support-tickets/${id}/status`, { status });
    mutate();
  }

  async function deleteTicket(id: string) {
    if (!confirm('Bu teknik destek kaydını kalıcı olarak silmek istediğinize emin misiniz?')) return;
    await api.delete(`/support-tickets/${id}`);
    mutate();
  }

  async function updateTicketFields(id: string, fields: { productName?: string; productModel?: string; serialNumber?: string; location?: string; description?: string }) {
    await api.patch(`/support-tickets/${id}`, fields);
    mutate();
  }

  async function updateSla(priority: string, responseMinutes: number, resolutionMinutes: number) {
    await api.patch(`/support-tickets/settings/sla/${priority}`, { responseMinutes, resolutionMinutes });
    mutateSla();
  }

  async function updateSparePartStatus(id: string, status: string) {
    await api.patch(`/support-tickets/spare-part-requests/${id}/status`, { status });
    mutateSpareParts();
  }

  async function addMeasurementType(e: React.FormEvent) {
    e.preventDefault();
    if (!newTypeName.trim() || !newTypeUnit.trim()) return;
    await api.post('/support-tickets/measurement-types', {
      name: newTypeName.trim(),
      unit: newTypeUnit.trim(),
      minValue: newTypeMin ? Number(newTypeMin) : undefined,
      maxValue: newTypeMax ? Number(newTypeMax) : undefined,
    });
    setNewTypeName('');
    setNewTypeUnit('');
    setNewTypeMin('');
    setNewTypeMax('');
    mutateTypes();
  }

  const sparePartStatusLabels: Record<string, string> = {
    REQUESTED: 'Talep Edildi',
    APPROVED: 'Onaylandı',
    ORDERED: 'Sipariş Verildi',
    DELIVERED: 'Teslim Edildi',
    REJECTED: 'Reddedildi',
  };

  const costCategoryLabels: Record<string, string> = {
    ENGINEER_TIME: 'Mühendis Çalışma Süresi',
    SITE_VISIT: 'Saha Ziyareti',
    TRAVEL: 'Yol',
    ACCOMMODATION: 'Konaklama',
    SPARE_PART: 'Yedek Parça',
    LABOR: 'İşçilik',
  };

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <p className="text-sm text-gray-500">Bayilerden gelen teknik destek kayıtları — acil kayıtlar ayrı ve belirgin şekilde gösterilir.</p>
        <div className="flex gap-2 shrink-0 ml-4 flex-wrap justify-end">
          <button onClick={() => setShowCostReport((v) => !v)} className="text-sm font-medium text-navy border border-gray-200 px-4 py-2 rounded-xl hover:bg-gray-50 transition">
            {showCostReport ? 'Kapat' : 'Maliyet Raporu'}
          </button>
          <button onClick={() => setShowSpareParts((v) => !v)} className="text-sm font-medium text-navy border border-gray-200 px-4 py-2 rounded-xl hover:bg-gray-50 transition">
            {showSpareParts ? 'Kapat' : 'Yedek Parça Talepleri'}
          </button>
          <button onClick={() => setShowMeasurementTypes((v) => !v)} className="text-sm font-medium text-navy border border-gray-200 px-4 py-2 rounded-xl hover:bg-gray-50 transition">
            {showMeasurementTypes ? 'Kapat' : 'Ölçüm Türleri'}
          </button>
          <button onClick={() => setShowSlaSettings((v) => !v)} className="text-sm font-medium text-navy border border-gray-200 px-4 py-2 rounded-xl hover:bg-gray-50 transition">
            {showSlaSettings ? 'Kapat' : 'SLA Ayarları'}
          </button>
        </div>
      </div>

      {showCostReport && (
        <div className="bg-white rounded-2xl border border-gray-100 p-6 mb-8">
          <h3 className="text-sm font-bold text-gray-700 mb-4">Maliyet Analizi Raporu</h3>
          <div className="flex flex-wrap gap-3 mb-5">
            {costReport && Object.entries(costReport.totalByCategory).map(([cat, amount]: [string, any]) => (
              <div key={cat} className="bg-gray-50 rounded-xl px-4 py-3">
                <p className="text-xs text-gray-400">{costCategoryLabels[cat] || cat}</p>
                <p className="text-lg font-bold text-gray-800">{amount.toFixed(2)} ₺</p>
              </div>
            ))}
            <div className="bg-brand/10 rounded-xl px-4 py-3">
              <p className="text-xs text-brand">Genel Toplam</p>
              <p className="text-lg font-bold text-brand">{costReport?.grandTotal?.toFixed(2) ?? 0} ₺</p>
            </div>
          </div>
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-left">
              <tr>
                <th className="px-3 py-2">Bayi</th>
                <th className="px-3 py-2">Ürün</th>
                <th className="px-3 py-2">Konum</th>
                <th className="px-3 py-2">Kategori</th>
                <th className="px-3 py-2">Tutar</th>
                <th className="px-3 py-2">Tarih</th>
              </tr>
            </thead>
            <tbody>
              {costReport?.costs?.map((c: any) => (
                <tr key={c.id} className="border-t border-gray-100">
                  <td className="px-3 py-2">{c.ticket?.dealer?.firstName} {c.ticket?.dealer?.lastName}</td>
                  <td className="px-3 py-2">{c.ticket?.productName || '—'}</td>
                  <td className="px-3 py-2">{c.ticket?.location || '—'}</td>
                  <td className="px-3 py-2">{costCategoryLabels[c.category] || c.category}</td>
                  <td className="px-3 py-2 font-medium">{c.amount} ₺</td>
                  <td className="px-3 py-2 text-gray-400">{new Date(c.createdAt).toLocaleDateString('tr-TR')}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {(!costReport || costReport.costs.length === 0) && <p className="p-6 text-center text-gray-400">Henüz maliyet kaydı yok.</p>}
        </div>
      )}

      {showSpareParts && (
        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden mb-8">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-left">
              <tr>
                <th className="px-4 py-3">Ürün / Model / SN</th>
                <th className="px-4 py-3">Parça</th>
                <th className="px-4 py-3">Miktar</th>
                <th className="px-4 py-3">Bayi</th>
                <th className="px-4 py-3">Durum</th>
              </tr>
            </thead>
            <tbody>
              {spareParts?.map((r: any) => (
                <tr key={r.id} className="border-t border-gray-100">
                  <td className="px-4 py-3">{r.ticket?.productName} {r.ticket?.productModel} <span className="text-gray-400">({r.ticket?.serialNumber || '—'})</span></td>
                  <td className="px-4 py-3">{r.partName} {r.partCode && <span className="text-gray-400">[{r.partCode}]</span>}</td>
                  <td className="px-4 py-3">{r.quantity}</td>
                  <td className="px-4 py-3">{r.ticket?.dealer?.firstName} {r.ticket?.dealer?.lastName}</td>
                  <td className="px-4 py-3">
                    <select value={r.status} onChange={(e) => updateSparePartStatus(r.id, e.target.value)} className="border border-gray-200 rounded-lg px-2 py-1 text-xs">
                      {Object.entries(sparePartStatusLabels).map(([k, v]) => (
                        <option key={k} value={k}>{v}</option>
                      ))}
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {(!spareParts || spareParts.length === 0) && <p className="p-6 text-center text-gray-400">Henüz yedek parça talebi yok.</p>}
        </div>
      )}

      {showMeasurementTypes && (
        <div className="bg-white rounded-2xl border border-gray-100 p-6 mb-8 max-w-2xl">
          <h3 className="text-sm font-bold text-gray-700 mb-4">Ölçüm Türleri (Teknik Ölçüm Sistemi)</h3>
          <form onSubmit={addMeasurementType} className="flex items-end gap-2 mb-4">
            <div className="flex-1">
              <label className="block text-xs text-gray-400 mb-1">Ad</label>
              <input value={newTypeName} onChange={(e) => setNewTypeName(e.target.value)} placeholder="Örn: Voltaj" className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" />
            </div>
            <div className="w-20">
              <label className="block text-xs text-gray-400 mb-1">Birim</label>
              <input value={newTypeUnit} onChange={(e) => setNewTypeUnit(e.target.value)} placeholder="V" className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" />
            </div>
            <div className="w-20">
              <label className="block text-xs text-gray-400 mb-1">Min</label>
              <input type="number" value={newTypeMin} onChange={(e) => setNewTypeMin(e.target.value)} className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" />
            </div>
            <div className="w-20">
              <label className="block text-xs text-gray-400 mb-1">Max</label>
              <input type="number" value={newTypeMax} onChange={(e) => setNewTypeMax(e.target.value)} className="w-full border border-gray-200 rounded-lg px-2 py-1.5 text-sm" />
            </div>
            <button type="submit" className="text-xs font-medium text-white bg-brand px-3 py-2 rounded-lg hover:bg-brand-dark transition shrink-0">
              Ekle
            </button>
          </form>
          <div className="space-y-1.5">
            {measurementTypes?.map((t: any) => (
              <div key={t.id} className="text-sm text-gray-600 flex items-center gap-2">
                <span className="font-medium text-gray-800">{t.name}</span>
                <span className="text-gray-400">({t.unit})</span>
                {(t.minValue != null || t.maxValue != null) && (
                  <span className="text-xs text-gray-400">Kabul aralığı: {t.minValue ?? '—'} – {t.maxValue ?? '—'}</span>
                )}
              </div>
            ))}
            {(!measurementTypes || measurementTypes.length === 0) && <p className="text-xs text-gray-400">Henüz ölçüm türü tanımlanmadı.</p>}
          </div>
        </div>
      )}

      {showSlaSettings && (
        <div className="bg-white rounded-2xl border border-gray-100 p-6 mb-8 max-w-2xl">
          <h3 className="text-sm font-bold text-gray-700 mb-4">Öncelik Bazında SLA Süreleri (dakika)</h3>
          <div className="space-y-3">
            {slaSettings?.map((s: any) => (
              <SlaRow key={s.priority} setting={s} onSave={updateSla} />
            ))}
          </div>
        </div>
      )}

      {emergency.length > 0 && (
        <div className="mb-8">
          <h2 className="text-sm font-bold text-red-700 mb-3 flex items-center gap-2">
            🔴 ACİL KAYITLAR ({emergency.length})
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {emergency.map((t: any) => (
              <TicketCard key={t.id} ticket={t} onStatusChange={updateStatus} onDelete={deleteTicket} onEdit={setEditingTicket} emergency />
            ))}
          </div>
        </div>
      )}

      <h2 className="text-sm font-semibold text-gray-500 mb-3">Tüm Kayıtlar ({normal.length})</h2>
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th className="px-4 py-3">Bayi</th>
              <th className="px-4 py-3">Ürün</th>
              <th className="px-4 py-3">Açıklama</th>
              <th className="px-4 py-3">Durum</th>
              <th className="px-4 py-3">Tarih</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {normal.map((t: any) => (
              <tr key={t.id} className="border-t border-gray-100">
                <td className="px-4 py-3">{t.dealer?.firstName} {t.dealer?.lastName}</td>
                <td className="px-4 py-3">{t.productName || '—'}</td>
                <td className="px-4 py-3 max-w-xs truncate">{t.description}</td>
                <td className="px-4 py-3">
                  <select
                    value={t.status}
                    onChange={(e) => updateStatus(t.id, e.target.value)}
                    className="border border-gray-200 rounded-lg px-2 py-1 text-xs"
                  >
                    {Object.entries(statusLabels).map(([k, v]) => (
                      <option key={k} value={k}>{v}</option>
                    ))}
                  </select>
                </td>
                <td className="px-4 py-3 text-gray-400">{new Date(t.createdAt).toLocaleDateString('tr-TR')}</td>
                <td className="px-4 py-3 text-right whitespace-nowrap">
                  <button onClick={() => setEditingTicket(t)} className="text-navy hover:underline text-xs mr-3">
                    Düzenle
                  </button>
                  <button onClick={() => deleteTicket(t.id)} className="text-red-600 hover:underline text-xs">
                    Sil
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {normal.length === 0 && <p className="p-6 text-center text-gray-400">Kayıt yok.</p>}
      </div>

      {editingTicket && (
        <EditTicketModal
          ticket={editingTicket}
          onClose={() => setEditingTicket(null)}
          onSave={async (fields) => {
            await updateTicketFields(editingTicket.id, fields);
            setEditingTicket(null);
          }}
        />
      )}
    </div>
  );
}

function EditTicketModal({
  ticket,
  onClose,
  onSave,
}: {
  ticket: any;
  onClose: () => void;
  onSave: (fields: { productName?: string; productModel?: string; serialNumber?: string; location?: string; description?: string }) => void;
}) {
  const [productName, setProductName] = useState(ticket.productName || '');
  const [productModel, setProductModel] = useState(ticket.productModel || '');
  const [serialNumber, setSerialNumber] = useState(ticket.serialNumber || '');
  const [location, setLocation] = useState(ticket.location || '');
  const [description, setDescription] = useState(ticket.description || '');

  return (
    <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50 p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
        <h3 className="text-sm font-bold text-navy mb-4">Teknik Destek Kaydını Düzenle</h3>
        <div className="space-y-3">
          <div>
            <label className="block text-xs text-gray-400 mb-1">Ürün Adı</label>
            <input value={productName} onChange={(e) => setProductName(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-gray-400 mb-1">Model</label>
            <input value={productModel} onChange={(e) => setProductModel(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-gray-400 mb-1">Seri Numarası</label>
            <input value={serialNumber} onChange={(e) => setSerialNumber(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-gray-400 mb-1">Konum</label>
            <input value={location} onChange={(e) => setLocation(e.target.value)} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="block text-xs text-gray-400 mb-1">Açıklama</label>
            <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
          </div>
        </div>
        <div className="flex gap-2 mt-5">
          <button onClick={onClose} className="flex-1 text-sm font-medium text-gray-600 border border-gray-200 rounded-xl py-2.5 hover:bg-gray-50 transition">
            Vazgeç
          </button>
          <button
            onClick={() => onSave({ productName, productModel, serialNumber, location, description })}
            className="flex-1 text-sm font-medium text-white bg-brand rounded-xl py-2.5 hover:bg-brand-dark transition"
          >
            Kaydet
          </button>
        </div>
      </div>
    </div>
  );
}

function TicketCard({ ticket, onStatusChange, onDelete, onEdit, emergency }: { ticket: any; onStatusChange: (id: string, status: string) => void; onDelete: (id: string) => void; onEdit: (ticket: any) => void; emergency?: boolean }) {
  const sla = ticket.slaStatus || {};
  return (
    <div className={`bg-white rounded-xl border p-4 ${emergency ? 'border-red-300 shadow-sm shadow-red-100' : 'border-gray-200'}`}>
      <div className="flex items-start justify-between mb-2">
        <p className="font-semibold text-gray-800">{ticket.productName || 'Ürün belirtilmedi'}</p>
        <select
          value={ticket.status}
          onChange={(e) => onStatusChange(ticket.id, e.target.value)}
          className="border border-gray-200 rounded-lg px-2 py-1 text-xs"
        >
          {Object.entries(statusLabels).map(([k, v]) => (
            <option key={k} value={k}>{v}</option>
          ))}
        </select>
      </div>
      <p className="text-xs text-gray-500 mb-2">{ticket.dealer?.firstName} {ticket.dealer?.lastName} — {ticket.dealer?.company}</p>
      <p className="text-sm text-gray-700 mb-2">{ticket.description}</p>
      {ticket.location && <p className="text-xs text-gray-400 mb-2">📍 {ticket.location}</p>}
      {ticket.escalationLevel > 0 && (
        <span className="mr-2 inline-block">
          <Badge label={`⚠️ Eskalasyon Seviye ${ticket.escalationLevel}`} tone="pending" />
        </span>
      )}
      {sla.resolutionRemainingMinutes != null && (
        <Badge
          label={sla.resolutionBreached ? 'SLA Aşıldı' : `SLA: ${Math.floor(sla.resolutionRemainingMinutes / 60)}sa ${sla.resolutionRemainingMinutes % 60}dk kaldı`}
          tone={sla.resolutionBreached ? 'danger' : 'neutral'}
        />
      )}
      <div className="flex gap-3 mt-3 pt-3 border-t border-gray-50">
        <button onClick={() => onEdit(ticket)} className="text-navy hover:underline text-xs font-medium">
          Düzenle
        </button>
        <button onClick={() => onDelete(ticket.id)} className="text-red-600 hover:underline text-xs font-medium">
          Sil
        </button>
      </div>
    </div>
  );
}

const priorityLabels: Record<string, string> = {
  EMERGENCY: 'Acil',
  HIGH: 'Yüksek',
  NORMAL: 'Normal',
  LOW: 'Düşük',
};

function SlaRow({ setting, onSave }: { setting: any; onSave: (priority: string, response: number, resolution: number) => void }) {
  const [response, setResponse] = useState(setting.responseMinutes);
  const [resolution, setResolution] = useState(setting.resolutionMinutes);

  return (
    <div className="flex items-center gap-3">
      <span className="w-20 text-sm font-medium text-gray-700 shrink-0">{priorityLabels[setting.priority] || setting.priority}</span>
      <div className="flex items-center gap-1.5">
        <label className="text-xs text-gray-400">Yanıt:</label>
        <input
          type="number"
          value={response}
          onChange={(e) => setResponse(Number(e.target.value))}
          className="w-20 border border-gray-200 rounded-lg px-2 py-1 text-xs"
        />
      </div>
      <div className="flex items-center gap-1.5">
        <label className="text-xs text-gray-400">Çözüm:</label>
        <input
          type="number"
          value={resolution}
          onChange={(e) => setResolution(Number(e.target.value))}
          className="w-20 border border-gray-200 rounded-lg px-2 py-1 text-xs"
        />
      </div>
      <button
        onClick={() => onSave(setting.priority, response, resolution)}
        className="text-xs font-medium text-white bg-navy px-3 py-1.5 rounded-lg hover:bg-navy-light transition"
      >
        Kaydet
      </button>
    </div>
  );
}
