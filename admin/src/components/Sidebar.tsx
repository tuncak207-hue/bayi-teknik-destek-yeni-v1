'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import useSWR from 'swr';
import { api } from '@/lib/api';
import {
  IconDashboard,
  IconUsers,
  IconDocument,
  IconChat,
  IconCalendar,
  IconGroups,
  IconBriefcase,
  IconSchool,
  IconAlertTriangle,
  IconChart,
  IconMap,
  IconMapPin,
  IconBrain,
  IconReceipt,
  IconMegaphone,
  IconImage,
  IconClock,
  IconScroll,
  IconSettings,
} from './icons';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const badgeKeyByHref: Record<string, string> = {
  '/dealers': 'dealers',
  '/appointments': 'appointments',
  '/support-tickets': 'supportTickets',
  '/quotes': 'quotes',
};

const items = [
  { href: '/', label: 'Genel Bakış', Icon: IconDashboard },
  { href: '/dealers', label: 'Bayiler', Icon: IconUsers },
  { href: '/documents', label: 'Dokümanlar', Icon: IconDocument },
  { href: '/slides', label: 'Ana Sayfa Slaytları', Icon: IconImage },
  { href: '/chats', label: 'Sohbetler', Icon: IconChat },
  { href: '/appointments', label: 'Randevular', Icon: IconCalendar },
  { href: '/groups', label: 'Gruplar', Icon: IconGroups },
  { href: '/sales-consultants', label: 'Satış Danışmanları', Icon: IconBriefcase },
  { href: '/dealer-visits', label: 'Bayi Ziyaretleri', Icon: IconMapPin },
  { href: '/training', label: 'Eğitim Merkezi', Icon: IconSchool },
  { href: '/support-tickets', label: 'Teknik Destek', Icon: IconAlertTriangle },
  { href: '/ai-memory', label: 'AI Teknik Hafıza', Icon: IconBrain },
  { href: '/product-analysis', label: 'Ürün Analizi', Icon: IconChart },
  { href: '/operations-analysis', label: 'Operasyon Analizi', Icon: IconMap },
  { href: '/quotes', label: 'Teklif Al', Icon: IconReceipt },
  { href: '/announcements', label: 'Duyurular', Icon: IconMegaphone },
  { href: '/inactive-dealers', label: 'Pasif Bayiler', Icon: IconClock },
  { href: '/audit-log', label: 'İşlem Günlüğü', Icon: IconScroll },
  { href: '/settings', label: 'Ayarlar', Icon: IconSettings },
];

export default function Sidebar({
  collapsed,
  mobileOpen,
  onCloseMobile,
}: {
  collapsed: boolean;
  mobileOpen: boolean;
  onCloseMobile: () => void;
}) {
  const pathname = usePathname();
  const { data: badgeCounts } = useSWR('/dashboard/admin-badge-counts', fetcher, { refreshInterval: 20000 });
  const emergencyCount = badgeCounts?.emergencyTickets ?? 0;

  const content = (
    <>
      <div className={`h-16 flex items-center border-b border-gray-100/80 ${collapsed ? 'px-3 justify-center' : 'px-5'}`}>
        <div className="flex items-center gap-2.5 min-w-0">
          <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-brand to-brand-dark flex items-center justify-center text-white font-bold text-[11px] shadow-sm shrink-0">
            E
          </div>
          {!collapsed && (
            <div className="min-w-0">
              <h1 className="text-[13px] font-semibold text-gray-900 tracking-tight leading-tight truncate">ENTPA</h1>
            </div>
          )}
        </div>
      </div>

      <nav className={`flex-1 space-y-1 overflow-y-auto py-4 ${collapsed ? 'px-2' : 'px-3'}`}>
        {items.map(({ href, label, Icon }) => {
          const active = href === '/' ? pathname === '/' : pathname?.startsWith(href);
          const badgeKey = badgeKeyByHref[href];
          const badgeCount = badgeKey ? badgeCounts?.[badgeKey] ?? 0 : 0;
          const isUrgent = href === '/support-tickets' && emergencyCount > 0;
          return (
            <Link
              key={href}
              href={href}
              onClick={onCloseMobile}
              title={collapsed ? label : undefined}
              className={`group relative flex items-center gap-2.5 rounded-lg h-9 text-[12.5px] font-medium transition-colors ${
                collapsed ? 'px-2 justify-center' : 'px-2.5'
              } ${active ? 'bg-brand/10 text-brand-dark shadow-sm' : 'text-gray-500 hover:bg-gray-50 hover:text-gray-800'}`}
            >
              <Icon className={active ? 'text-brand' : 'text-gray-400 group-hover:text-gray-500'} width={15} height={15} />
              {!collapsed && <span className="truncate flex-1">{label}</span>}
              {badgeCount > 0 && (
                <span
                  className={`shrink-0 text-[10px] font-semibold text-white rounded-full min-w-[16px] h-[16px] px-1 flex items-center justify-center ${
                    isUrgent ? 'bg-red-500' : 'bg-gray-400'
                  } ${collapsed ? 'absolute -top-0.5 -right-0.5' : ''}`}
                >
                  {collapsed ? '' : badgeCount > 99 ? '99+' : badgeCount}
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      {!collapsed && (
        <div className="px-4 py-3 border-t border-gray-100">
          <p className="text-[10px] text-gray-300">v1.0</p>
        </div>
      )}
    </>
  );

  return (
    <>
      <aside className={`hidden md:flex flex-col shrink-0 bg-white border-r border-gray-200/70 transition-all duration-150 ${collapsed ? 'w-14' : 'w-[224px]'}`}>
        {content}
      </aside>

      {mobileOpen && (
        <div className="md:hidden fixed inset-0 z-40 flex">
          <div className="absolute inset-0 bg-black/30" onClick={onCloseMobile} />
          <aside className="relative w-[224px] bg-white flex flex-col h-full shadow-xl">
            {content}
          </aside>
        </div>
      )}
    </>
  );
}
