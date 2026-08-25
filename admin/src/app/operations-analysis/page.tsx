'use client';

import useSWR from 'swr';
import { api } from '@/lib/api';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

function HeatBar({ label, count, max }: { label: string; count: number; max: number }) {
  const pct = max > 0 ? Math.round((count / max) * 100) : 0;
  return (
    <div className="mb-2.5">
      <div className="flex items-center justify-between mb-1">
        <span className="text-sm text-gray-700">{label}</span>
        <span className="text-sm font-bold text-gray-800">{count}</span>
      </div>
      <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
        <div
          className="h-full rounded-full"
          style={{
            width: `${pct}%`,
            background: pct > 66 ? '#DC2626' : pct > 33 ? '#F59E0B' : '#9B1C2E',
          }}
        />
      </div>
    </div>
  );
}

export default function OperationsAnalysisPage() {
  const { data: heatMap } = useSWR('/support-tickets/reports/heat-map', fetcher);
  const { data: anomalies } = useSWR('/support-tickets/reports/anomalies', fetcher);
  const { data: forecast } = useSWR('/support-tickets/reports/spare-part-forecast', fetcher);
  const { data: competency } = useSWR('/support-tickets/reports/competency', fetcher);
  const { data: sevenDay } = useSWR('/support-tickets/reports/seven-day-forecast', fetcher);

  const maxLocation = heatMap?.byLocation?.[0]?.count ?? 1;
  const maxProduct = heatMap?.byProduct?.[0]?.count ?? 1;
  const maxDealer = heatMap?.byDealer?.[0]?.count ?? 1;

  return (
    <div>
      <p className="text-sm text-gray-500 mb-6">
        Teknik yoğunluk analizi, anomali tespiti ve yedek parça talep tahmini.
      </p>

      {sevenDay && (
        <div className="bg-white rounded-lg border border-gray-100 p-6 mb-8">
          <h3 className="text-sm font-bold text-gray-700 mb-1">📅 Önümüzdeki 7 Gün Tahmini</h3>
          <p className="text-[11px] text-amber-700 bg-amber-50 border border-amber-100 rounded-lg px-3 py-2 mb-4">
            ⚠️ {sevenDay.disclaimer}
          </p>
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-gray-50 rounded-xl p-4">
              <p className="text-xs text-gray-400 mb-1">Beklenen Teknik Destek Yoğunluğu</p>
              <p className="text-2xl font-bold text-gray-800">{sevenDay.expectedTicketVolume.estimate}</p>
              <p className="text-[10px] text-gray-400 mt-1">{sevenDay.expectedTicketVolume.basis}</p>
            </div>
            <div className="bg-gray-50 rounded-xl p-4">
              <p className="text-xs text-gray-400 mb-1">Beklenen Saha Ziyareti</p>
              <p className="text-2xl font-bold text-gray-800">{sevenDay.expectedSiteVisits.estimate}</p>
              <p className="text-[10px] text-gray-400 mt-1">{sevenDay.expectedSiteVisits.basis}</p>
            </div>
          </div>
        </div>
      )}

      {competency?.length > 0 && (
        <div className="bg-white rounded-lg border border-gray-100 overflow-hidden mb-8">
          <div className="p-4 border-b border-gray-100">
            <h3 className="text-sm font-bold text-gray-700">Teknik Yetkinlik Analizi</h3>
            <p className="text-[11px] text-gray-400 mt-1">Not: Sınav/quiz sistemi ve dokümantasyon kalitesi verisi bulunmadığından bu kriterler skora dahil edilemedi.</p>
          </div>
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-left">
              <tr>
                <th className="px-4 py-3">Bayi</th>
                <th className="px-4 py-3">Kayıt Sayısı</th>
                <th className="px-4 py-3">İlk Müdahale Çözüm Oranı</th>
                <th className="px-4 py-3">Tekrar Eden Hata</th>
                <th className="px-4 py-3">Skor</th>
              </tr>
            </thead>
            <tbody>
              {competency.map((c: any) => (
                <tr key={c.dealerId} className="border-t border-gray-100">
                  <td className="px-4 py-3">{c.dealerName}</td>
                  <td className="px-4 py-3">{c.ticketCount}</td>
                  <td className="px-4 py-3">%{c.firstTimeResolutionRate}</td>
                  <td className="px-4 py-3">{c.repeatedFaultCount}</td>
                  <td className="px-4 py-3 font-bold">{c.score}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {anomalies?.length > 0 && (
        <div className="bg-white rounded-lg border border-orange-200 p-6 mb-8">
          <h3 className="text-sm font-bold text-orange-700 mb-3">🔍 Tespit Edilen Anomaliler</h3>
          <div className="space-y-2">
            {anomalies.map((a: any, i: number) => (
              <div key={i} className="px-4 py-2.5 bg-orange-50 border border-orange-100 rounded-xl text-sm text-orange-800">
                {a.description}
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-8">
        <div className="bg-white rounded-lg border border-gray-100 p-5">
          <h3 className="text-sm font-bold text-gray-700 mb-4">Konum Bazlı Yoğunluk</h3>
          <p className="text-[11px] text-gray-400 mb-3">
            Not: Kayıtlardaki serbest metin konum bilgisine göre — coğrafi harita yerine yoğunluk çubuğu olarak gösteriliyor.
          </p>
          {heatMap?.byLocation?.slice(0, 8).map((l: any) => (
            <HeatBar key={l.label} label={l.label} count={l.count} max={maxLocation} />
          ))}
          {(!heatMap?.byLocation || heatMap.byLocation.length === 0) && <p className="text-xs text-gray-400">Henüz konum bilgisi olan kayıt yok.</p>}
        </div>

        <div className="bg-white rounded-lg border border-gray-100 p-5">
          <h3 className="text-sm font-bold text-gray-700 mb-4">Ürün Bazlı Problemler</h3>
          {heatMap?.byProduct?.slice(0, 8).map((p: any) => (
            <HeatBar key={p.label} label={p.label} count={p.count} max={maxProduct} />
          ))}
          {(!heatMap?.byProduct || heatMap.byProduct.length === 0) && <p className="text-xs text-gray-400">Henüz ürün bilgisi olan kayıt yok.</p>}
        </div>

        <div className="bg-white rounded-lg border border-gray-100 p-5">
          <h3 className="text-sm font-bold text-gray-700 mb-4">Bayi Bazlı Destek Yoğunluğu</h3>
          {heatMap?.byDealer?.slice(0, 8).map((d: any) => (
            <HeatBar key={d.name} label={d.name} count={d.count} max={maxDealer} />
          ))}
          {(!heatMap?.byDealer || heatMap.byDealer.length === 0) && <p className="text-xs text-gray-400">Henüz kayıt yok.</p>}
        </div>
      </div>

      <div className="bg-white rounded-lg border border-gray-100 overflow-hidden">
        <div className="p-4 border-b border-gray-100">
          <h3 className="text-sm font-bold text-gray-700">Yedek Parça Talep Tahmini</h3>
          <p className="text-[11px] text-gray-400 mt-1">
            Son 6 aylık talep geçmişine dayalı basit projeksiyon. Stok/envanter verisi bulunmadığı için kritik stok riski hesaplanamıyor.
          </p>
        </div>
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th className="px-4 py-3">Parça</th>
              <th className="px-4 py-3">Ürün</th>
              <th className="px-4 py-3">Son 6 Ay Toplam</th>
              <th className="px-4 py-3">Gelecek Ay Tahmini</th>
            </tr>
          </thead>
          <tbody>
            {forecast?.map((f: any) => (
              <tr key={f.partName} className="border-t border-gray-100">
                <td className="px-4 py-3 font-medium">{f.partName}</td>
                <td className="px-4 py-3 text-gray-500">{f.productName || '—'}</td>
                <td className="px-4 py-3">{f.last6MonthsQuantity}</td>
                <td className="px-4 py-3 font-bold text-brand">{f.estimatedNextMonthQuantity}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!forecast || forecast.length === 0) && <p className="p-6 text-center text-gray-400">Henüz yedek parça talep geçmişi yok.</p>}
      </div>
    </div>
  );
}
