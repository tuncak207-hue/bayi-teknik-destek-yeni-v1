'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Badge, IconBadge, PillButton, LoadingState, EmptyState, NoResultsState } from '@/components/ui';
import { IconMapPin } from '@/components/icons';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const visitTypeLabels: Record<string, string> = {
  DEALER_VISIT: 'Bayi Ziyareti',
  PROJECT_MEETING: 'Proje Görüşmesi',
  PRODUCT_INTRO: 'Ürün Tanıtımı',
  TECHNICAL_MEETING: 'Teknik Görüşme',
  QUOTE_MEETING: 'Teklif Görüşmesi',
  TRAINING: 'Eğitim',
  COLLECTION: 'Tahsilat / Ticari Görüşme',
  OTHER: 'Diğer',
};

const topicLabels: Record<string, string> = {
  NEW_PROJECT: 'Yeni Proje',
  EXISTING_PROJECT: 'Mevcut Proje',
  PRODUCT_REQUEST: 'Ürün Talebi',
  PRICE_QUOTE: 'Fiyat / Teklif',
  TECHNICAL_SUPPORT: 'Teknik Destek',
  NEW_PRODUCT_INTRO: 'Yeni Ürün Tanıtımı',
  TRAINING: 'Eğitim',
  BUSINESS_DEVELOPMENT: 'İş Geliştirme',
  GENERAL: 'Genel Görüşme',
  OTHER: 'Diğer',
};

const outcomeLabels: Record<string, string> = {
  POSITIVE: 'Olumlu',
  QUOTE_PENDING: 'Teklif Bekliyor',
  PROJECT_CREATED: 'Proje Oluştu',
  ORDER_PENDING: 'Sipariş Bekleniyor',
  FOLLOW_UP_NEEDED: 'Takip Gerekli',
  NEGATIVE: 'Olumsuz',
  NOT_HAPPENED: 'Görüşme Gerçekleşmedi',
  OTHER: 'Diğer',
};

const outcomeTone: Record<string, 'success' | 'pending' | 'danger' | 'neutral' | 'inProgress'> = {
  POSITIVE: 'success',
  QUOTE_PENDING: 'pending',
  PROJECT_CREATED: 'success',
  ORDER_PENDING: 'pending',
  FOLLOW_UP_NEEDED: 'inProgress',
  NEGATIVE: 'danger',
  NOT_HAPPENED: 'neutral',
  OTHER: 'neutral',
};

const projectTypeLabels: Record<string, string> = {
  HOTEL: 'Otel',
  HOSPITAL: 'Hastane',
  MALL: 'AVM',
  FACTORY: 'Fabrika',
  SCHOOL: 'Okul',
  RESIDENTIAL: 'Konut',
  GOVERNMENT: 'Kamu',
  OFFICE: 'Ofis',
  OTHER: 'Diğer',
};

