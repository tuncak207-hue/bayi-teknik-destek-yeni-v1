'use client';

import { useState } from 'react';
import Link from 'next/link';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { IconUsers, IconDocument, IconCalendar, IconChat } from '@/components/icons';
import { Card, Badge, IconBadge, type IconColor } from '@/components/ui';

const statColorCycle: IconColor[] = ['blue', 'violet', 'amber', 'emerald', 'rose', 'cyan'];

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function DashboardPage() {
  const { data: s } = useSWR('/stats/dashboard', fetcher, { refreshInterval: 30000 });
  const { data: priorities } = useSWR('/dashboard/admin-priorities', fetcher, { refreshInterval: 30000 });
  const { data: visitSummary } = useSWR('/dealer-visits/dashboard-summary', fetcher, { refreshInterval: 30000 });

  const severityTone: Record<string, 'danger' | 'pending' | 'neutral'> = {
    critical: 'danger',
    high: 'pending',
    medium: 'neutral',
  };

  // "Bugün Ne Yapmalıyım" öğelerine tıklanınca ilgili sayfaya götürür.
  function priorityHref(label: string): string {
    if (label.includes('Randevu')) return '/appointments';
    return '/support-tickets';
  }

  // "Son Aktivite" öğesine tıklanınca ilgili sayfaya götürür — Bayilere
  // Sor gönderilerinin admin panelde ayrı bir sayfası olmadığı için
  // "community" türü tıklanabilir değil.
  function activityHref(type: string): string | null {
    switch (type) {
      case 'dealer':
        return '/dealers';
      case 'document':
        return '/documents';
      case 'appointment':
        return '/appointments';
      default:
        return null;
    }
  }

  return (
    <div>
      <p className="text-[13px] text-gray-400 mb-4">Uygulamanın tüm modüllerine dair anlık özet — 30 saniyede bir otomatik yenilenir.</p>

      {/* Büyük, renkli "hero" istatistik kartları. */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-5">
        <HeroStat label="Aktif Bayi" value={s?.dealers?.active} icon={<IconUsers width={18} height={18} />} color="blue" href="/dealers" />
        <HeroStat label="Bugün AI Soruları" value={s?.messaging?.aiQuestionsToday} icon={<IconChat width={18} height={18} />} color="violet" href="/chats" />
        <HeroStat
          label="Onay Bekleyen Randevu"
          value={s?.appointments?.pending}
          icon={<IconCalendar width={18} height={18} />}
          color="amber"
          href="/appointments"
          highlight={!!s?.appointments?.pending}
        />
        <HeroStat label="Toplam Doküman" value={s?.documents?.total} icon={<IconDocument width={18} height={18} />} color="emerald" href="/documents" />
      </div>

      {priorities?.priorities?.length > 0 && (
        <Card className="p-4 mb-4">
          <h3 className="text-[13px] font-semibold text-gray-900 mb-2.5">Bugün Ne Yapmalıyım?</h3>
          <div className="space-y-1.5">
            {priorities.priorities.map((p: any, i: number) => (
              <Link
                key={i}
                href={priorityHref(p.label)}
                className="flex items-center justify-between px-3 h-9 rounded-lg bg-gray-50/70 hover:bg-gray-100 transition-colors"
              >
                <span className="text-[12.5px] font-medium text-gray-700">{i + 1}. {p.label}</span>
                <Badge label={String(p.count)} tone={severityTone[p.severity] ?? 'neutral'} />
              </Link>
            ))}
          </div>
        </Card>
      )}

      <Section
        title="Bayiler"
        href="/dealers"
        summary={`${s?.dealers?.active ?? '—'} aktif`}
        urgentCount={s?.dealers?.pending}
        defaultOpen
      >
        <StatTile label="Aktif Bayi" value={s?.dealers?.active} color="emerald" />
        <StatTile label="Onay Bekleyen" value={s?.dealers?.pending} color="amber" urgent={!!s?.dealers?.pending} />
        <StatTile label="Pasifleştirilen" value={s?.dealers?.suspended} color="navy" />
        <StatTile label="Bu Hafta Yeni Kayıt" value={s?.dealers?.newThisWeek} color="blue" />
      </Section>

      <Section
        title="Bayi Ziyaretleri"
        href="/dealer-visits"
        summary={`${visitSummary?.visitsThisMonth ?? '—'} bu ay`}
        urgentCount={visitSummary?.needsFollowUp}
        defaultOpen
      >
        <StatTile label="Bu Ay Ziyaret" value={visitSummary?.visitsThisMonth} color="blue" />
        <StatTile label="Aktif Satışçı" value={visitSummary?.activeSalespeople} color="violet" />
        <StatTile label="Takip Gereken" value={visitSummary?.needsFollowUp} color="amber" urgent={!!visitSummary?.needsFollowUp} />
        <StatTile label="Oluşan Proje" value={visitSummary?.projectsCreated} color="emerald" />
      </Section>

      <Section title="Dokümanlar" href="/documents" summary={`${s?.documents?.total ?? '—'} doküman`} urgentCount={s?.documents?.error} defaultOpen>
        <StatTile label="Toplam Doküman" value={s?.documents?.total} color="emerald" />
        <StatTile label="İşleniyor" value={s?.documents?.processing} color="amber" />
        <StatTile label="Hata Alan" value={s?.documents?.error} color="rose" urgent={!!s?.documents?.error} />
      </Section>

      <Section title="Mesajlaşma & AI" href="/chats" summary={`${s?.messaging?.aiQuestionsToday ?? '—'} soru bugün`} urgentCount={s?.messaging?.activeChatBans} defaultOpen>
        <StatTile label="Bugünkü AI Soruları" value={s?.messaging?.aiQuestionsToday} color="violet" />
        <StatTile label="Bu Hafta AI Soruları" value={s?.messaging?.aiQuestionsThisWeek} color="violet" />
        <StatTile label="Aktif Sohbet (24s)" value={s?.messaging?.activeConversations} color="emerald" />
        <StatTile label="Bu Hafta Mesaj" value={s?.messaging?.totalMessagesThisWeek} color="blue" />
        <StatTile label="Birebir Sohbet" value={s?.messaging?.directConversations} color="cyan" />
        <StatTile label="Grup Sohbeti" value={s?.messaging?.groupConversations} color="cyan" />
        <StatTile
          label="Aktif Konuşma Yasağı"
          value={s?.messaging?.activeChatBans}
          color="rose"
          urgent={!!s?.messaging?.activeChatBans}
        />
      </Section>

      <Section title="Randevular" href="/appointments" summary={`${s?.appointments?.confirmedUpcoming ?? '—'} yaklaşan`} urgentCount={s?.appointments?.pending} defaultOpen>
        <StatTile label="Onay Bekleyen" value={s?.appointments?.pending} color="amber" urgent={!!s?.appointments?.pending} />
        <StatTile label="Onaylı (Yaklaşan)" value={s?.appointments?.confirmedUpcoming} color="emerald" />
        <StatTile label="Bu Ay Tamamlanan" value={s?.appointments?.completedThisMonth} color="blue" />
      </Section>

      <Section
        title="Topluluk & Duyurular"
        summary={`${s?.community?.totalPosts ?? '—'} gönderi`}
        urgentCount={s?.announcements?.criticalUnacknowledged}
        defaultOpen
      >
        <StatTile label="Bayilere Sor Gönderisi" value={s?.community?.totalPosts} color="blue" />
        <StatTile label="Bu Hafta Yeni Gönderi" value={s?.community?.postsThisWeek} color="blue" />
        <StatTile label="Toplam Yorum" value={s?.community?.totalComments} color="cyan" />
        <StatTile label="Toplam Duyuru" value={s?.announcements?.total} color="violet" />
        <StatTile
          label="Onaylanmamış Kritik Duyuru"
          value={s?.announcements?.criticalUnacknowledged}
          color="rose"
          urgent={!!s?.announcements?.criticalUnacknowledged}
        />
      </Section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3 mt-5">
        <Panel title="Satışçı Bazlı Ziyaretler (Bu Ay)">
          {visitSummary?.bySalesperson?.length ? (
            <div className="space-y-2.5">
              {visitSummary.bySalesperson.map((sp: any, i: number) => {
                const max = visitSummary.bySalesperson[0]?.count || 1;
                return (
                  <div key={sp.salespersonId}>
                    <div className="flex justify-between text-[12.5px] mb-1">
                      <span className="font-medium text-gray-700 truncate">{sp.name}</span>
                      <span className="text-gray-500 font-semibold">{sp.count}</span>
                    </div>
                    <div className="h-1.5 bg-gray-100 rounded-full overflow-hidden">
                      <div
                        className={`h-full rounded-full bg-gradient-to-r ${
                          i === 0 ? 'from-blue-500 to-blue-600' : i === 1 ? 'from-violet-500 to-purple-600' : 'from-emerald-500 to-teal-600'
                        }`}
                        style={{ width: `${Math.max(6, (sp.count / max) * 100)}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <EmptyRow text="Bu ay henüz ziyaret kaydı yok." />
          )}
        </Panel>

        <Panel title="En Çok Favorilenen Dokümanlar">
          {s?.documents?.topFavorited?.length ? (
            <div className="space-y-2">
              {s.documents.topFavorited.map((d: any, i: number) => (
                <div key={d.id} className="flex items-center gap-3 p-2 rounded-lg hover:bg-gray-50 transition-colors">
                  <IconBadge icon={<IconDocument width={14} height={14} />} color={statColorCycle[i % statColorCycle.length]} size="sm" />
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-gray-800 truncate text-[13px]">{d.title}</div>
                    <div className="text-gray-400 text-[11.5px] mt-0.5">
                      {d.brand} / {d.model}
                    </div>
                  </div>
                  <span className="text-gray-600 font-semibold text-[12.5px] shrink-0 bg-gray-100 px-1.5 py-0.5 rounded">
                    {d.favoriteCount}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <EmptyRow text="Henüz favorilenen doküman yok." />
          )}
        </Panel>

        <Panel title="Son Aktivite">
          {s?.recentActivity?.length ? (
            <ul className="divide-y divide-gray-100">
              {s.recentActivity.map((a: any) => {
                const href = activityHref(a.type);
                const content = (
                  <>
                    <div className="w-6 h-6 rounded-md bg-gray-100 flex items-center justify-center shrink-0 mt-0.5 text-gray-500">
                      <ActivityIcon type={a.type} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-gray-800 truncate text-[13px]">{a.label}</div>
                      <div className="text-gray-400 text-[11.5px] mt-0.5">
                        {a.detail} · {new Date(a.createdAt).toLocaleString('tr-TR')}
                      </div>
                    </div>
                  </>
                );
                return href ? (
                  <Link key={`${a.type}-${a.id}`} href={href} className="py-2.5 flex items-start gap-2.5 hover:bg-gray-50 -mx-2 px-2 rounded-lg transition-colors">
                    {content}
                  </Link>
                ) : (
                  <li key={`${a.type}-${a.id}`} className="py-2.5 flex items-start gap-2.5">
                    {content}
                  </li>
                );
              })}
            </ul>
          ) : (
            <EmptyRow text="Henüz aktivite yok." />
          )}
        </Panel>
      </div>
    </div>
  );
}

function ActivityIcon({ type }: { type: string }) {
  const size = { width: 12, height: 12 };
  switch (type) {
    case 'dealer':
      return <IconUsers {...size} />;
    case 'document':
      return <IconDocument {...size} />;
    case 'appointment':
      return <IconCalendar {...size} />;
    case 'community':
      return <IconChat {...size} />;
    default:
      return <span className="w-1 h-1 rounded-full bg-gray-400 inline-block" />;
  }
}

function EmptyRow({ text }: { text: string }) {
  return <p className="text-[13px] text-gray-400 py-4">{text}</p>;
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200/70 p-4">
      <h3 className="text-[13px] font-semibold text-gray-800 mb-1">{title}</h3>
      {children}
    </div>
  );
}

function Section({
  title,
  href,
  summary,
  urgentCount,
  defaultOpen = false,
  children,
}: {
  title: string;
  href?: string;
  summary?: string;
  urgentCount?: number;
  defaultOpen?: boolean;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="bg-white rounded-xl border border-gray-200/70 mb-3 overflow-hidden">
      <button
        onClick={() => setOpen((v) => !v)}
        className="w-full flex items-center justify-between px-4 h-11 text-left hover:bg-gray-50/70 transition-colors"
      >
        <div className="flex items-center gap-2.5">
          <h3 className="text-[13px] font-semibold text-gray-900">{title}</h3>
          {summary && <span className="text-[12px] text-gray-400">{summary}</span>}
          {!!urgentCount && (
            <span className="text-[10px] font-medium text-red-700 bg-red-50 ring-1 ring-inset ring-red-600/15 px-1.5 py-0.5 rounded">{urgentCount} bekliyor</span>
          )}
        </div>
        <div className="flex items-center gap-3 shrink-0">
          {href && (
            <Link
              href={href}
              onClick={(e) => e.stopPropagation()}
              className="text-[12px] text-gray-400 hover:text-gray-700 font-medium transition-colors"
            >
              Tümünü gör →
            </Link>
          )}
          <svg
            width="13"
            height="13"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            className={`text-gray-300 transition-transform ${open ? 'rotate-180' : ''}`}
          >
            <path d="M6 9l6 6 6-6" />
          </svg>
        </div>
      </button>
      {open && (
        <div className="px-4 pb-4 pt-0.5 border-t border-gray-100">
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-2.5 mt-3">{children}</div>
        </div>
      )}
    </div>
  );
}

/** Renkli, ikon rozetli istatistik karosu — "göz kamaştırıcı" kart dili. */
function StatTile({
  label,
  value,
  color,
  urgent = false,
}: {
  label: string;
  value: number | undefined;
  color: IconColor;
  urgent?: boolean;
}) {
  return (
    <div className={`relative bg-white rounded-xl p-3 border flex items-center gap-2.5 ${urgent ? 'border-amber-200 bg-amber-50/30' : 'border-gray-100'}`}>
      <IconBadge icon={<span className="w-1.5 h-1.5 rounded-full bg-white/90 block" />} color={color} size="sm" />
      <div className="min-w-0">
        <p className="text-[10.5px] text-gray-400 leading-tight truncate">{label}</p>
        <p className="text-[17px] font-bold text-gray-900 tabular-nums leading-tight mt-0.5">{value ?? '—'}</p>
      </div>
      {urgent && <span className="absolute top-2 right-2 w-1.5 h-1.5 rounded-full bg-amber-500" />}
    </div>
  );
}

const accentClasses: Record<string, string> = {
  navy: 'text-gray-900',
  brand: 'text-brand',
  green: 'text-emerald-600',
  amber: 'text-amber-600',
  red: 'text-red-600',
  gray: 'text-gray-500',
};

function StatCard({
  label,
  value,
  accent = 'navy',
  urgent = false,
}: {
  label: string;
  value: number | undefined;
  accent?: keyof typeof accentClasses;
  urgent?: boolean;
}) {
  return (
    <div className={`relative bg-white rounded-lg p-3 border ${urgent ? 'border-red-200/70 bg-red-50/30' : 'border-gray-100'}`}>
      {urgent && <span className="absolute top-2.5 right-2.5 w-1.5 h-1.5 rounded-full bg-red-500" />}
      <p className="text-[11px] text-gray-400 leading-tight">{label}</p>
      <p className={`text-[19px] font-semibold mt-1.5 tabular-nums ${accentClasses[accent]}`}>{value ?? '—'}</p>
    </div>
  );
}

/** Büyük, renkli hero istatistik kartı — kullanıcı isteği: "göz kamaştırıcı" olsun. */
function HeroStat({
  label,
  value,
  icon,
  color,
  href,
  highlight = false,
}: {
  label: string;
  value: number | undefined;
  icon: React.ReactNode;
  color: IconColor;
  href: string;
  highlight?: boolean;
}) {
  return (
    <Link
      href={href}
      className={`relative bg-white rounded-2xl border p-4 flex items-center gap-3 hover:shadow-md hover:-translate-y-0.5 transition-all ${
        highlight ? 'border-amber-200 bg-gradient-to-br from-amber-50/60 to-white' : 'border-gray-200/70'
      }`}
    >
      <IconBadge icon={icon} color={color} size="lg" />
      <div className="min-w-0">
        <p className="text-[11.5px] text-gray-400 font-medium truncate">{label}</p>
        <p className="text-[26px] font-bold text-gray-900 tabular-nums leading-tight mt-0.5">{value ?? '—'}</p>
      </div>
      {highlight && <span className="absolute top-3 right-3 w-2 h-2 rounded-full bg-amber-500 animate-pulse" />}
    </Link>
  );
}
