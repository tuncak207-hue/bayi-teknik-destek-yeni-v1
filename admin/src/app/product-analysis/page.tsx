'use client';

import { useState, Fragment } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const levelColors: Record<string, string> = {
  'İyi': 'bg-green-100 text-green-700',
  'İzlenmeli': 'bg-yellow-100 text-yellow-700',
  'Riskli': 'bg-orange-100 text-orange-700',
  'Kritik': 'bg-red-100 text-red-700',
};

export default function ProductAnalysisPage() {
  const { data: healthScores } = useSWR('/support-tickets/reports/product-health', fetcher);
  const { data: rndAlerts } = useSWR('/support-tickets/reports/rnd-feedback', fetcher);
  const [versionQuery, setVersionQuery] = useState('');
  const [versionData, setVersionData] = useState<any>(null);
  const [expandedSerial, setExpandedSerial] = useState<string | null>(null);

  async function searchVersion(e: React.FormEvent) {
    e.preventDefault();
    if (!versionQuery.trim()) return;
    const res = await api.get(`/support-tickets/reports/version-analysis/${encodeURIComponent(versionQuery.trim())}`);
    setVersionData(res.data);
  }

  return (
    <div>
      <p className="text-sm text-gray-500 mb-6">Ürün sağlık skorları, versiyon karşılaştırması ve AR-GE'ye otomatik geri bildirim uyarıları.</p>

      {rndAlerts?.length > 0 && (
        <div className="bg-white rounded-lg border border-red-200 p-6 mb-8">
          <h3 className="text-sm font-bold text-red-700 mb-3">🔬 AR-GE Geri Bildirim Uyarıları</h3>
          <p className="text-xs text-gray-400 mb-4">Son 30 günde 5+ kayıt ve 3+ farklı bayide görülen ürün/model kombinasyonları — ürün problemi olabilir.</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {rndAlerts.map((a: any, i: number) => (
              <div key={i} className="bg-red-50 rounded-xl p-4 border border-red-100">
                <p className="font-semibold text-gray-800">{a.productName} {a.productModel && <span className="text-gray-500">({a.productModel})</span>}</p>
                <p className="text-xs text-gray-500 mt-1">
                  {a.ticketCount} kayıt · {a.dealerCount} bayide · {a.regionCount} bölgede görüldü
                </p>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="bg-white rounded-lg border border-gray-100 p-6 mb-8">
        <h3 className="text-sm font-bold text-gray-700 mb-3">Ürün Versiyon Analizi</h3>
        <form onSubmit={searchVersion} className="flex gap-2 mb-4">
          <input
            value={versionQuery}
            onChange={(e) => setVersionQuery(e.target.value)}
            placeholder="Ürün adı girin (örn. MA8000)"
            className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm"
          />
          <button type="submit" className="text-sm font-medium text-white bg-navy px-4 py-2 rounded-lg hover:bg-navy-light transition">
            Analiz Et
          </button>
        </form>
        {versionData && (
          <div>
            {versionData.improvementRate !== null && (
              <p className="text-xs text-gray-500 mb-3">
                En kötü versiyona göre en iyi versiyonda <span className="font-bold text-green-700">%{versionData.improvementRate}</span> iyileşme var.
              </p>
            )}
            <div className="space-y-2">
              {versionData.versions.map((v: any) => (
                <div key={v.version} className="flex items-center justify-between px-3 py-2 bg-gray-50 rounded-lg">
                  <span className="text-sm font-medium text-gray-700">{v.version}</span>
                  <span className="text-sm font-bold text-gray-800">{v.faultCount} arıza</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="bg-white rounded-lg border border-gray-100 overflow-hidden">
        <div className="p-4 border-b border-gray-100">
          <h3 className="text-sm font-bold text-gray-700">Ürün Sağlık Skorları</h3>
        </div>
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-left">
            <tr>
              <th className="px-4 py-3">Ürün</th>
              <th className="px-4 py-3">Seri No</th>
              <th className="px-4 py-3">Skor</th>
              <th className="px-4 py-3">Durum</th>
              <th className="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            {healthScores?.map((h: any) => (
              <Fragment key={h.serialNumber}>
                <tr className="border-t border-gray-100">
                  <td className="px-4 py-3">{h.productName} {h.productModel && <span className="text-gray-400">({h.productModel})</span>}</td>
                  <td className="px-4 py-3 text-gray-500">{h.serialNumber}</td>
                  <td className="px-4 py-3 font-bold">{h.score}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs font-bold px-2 py-1 rounded-full ${levelColors[h.level]}`}>{h.level}</span>
                  </td>
                  <td className="px-4 py-3">
                    <button
                      onClick={() => setExpandedSerial(expandedSerial === h.serialNumber ? null : h.serialNumber)}
                      className="text-xs text-navy hover:underline"
                    >
                      {expandedSerial === h.serialNumber ? 'Gizle' : 'Neden?'}
                    </button>
                  </td>
                </tr>
                {expandedSerial === h.serialNumber && (
                  <tr className="bg-gray-50">
                    <td colSpan={5} className="px-4 py-3">
                      <div className="flex flex-wrap gap-2">
                        {h.deductions.map((d: any, i: number) => (
                          <span key={i} className="text-xs bg-white border border-gray-200 rounded-full px-3 py-1">
                            {d.reason}: <span className="font-bold text-red-600">-{d.points}</span>
                          </span>
                        ))}
                      </div>
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
        {(!healthScores || healthScores.length === 0) && <p className="p-6 text-center text-gray-400">Henüz seri numaralı bir kayıt yok.</p>}
      </div>
    </div>
  );
}