export default function DealerVisitsPage() {
  const [filters, setFilters] = useState({ from: '', to: '', city: '', visitType: '', outcome: '', needsFollowUp: '', search: '' });
  const queryString = new URLSearchParams(Object.entries(filters).filter(([, v]) => v)).toString();
  const { data: visits, isLoading, error, mutate } = useSWR(`/dealer-visits?${queryString}`, fetcher);
  const { data: dealers } = useSWR('/users?status=ACTIVE', fetcher);

  const [showForm, setShowForm] = useState(false);
  const [selected, setSelected] = useState<any>(null);
  const [editingVisit, setEditingVisit] = useState<any>(null);
  const [performanceSalesperson, setPerformanceSalesperson] = useState<any>(null);
  const [dealerHistoryId, setDealerHistoryId] = useState<string | null>(null);

  async function deleteVisit(id: string) {
    if (!confirm('Bu ziyaret kaydını silmek istediğinize emin misiniz?')) return;
    await api.delete(`/dealer-visits/${id}`);
    mutate();
    setSelected(null);
  }

  return (
    <div className="admin-page">
      <div className="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between mb-7">
        <div><p className="admin-eyebrow">OPERASYON / SAHA</p><h2 className="admin-page-title">Bayi Ziyaretleri</h2><p className="admin-page-subtitle">Saha faaliyetlerini, takip gerektiren kayıtları ve satış ekibi performansını tek ekrandan yönetin.</p></div>
        <PillButton onClick={() => setShowForm(true)} variant="primary">+ Yeni Ziyaret</PillButton>
      </div>

      <div className="flex justify-end gap-2 mb-3">
        <button
          onClick={() => exportVisitsToPdf(visits || [], filters)}
          disabled={!visits?.length}
          className="text-[12.5px] font-semibold text-slate-700 bg-white border border-slate-200 rounded-xl px-3.5 h-10 hover:bg-slate-50 hover:border-slate-300 transition disabled:opacity-40"
        >
          ⬇ PDF Rapor
        </button>
        <button
          onClick={() => exportVisitsToCsv(visits || [])}
          disabled={!visits?.length}
          className="text-[12.5px] font-semibold text-slate-700 bg-white border border-slate-200 rounded-xl px-3.5 h-10 hover:bg-slate-50 hover:border-slate-300 transition disabled:opacity-40"
        >
          ⬇ Excel&apos;e Aktar (CSV)
        </button>
      </div>

      <div className="admin-surface p-4 mb-5 flex flex-wrap gap-2.5 items-center">
        <input
          value={filters.search}
          onChange={(e) => setFilters({ ...filters, search: e.target.value })}
          placeholder="Bayi, satışçı, görüşülen kişi, not ara..."
          aria-label="Bayi ziyaretlerinde ara"
          className="h-10 flex-1 min-w-[220px] bg-slate-50 border border-slate-200/80 rounded-xl px-3.5 text-[12.5px] focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-300"
        />
        <input type="date" value={filters.from} onChange={(e) => setFilters({ ...filters, from: e.target.value })} className="h-10 border border-slate-200 rounded-xl bg-white px-2.5 text-[12.5px] focus:outline-none focus:ring-2 focus:ring-blue-500/20" />
        <span className="text-gray-300 text-xs">—</span>
        <input type="date" value={filters.to} onChange={(e) => setFilters({ ...filters, to: e.target.value })} className="h-10 border border-slate-200 rounded-xl bg-white px-2.5 text-[12.5px] focus:outline-none focus:ring-2 focus:ring-blue-500/20" />
        <input
          value={filters.city}
          onChange={(e) => setFilters({ ...filters, city: e.target.value })}
          placeholder="Şehir"
          className="h-8 w-24 border border-gray-200 rounded-lg px-2 text-[12.5px]"
        />
        <select value={filters.visitType} onChange={(e) => setFilters({ ...filters, visitType: e.target.value })} className="h-10 border border-slate-200 rounded-xl bg-white px-2.5 text-[12.5px] focus:outline-none focus:ring-2 focus:ring-blue-500/20">
          <option value="">Tüm Türler</option>
          {Object.entries(visitTypeLabels).map(([k, v]) => (
            <option key={k} value={k}>{v}</option>
          ))}
        </select>
        <select value={filters.outcome} onChange={(e) => setFilters({ ...filters, outcome: e.target.value })} className="h-10 border border-slate-200 rounded-xl bg-white px-2.5 text-[12.5px] focus:outline-none focus:ring-2 focus:ring-blue-500/20">
          <option value="">Tüm Sonuçlar</option>
          {Object.entries(outcomeLabels).map(([k, v]) => (
            <option key={k} value={k}>{v}</option>
          ))}
        </select>
        <label className="flex items-center gap-1.5 text-[12.5px] text-gray-600 h-8 px-2">
          <input type="checkbox" checked={filters.needsFollowUp === 'true'} onChange={(e) => setFilters({ ...filters, needsFollowUp: e.target.checked ? 'true' : '' })} />
          Sadece takip gerekenler
        </label>
      </div>

      {isLoading && <LoadingState />}
      {error && <EmptyState title="Ziyaretler yüklenemedi" description="Sayfayı yenilemeyi deneyin." />}
      {!isLoading && !error && visits?.length === 0 && (
        queryString ? <NoResultsState /> : <EmptyState title="Henüz ziyaret kaydı yok" description="Sağ üstteki '+ Yeni Ziyaret' ile ilk kaydı oluşturun." />
      )}

      {!isLoading && visits?.length > 0 && (
        <div className="space-y-2">
          {visits.map((v: any) => (
            <button
              key={v.id}
              onClick={() => setSelected(v)}
              className="w-full text-left bg-white rounded-2xl border border-slate-200/80 p-4 hover:border-blue-200 hover:shadow-[0_12px_26px_rgba(30,64,175,0.08)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500/30 transition-all flex items-center gap-3"
            >
              <IconBadge icon={<IconMapPin width={16} height={16} />} color={v.needsFollowUp ? 'amber' : 'blue'} size="md" />
              <div className="flex-1 min-w-0 grid grid-cols-1 sm:grid-cols-4 gap-2 items-center">
                <div className="min-w-0">
                  <span
                    onClick={(e) => {
                      if (v.dealerId) {
                        e.stopPropagation();
                        setDealerHistoryId(v.dealerId);
                      }
                    }}
                    className={`text-[13px] font-semibold text-gray-900 truncate block ${v.dealerId ? 'hover:underline hover:text-blue-700' : ''}`}
                  >
                    {v.dealer?.company || v.dealerNameFreeText || 'Bayi belirtilmedi'}
                  </span>
                  <p className="text-[11.5px] text-gray-400 mt-0.5">{new Date(v.visitDate).toLocaleDateString('tr-TR')} · {v.city || '—'}</p>
                </div>
                <span
                  onClick={(e) => {
                    e.stopPropagation();
                    setPerformanceSalesperson(v.salesperson);
                  }}
                  className="text-[12px] text-gray-500 truncate hover:underline hover:text-blue-700"
                >
                  {v.salesperson.firstName} {v.salesperson.lastName}
                </span>
                <div className="text-[12px] text-gray-500 truncate">{visitTypeLabels[v.visitType]}</div>
                <div className="flex items-center gap-2 justify-start sm:justify-end">
                  <Badge label={outcomeLabels[v.outcome]} tone={outcomeTone[v.outcome]} />
                  {v.needsFollowUp && !v.followUpDone && <Badge label="Takip" tone="pending" />}
                </div>
              </div>
            </button>
          ))}
        </div>
      )}

      {performanceSalesperson && (
        <SalespersonPerformanceDrawer salesperson={performanceSalesperson} onClose={() => setPerformanceSalesperson(null)} />
      )}

      {dealerHistoryId && <DealerHistoryDrawer dealerId={dealerHistoryId} onClose={() => setDealerHistoryId(null)} />}

      {showForm && (
        <VisitFormModal
          dealers={dealers}
          onClose={() => setShowForm(false)}
          onSaved={() => {
            setShowForm(false);
            mutate();
          }}
        />
      )}

      {editingVisit && (
        <VisitFormModal
          dealers={dealers}
          existingVisit={editingVisit}
          onClose={() => setEditingVisit(null)}
          onSaved={() => {
            setEditingVisit(null);
            setSelected(null);
            mutate();
          }}
        />
      )}

      {selected && !editingVisit && (
        <VisitDetailDrawer
          visit={selected}
          onClose={() => setSelected(null)}
          onEdit={() => setEditingVisit(selected)}
          onDelete={() => deleteVisit(selected.id)}
        />
      )}
    </div>
  );
}

function VisitDetailDrawer({ visit, onClose, onEdit, onDelete }: { visit: any; onClose: () => void; onEdit: () => void; onDelete: () => void }) {
  return (
    <div className="fixed inset-0 bg-black/30 flex justify-end z-50" onClick={onClose}>
      <div className="bg-white w-full max-w-md h-full overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between mb-1">
          <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide">Bayi Ziyareti</p>
          <button onClick={onClose} className="text-gray-300 hover:text-gray-600">✕</button>
        </div>
        <h2 className="text-lg font-bold text-gray-900">{visit.dealer?.company || visit.dealerNameFreeText || 'Bayi belirtilmedi'}</h2>
        <div className="flex items-center gap-2 mt-2">
          <Badge label={outcomeLabels[visit.outcome]} tone={outcomeTone[visit.outcome]} />
          <span className="text-[12px] text-gray-400">{visit.salesperson.firstName} {visit.salesperson.lastName} · {new Date(visit.visitDate).toLocaleDateString('tr-TR')}</span>
        </div>

        <Section title="Ziyaret Bilgileri">
          <Row label="Şehir" value={visit.city} />
          <Row label="Ziyaret Türü" value={visitTypeLabels[visit.visitType]} />
          <Row label="Konu" value={visit.topic ? topicLabels[visit.topic] : undefined} />
        </Section>

        {(visit.contactName || visit.contactPhone) && (
          <Section title="Görüşülen Kişi">
            <Row label="Ad Soyad" value={visit.contactName} />
            <Row label="Görevi" value={visit.contactTitle} />
            <Row label="Telefon" value={visit.contactPhone} />
            <Row label="E-posta" value={visit.contactEmail} />
          </Section>
        )}

        <Section title="Görüşme Notları">
          <p className="text-[13px] text-gray-700 leading-relaxed whitespace-pre-wrap">{visit.notes}</p>
        </Section>

        {visit.hasProject && (
          <Section title="Proje / Fırsat">
            <Row label="Proje Adı" value={visit.projectName} />
            <Row label="Proje Tipi" value={visit.projectType ? projectTypeLabels[visit.projectType] : undefined} />
            <Row label="Tahmini Tutar" value={visit.estimatedAmount ? `₺${Number(visit.estimatedAmount).toLocaleString('tr-TR')}` : undefined} />
            <Row label="Tahmini Sipariş Tarihi" value={visit.estimatedOrderDate ? new Date(visit.estimatedOrderDate).toLocaleDateString('tr-TR') : undefined} />
            <Row label="İlgili Ürünler" value={visit.relatedProducts} />
            <Row label="Rakip Marka" value={visit.competitorBrand} />
            <Row label="Satış Olasılığı" value={visit.winProbability ? `%${visit.winProbability}` : undefined} />
            {visit.projectDescription && <p className="text-[12.5px] text-gray-600 mt-2">{visit.projectDescription}</p>}
          </Section>
        )}

        {visit.needsFollowUp && (
          <Section title="Takip Aksiyonları">
            <Row label="Takip Tarihi" value={visit.followUpDate ? new Date(visit.followUpDate).toLocaleDateString('tr-TR') : undefined} />
            <Row label="Yapılacak İşlem" value={visit.followUpAction} />
            <Row label="Sorumlu" value={visit.followUpOwner} />
            {visit.followUpNote && <p className="text-[12.5px] text-gray-600 mt-2">{visit.followUpNote}</p>}
            <Badge label={visit.followUpDone ? 'Takip Tamamlandı' : 'Takip Bekliyor'} tone={visit.followUpDone ? 'success' : 'pending'} />
          </Section>
        )}

        {visit.attachments?.length > 0 && (
          <Section title="Ekli Dosyalar">
            <div className="space-y-1.5">
              {visit.attachments.map((f: any) => (
                <a
                  key={f.id}
                  href="#"
                  onClick={async (e) => {
                    e.preventDefault();
                    const res = await api.get(`/dealer-visits/attachments/${f.id}/signed-url`);
                    const opened = window.open(res.data.url, '_blank', 'noopener,noreferrer');
                    if (opened) opened.opener = null;
                  }}
                  className="block text-[12.5px] text-blue-600 hover:underline truncate"
                >
                  📎 {f.fileName}
                </a>
              ))}
            </div>
          </Section>
        )}

        <div className="flex gap-2 mt-6">
          <button onClick={onEdit} className="flex-1 text-sm font-medium text-gray-700 border border-gray-200 rounded-xl py-2.5 hover:bg-gray-50 transition">
            Düzenle
          </button>
          <button onClick={onDelete} className="flex-1 text-sm font-medium text-red-600 border border-gray-200 rounded-xl py-2.5 hover:bg-red-50 transition">
            Sil
          </button>
        </div>
      </div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mt-5 pt-5 border-t border-gray-100">
      <h3 className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide mb-2">{title}</h3>
      {children}
    </div>
  );
}

function Row({ label, value }: { label: string; value?: string | null }) {
  if (!value) return null;
  return (
    <div className="flex justify-between text-[12.5px] py-1">
      <span className="text-gray-400">{label}</span>
      <span className="text-gray-700 font-medium text-right">{value}</span>
    </div>
  );
}

const visitTypeOptions = Object.entries(visitTypeLabels);
const topicOptions = Object.entries(topicLabels);
const outcomeOptions = Object.entries(outcomeLabels);
const projectTypeOptions = Object.entries(projectTypeLabels);
const winProbabilityOptions = [25, 50, 75, 90, 100];

function VisitFormModal({
  dealers,
  existingVisit,
  onClose,
  onSaved,
}: {
  dealers: any[] | undefined;
  existingVisit?: any;
  onClose: () => void;
  onSaved: () => void;
}) {
  const isEditing = !!existingVisit;
  const [form, setForm] = useState({
    visitDate: existingVisit?.visitDate ? existingVisit.visitDate.slice(0, 16) : new Date().toISOString().slice(0, 16),
    dealerId: existingVisit?.dealerId || '',
    dealerNameFreeText: existingVisit?.dealerNameFreeText || '',
    city: existingVisit?.city || '',
    visitType: existingVisit?.visitType || 'DEALER_VISIT',
    contactName: existingVisit?.contactName || '',
    contactTitle: existingVisit?.contactTitle || '',
    contactPhone: existingVisit?.contactPhone || '',
    contactEmail: existingVisit?.contactEmail || '',
    topic: existingVisit?.topic || '',
    outcome: existingVisit?.outcome || 'POSITIVE',
    notes: existingVisit?.notes || '',
    hasProject: existingVisit?.hasProject || false,
    projectName: existingVisit?.projectName || '',
    projectType: existingVisit?.projectType || '',
    estimatedAmount: existingVisit?.estimatedAmount || '',
    estimatedOrderDate: existingVisit?.estimatedOrderDate ? existingVisit.estimatedOrderDate.slice(0, 10) : '',
    relatedProducts: existingVisit?.relatedProducts || '',
    competitorBrand: existingVisit?.competitorBrand || '',
    winProbability: existingVisit?.winProbability || '',
    projectDescription: existingVisit?.projectDescription || '',
    needsFollowUp: existingVisit?.needsFollowUp || false,
    followUpDate: existingVisit?.followUpDate ? existingVisit.followUpDate.slice(0, 10) : '',
    followUpAction: existingVisit?.followUpAction || '',
    followUpOwner: existingVisit?.followUpOwner || '',
    followUpNote: existingVisit?.followUpNote || '',
  });
  const [showOptional, setShowOptional] = useState(isEditing);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  function set<K extends keyof typeof form>(key: K, value: (typeof form)[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  async function submit() {
    if (!form.visitDate || !form.visitType || !form.outcome || !form.notes.trim()) {
      setError('Tarih, ziyaret türü, sonuç ve görüşme notu zorunludur.');
      return;
    }
    if (!form.dealerId && !form.dealerNameFreeText.trim()) {
      setError('Bir bayi seçin ya da bayi adını yazın.');
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      if (isEditing) {
        await api.patch(`/dealer-visits/${existingVisit.id}`, form);
      } else {
        await api.post('/dealer-visits', form);
      }
      onSaved();
    } catch (e: any) {
      setError(e.response?.data?.message || 'Kaydedilemedi.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/30 flex justify-end z-50" onClick={onClose}>
      <div className="bg-white w-full max-w-lg h-full overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-base font-bold text-gray-900 mb-1">{isEditing ? 'Ziyareti Düzenle' : 'Yeni Ziyaret'}</h2>
        <p className="text-[12.5px] text-gray-400 mb-5">Sadece işaretli alanlar zorunludur — hızlıca doldurup kaydedebilirsiniz.</p>

        {error && <p className="text-[12.5px] text-red-600 bg-red-50 rounded-lg px-3 py-2 mb-4">{error}</p>}

        <div className="space-y-4">
          <FormRow label="Ziyaret Tarihi ve Saati *">
            <input type="datetime-local" value={form.visitDate} onChange={(e) => set('visitDate', e.target.value)} className={inputCls} />
          </FormRow>

          <FormRow label="Bayi *">
            <select value={form.dealerId} onChange={(e) => set('dealerId', e.target.value)} className={inputCls}>
              <option value="">Listeden seçin...</option>
              {dealers?.map((d: any) => (
                <option key={d.id} value={d.id}>{d.company}</option>
              ))}
            </select>
            <input
              value={form.dealerNameFreeText}
              onChange={(e) => set('dealerNameFreeText', e.target.value)}
              placeholder="Ya da sistemde yoksa bayi adını yazın"
              className={`${inputCls} mt-2`}
            />
          </FormRow>

          <FormRow label="Şehir">
            <input value={form.city} onChange={(e) => set('city', e.target.value)} className={inputCls} />
          </FormRow>

          <FormRow label="Ziyaret Türü *">
            <select value={form.visitType} onChange={(e) => set('visitType', e.target.value)} className={inputCls}>
              {visitTypeOptions.map(([k, v]) => (
                <option key={k} value={k}>{v}</option>
              ))}
            </select>
          </FormRow>

          <FormRow label="Ziyaret Sonucu *">
            <select value={form.outcome} onChange={(e) => set('outcome', e.target.value)} className={inputCls}>
              {outcomeOptions.map(([k, v]) => (
                <option key={k} value={k}>{v}</option>
              ))}
            </select>
          </FormRow>

          <FormRow label="Görüşme Notları *">
            <textarea
              value={form.notes}
              onChange={(e) => set('notes', e.target.value)}
              rows={4}
              placeholder="Görüşmenin detaylarını yazın..."
              className={inputCls}
            />
          </FormRow>
        </div>

        <button
          onClick={() => setShowOptional((v) => !v)}
          className="text-[12.5px] font-medium text-gray-500 hover:text-gray-800 mt-5 flex items-center gap-1"
        >
          {showOptional ? '− Ek bilgileri gizle' : '+ Görüşme kişisi, proje ve takip bilgisi ekle (isteğe bağlı)'}
        </button>

        {showOptional && (
          <>
            <Section title="Görüşülen Kişi">
              <div className="grid grid-cols-2 gap-2">
                <input value={form.contactName} onChange={(e) => set('contactName', e.target.value)} placeholder="Ad Soyad" className={inputCls} />
                <input value={form.contactTitle} onChange={(e) => set('contactTitle', e.target.value)} placeholder="Görevi" className={inputCls} />
                <input value={form.contactPhone} onChange={(e) => set('contactPhone', e.target.value)} placeholder="Telefon" className={inputCls} />
                <input value={form.contactEmail} onChange={(e) => set('contactEmail', e.target.value)} placeholder="E-posta" className={inputCls} />
              </div>
              <select value={form.topic} onChange={(e) => set('topic', e.target.value)} className={`${inputCls} mt-2`}>
                <option value="">Görüşme konusu seçin...</option>
                {topicOptions.map(([k, v]) => (
                  <option key={k} value={k}>{v}</option>
                ))}
              </select>
            </Section>

            <Section title="Proje / Fırsat">
              <label className="flex items-center gap-2 text-[12.5px] text-gray-600 mb-2">
                <input type="checkbox" checked={form.hasProject} onChange={(e) => set('hasProject', e.target.checked)} />
                Bu ziyarette bir satış fırsatı/proje oluştu
              </label>
              {form.hasProject && (
                <div className="space-y-2">
                  <input value={form.projectName} onChange={(e) => set('projectName', e.target.value)} placeholder="Proje adı" className={inputCls} />
                  <div className="grid grid-cols-2 gap-2">
                    <select value={form.projectType} onChange={(e) => set('projectType', e.target.value)} className={inputCls}>
                      <option value="">Proje tipi</option>
                      {projectTypeOptions.map(([k, v]) => (
                        <option key={k} value={k}>{v}</option>
                      ))}
                    </select>
                    <select value={form.winProbability} onChange={(e) => set('winProbability', e.target.value)} className={inputCls}>
                      <option value="">Satış olasılığı</option>
                      {winProbabilityOptions.map((p) => (
                        <option key={p} value={p}>%{p}</option>
                      ))}
                    </select>
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <input type="number" value={form.estimatedAmount} onChange={(e) => set('estimatedAmount', e.target.value)} placeholder="Tahmini tutar (₺)" className={inputCls} />
                    <input type="date" value={form.estimatedOrderDate} onChange={(e) => set('estimatedOrderDate', e.target.value)} className={inputCls} />
                  </div>
                  <input value={form.relatedProducts} onChange={(e) => set('relatedProducts', e.target.value)} placeholder="İlgili ürünler" className={inputCls} />
                  <input value={form.competitorBrand} onChange={(e) => set('competitorBrand', e.target.value)} placeholder="Rakip marka" className={inputCls} />
                  <textarea value={form.projectDescription} onChange={(e) => set('projectDescription', e.target.value)} placeholder="Açıklama" rows={2} className={inputCls} />
                </div>
              )}
            </Section>

            <Section title="Takip / Aksiyon">
              <label className="flex items-center gap-2 text-[12.5px] text-gray-600 mb-2">
                <input type="checkbox" checked={form.needsFollowUp} onChange={(e) => set('needsFollowUp', e.target.checked)} />
                Takip gerekiyor
              </label>
              {form.needsFollowUp && (
                <div className="space-y-2">
                  <input type="date" value={form.followUpDate} onChange={(e) => set('followUpDate', e.target.value)} className={inputCls} />
                  <input value={form.followUpAction} onChange={(e) => set('followUpAction', e.target.value)} placeholder="Yapılacak işlem" className={inputCls} />
                  <input value={form.followUpOwner} onChange={(e) => set('followUpOwner', e.target.value)} placeholder="Sorumlu kişi" className={inputCls} />
                  <textarea value={form.followUpNote} onChange={(e) => set('followUpNote', e.target.value)} placeholder="Açıklama" rows={2} className={inputCls} />
                </div>
              )}
            </Section>
          </>
        )}

        <div className="flex gap-2 mt-6 sticky bottom-0 bg-white pt-4 pb-1">
          <button onClick={onClose} className="flex-1 text-sm font-medium text-gray-600 border border-gray-200 rounded-xl py-2.5 hover:bg-gray-50 transition">
            Vazgeç
          </button>
          <button
            onClick={submit}
            disabled={submitting}
            className="flex-1 text-sm font-medium text-white bg-gradient-to-r from-brand to-brand-dark rounded-xl py-2.5 hover:opacity-90 transition disabled:opacity-50"
          >
            {submitting ? 'Kaydediliyor...' : 'Kaydet'}
          </button>
        </div>
      </div>
    </div>
  );
}

const inputCls = 'w-full border border-gray-200 rounded-lg px-3 py-2 text-[13px] focus:outline-none focus:ring-2 focus:ring-gray-200';

function FormRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-[12px] font-medium text-gray-500 mb-1.5">{label}</label>
      {children}
    </div>
  );
}

/** Ziyaret listesini CSV'ye aktarır — Excel'de doğrudan açılabilir. */
/** Yöneticilere sunulabilecek profesyonel PDF ziyaret raporu. */
function exportVisitsToPdf(visits: any[], filters: { from: string; to: string }) {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();

  doc.setFontSize(15);
  doc.setFont('helvetica', 'bold');
  doc.text('ENTPA Mühendislik Hizmeti', 14, 18);
  doc.setFontSize(11);
  doc.setFont('helvetica', 'normal');
  doc.text('Bayi Ziyaret Raporu', 14, 25);

  doc.setFontSize(9);
  doc.setTextColor(120);
  const dateRangeLabel = filters.from || filters.to ? `${filters.from || '—'} – ${filters.to || '—'}` : 'Tüm Tarihler';
  doc.text(`Rapor Tarihi: ${new Date().toLocaleDateString('tr-TR')}`, pageWidth - 14, 18, { align: 'right' });
  doc.text(`Tarih Aralığı: ${dateRangeLabel}`, pageWidth - 14, 24, { align: 'right' });

  // Özet bilgiler
  const totalVisits = visits.length;
  const projectsCount = visits.filter((v) => v.hasProject).length;
  const followUpCount = visits.filter((v) => v.needsFollowUp && !v.followUpDone).length;
  const totalOpportunity = visits.reduce((sum, v) => sum + (v.hasProject ? Number(v.estimatedAmount || 0) : 0), 0);
  const salespeople = new Set(visits.map((v) => v.salesperson.id)).size;

  doc.setTextColor(0);
  doc.setFontSize(9);
  doc.setFont('helvetica', 'bold');
  const summaryY = 34;
  doc.text(
    `Toplam Ziyaret: ${totalVisits}   |   Satışçı: ${salespeople}   |   Oluşan Proje: ${projectsCount}   |   Takip Gereken: ${followUpCount}   |   Tahmini Fırsat: ₺${totalOpportunity.toLocaleString('tr-TR')}`,
    14,
    summaryY,
  );

  // Ziyaret listesi tablosu
  autoTable(doc, {
    startY: summaryY + 6,
    head: [['Tarih', 'Satışçı', 'Bayi', 'Şehir', 'Tür', 'Sonuç', 'Takip']],
    body: visits.map((v) => [
      new Date(v.visitDate).toLocaleDateString('tr-TR'),
      `${v.salesperson.firstName} ${v.salesperson.lastName}`,
      v.dealer?.company || v.dealerNameFreeText || '—',
      v.city || '—',
      visitTypeLabels[v.visitType] || v.visitType,
      outcomeLabels[v.outcome] || v.outcome,
      v.needsFollowUp ? 'Evet' : 'Hayır',
    ]),
    styles: { fontSize: 8 },
    headStyles: { fillColor: [11, 27, 43] }, // navy
    margin: { left: 14, right: 14 },
  });

  // Proje/fırsat bilgileri olan ziyaretler ayrı bir bölümde
  const withProjects = visits.filter((v) => v.hasProject);
  if (withProjects.length > 0) {
    const afterTableY = (doc as any).lastAutoTable.finalY + 10;
    doc.setFontSize(11);
    doc.setFont('helvetica', 'bold');
    doc.text('Proje / Fırsat Bilgileri', 14, afterTableY);
    autoTable(doc, {
      startY: afterTableY + 4,
      head: [['Bayi', 'Proje Adı', 'Tahmini Tutar', 'Olasılık', 'Tahmini Tarih']],
      body: withProjects.map((v) => [
        v.dealer?.company || v.dealerNameFreeText || '—',
        v.projectName || '—',
        v.estimatedAmount ? `₺${Number(v.estimatedAmount).toLocaleString('tr-TR')}` : '—',
        v.winProbability ? `%${v.winProbability}` : '—',
        v.estimatedOrderDate ? new Date(v.estimatedOrderDate).toLocaleDateString('tr-TR') : '—',
      ]),
      styles: { fontSize: 8 },
      headStyles: { fillColor: [155, 28, 46] }, // brand bordo
      margin: { left: 14, right: 14 },
    });
  }

  doc.save(`bayi-ziyaret-raporu-${new Date().toISOString().slice(0, 10)}.pdf`);
}

/** Ziyaret listesini CSV'ye aktarır — Excel'de doğrudan açılabilir. */
function exportVisitsToCsv(visits: any[]) {
  const headers = ['Tarih', 'Satışçı', 'Bayi', 'Şehir', 'Ziyaret Türü', 'Görüşülen Kişi', 'Sonuç', 'Takip Gerekiyor Mu', 'Notlar'];
  const rows = visits.map((v) => [
    new Date(v.visitDate).toLocaleDateString('tr-TR'),
    `${v.salesperson.firstName} ${v.salesperson.lastName}`,
    v.dealer?.company || v.dealerNameFreeText || '',
    v.city || '',
    visitTypeLabels[v.visitType] || v.visitType,
    v.contactName || '',
    outcomeLabels[v.outcome] || v.outcome,
    v.needsFollowUp ? 'Evet' : 'Hayır',
    (v.notes || '').replace(/\n/g, ' '),
  ]);
  const csvContent = [headers, ...rows].map((r) => r.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(';')).join('\r\n');
  // ÖNEMLİ: Excel'in Türkçe karakterleri doğru göstermesi için UTF-8 BOM ekleniyor.
  const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `bayi-ziyaretleri-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

function SalespersonPerformanceDrawer({ salesperson, onClose }: { salesperson: any; onClose: () => void }) {
  const { data: perf, isLoading } = useSWR(`/dealer-visits/salesperson/${salesperson.id}/performance`, fetcher);

  return (
    <div className="fixed inset-0 bg-black/30 flex justify-end z-50" onClick={onClose}>
      <div className="bg-white w-full max-w-md h-full overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between mb-1">
          <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide">Satışçı Ziyaret Performansı</p>
          <button onClick={onClose} className="text-gray-300 hover:text-gray-600">✕</button>
        </div>
        <h2 className="text-lg font-bold text-gray-900">{salesperson.firstName} {salesperson.lastName}</h2>

        {isLoading ? (
          <p className="text-[13px] text-gray-400 mt-6">Yükleniyor...</p>
        ) : (
          <>
            <div className="grid grid-cols-2 gap-2.5 mt-5">
              <PerfTile label="Toplam Ziyaret" value={perf.totalVisits} />
              <PerfTile label="Bu Ay" value={perf.visitsThisMonth} />
              <PerfTile label="Bu Hafta" value={perf.visitsThisWeek} />
              <PerfTile label="Olumlu Görüşme" value={perf.positiveOutcomes} />
              <PerfTile label="Oluşan Proje" value={perf.projectsCreated} />
              <PerfTile label="Takip Gereken" value={perf.needsFollowUp} />
            </div>
            <div className="mt-3 bg-gradient-to-br from-emerald-500 to-teal-600 rounded-xl p-4 text-white">
              <p className="text-[11px] opacity-80">Tahmini Fırsat Tutarı</p>
              <p className="text-[22px] font-bold mt-1">₺{Number(perf.estimatedOpportunity || 0).toLocaleString('tr-TR')}</p>
            </div>

            <Section title="Son Ziyaretler">
              {perf.recentVisits?.length ? (
                <div className="space-y-2">
                  {perf.recentVisits.map((v: any) => (
                    <div key={v.id} className="flex justify-between text-[12.5px] py-1.5 border-b border-gray-50 last:border-0">
                      <span className="text-gray-700 truncate">{v.dealer?.company || v.dealerNameFreeText}</span>
                      <span className="text-gray-400 shrink-0 ml-2">{new Date(v.visitDate).toLocaleDateString('tr-TR')}</span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-[12.5px] text-gray-400">Henüz ziyaret yok.</p>
              )}
            </Section>
          </>
        )}
      </div>
    </div>
  );
}

function PerfTile({ label, value }: { label: string; value: number }) {
  return (
    <div className="bg-gray-50 rounded-lg p-3">
      <p className="text-[10.5px] text-gray-400">{label}</p>
      <p className="text-[18px] font-bold text-gray-900 mt-0.5">{value ?? 0}</p>
    </div>
  );
}

function DealerHistoryDrawer({ dealerId, onClose }: { dealerId: string; onClose: () => void }) {
  const { data: history, isLoading } = useSWR(`/dealer-visits/dealer/${dealerId}/history`, fetcher);

  return (
    <div className="fixed inset-0 bg-black/30 flex justify-end z-50" onClick={onClose}>
      <div className="bg-white w-full max-w-md h-full overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between mb-1">
          <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wide">Bayi Ziyaret Geçmişi</p>
          <button onClick={onClose} className="text-gray-300 hover:text-gray-600">✕</button>
        </div>

        {isLoading ? (
          <p className="text-[13px] text-gray-400 mt-6">Yükleniyor...</p>
        ) : (
          <>
            <h2 className="text-lg font-bold text-gray-900">{history.visits[0]?.dealer?.company || 'Bayi'}</h2>
            <p className="text-[12.5px] text-gray-400 mt-1">
              Toplam ziyaret: {history.totalVisits} · Son ziyaret: {history.lastVisitDate ? new Date(history.lastVisitDate).toLocaleDateString('tr-TR') : '—'}
            </p>

            <div className="mt-5 relative pl-5">
              <div className="absolute left-[5px] top-1 bottom-1 w-px bg-gray-200" />
              {history.visits.map((v: any) => (
                <div key={v.id} className="relative mb-4 last:mb-0">
                  <span className="absolute -left-5 top-1 w-2.5 h-2.5 rounded-full bg-blue-500 ring-2 ring-white" />
                  <p className="text-[12.5px] font-semibold text-gray-800">{new Date(v.visitDate).toLocaleDateString('tr-TR')}</p>
                  <p className="text-[12px] text-gray-500">{v.salesperson.firstName} {v.salesperson.lastName}</p>
                  <p className="text-[12px] text-gray-400">{visitTypeLabels[v.visitType] || v.visitType}</p>
                </div>
              ))}
              {history.visits.length === 0 && <p className="text-[12.5px] text-gray-400">Henüz ziyaret kaydı yok.</p>}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
