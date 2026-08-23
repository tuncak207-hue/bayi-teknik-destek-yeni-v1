'use client';

import { useRouter, usePathname } from 'next/navigation';
import { useEffect, useState, useRef } from 'react';
import { api } from '@/lib/api';
import { IconLogout, IconMenu, IconPanelLeft, IconSearch, IconBell } from './icons';

const pageTitles: Record<string, string> = {
  '/': 'Genel Bakış',
  '/dealers': 'Bayiler',
  '/documents': 'Dokümanlar',
  '/chats': 'Sohbetler',
  '/appointments': 'Randevular',
  '/groups': 'Gruplar',
  '/sales-consultants': 'Satış Danışmanları',
  '/training': 'Eğitim Merkezi',
  '/support-tickets': 'Teknik Destek',
  '/product-analysis': 'Ürün Analizi',
  '/operations-analysis': 'Operasyon Analizi',
  '/quotes': 'Teklif Al',
  '/announcements': 'Duyurular',
  '/inactive-dealers': 'Pasif Bayiler',
  '/audit-log': 'İşlem Günlüğü',
  '/settings': 'Ayarlar',
};

export default function Topbar({
  onToggleMobile,
  onToggleCollapse,
}: {
  onToggleMobile: () => void;
  onToggleCollapse: () => void;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [admin, setAdmin] = useState<{ firstName?: string; lastName?: string; email?: string } | null>(null);
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<any | null>(null);
  const [searching, setSearching] = useState(false);
  const searchBoxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    api
      .get('/users/me')
      .then((res) => setAdmin(res.data))
      .catch(() => {});
  }, []);

  // Arama kutusu dışına tıklanınca sonuç panelini kapat.
  useEffect(() => {
    function onClickOutside(e: MouseEvent) {
      if (searchBoxRef.current && !searchBoxRef.current.contains(e.target as Node)) {
        setResults(null);
      }
    }
    document.addEventListener('mousedown', onClickOutside);
    return () => document.removeEventListener('mousedown', onClickOutside);
  }, []);

  useEffect(() => {
    const q = query.trim();
    if (q.length < 2) {
      setResults(null);
      return;
    }
    setSearching(true);
    const timeout = setTimeout(() => {
      api
        .get('/search', { params: { q } })
        .then((res) => setResults(res.data))
        .finally(() => setSearching(false));
    }, 300);
    return () => clearTimeout(timeout);
  }, [query]);

  function logout() {
    if (!confirm('Oturumu kapatmak istediğinize emin misiniz?')) return;
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_refresh_token');
    router.push('/login');
  }

  const title = pageTitles[pathname ?? ''] ?? 'Admin';
  const initials = admin ? `${admin.firstName?.[0] ?? ''}${admin.lastName?.[0] ?? ''}`.toUpperCase() : '';
  const hasResults = results && ((results.documents?.length ?? 0) + (results.dealers?.length ?? 0) + (results.posts?.length ?? 0) > 0);

  return (
    <header className="h-14 border-b border-gray-200/70 bg-white flex items-center justify-between gap-4 px-4 md:px-6 shrink-0 sticky top-0 z-30">
      <div className="flex items-center gap-3 min-w-0">
        <button onClick={onToggleMobile} className="md:hidden text-gray-500 hover:text-gray-800 shrink-0" aria-label="Menüyü aç">
          <IconMenu width={19} height={19} />
        </button>
        <button onClick={onToggleCollapse} className="hidden md:block text-gray-300 hover:text-gray-600 shrink-0 transition-colors" aria-label="Menüyü daralt/genişlet">
          <IconPanelLeft width={17} height={17} />
        </button>
        <h1 className="text-[13.5px] font-semibold text-gray-900 truncate">{title}</h1>
      </div>

      <div ref={searchBoxRef} className="relative hidden sm:block flex-1 max-w-xs">
        <IconSearch width={14} height={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-300" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Ara..."
          className="w-full h-8 bg-gray-50 border border-gray-200/70 rounded-lg pl-8 pr-3 text-[12.5px] focus:outline-none focus:ring-2 focus:ring-gray-200 focus:border-gray-300 transition"
        />
        {query.trim().length >= 2 && (
          <div className="absolute top-full mt-2 left-0 right-0 bg-white rounded-lg border border-gray-200 shadow-lg max-h-80 overflow-y-auto z-40">
            {searching && <p className="text-[12px] text-gray-400 px-4 py-3">Aranıyor...</p>}
            {!searching && !hasResults && <p className="text-[12px] text-gray-400 px-4 py-3">Sonuç bulunamadı.</p>}
            {!searching && hasResults && (
              <div className="py-2">
                {results.dealers?.length > 0 && (
                  <SearchGroup title="Bayiler">
                    {results.dealers.map((d: any) => (
                      <SearchItem key={d.id} label={d.company} sub={`${d.firstName} ${d.lastName}`} href="/dealers" onNavigate={() => { setQuery(''); router.push('/dealers'); }} />
                    ))}
                  </SearchGroup>
                )}
                {results.documents?.length > 0 && (
                  <SearchGroup title="Dokümanlar">
                    {results.documents.map((d: any) => (
                      <SearchItem key={d.id} label={d.title} sub={`${d.brand} / ${d.model}`} href="/documents" onNavigate={() => { setQuery(''); router.push('/documents'); }} />
                    ))}
                  </SearchGroup>
                )}
                {results.posts?.length > 0 && (
                  <SearchGroup title="Bayilere Sor Gönderileri">
                    {results.posts.map((p: any) => (
                      <SearchItem key={p.id} label={p.title} sub={p.body?.slice(0, 40)} href="/" onNavigate={() => { setQuery(''); }} />
                    ))}
                  </SearchGroup>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      <div className="flex items-center gap-1 md:gap-2 shrink-0">
        <button className="relative text-gray-400 hover:text-gray-700 transition p-1.5 rounded-md hover:bg-gray-50" aria-label="Bildirimler">
          <IconBell width={16} height={16} />
        </button>

        <div className="hidden sm:flex items-center gap-2 pl-1">
          <div className="w-[26px] h-[26px] rounded-full bg-navy text-white flex items-center justify-center text-[10.5px] font-semibold shrink-0">
            {initials || '?'}
          </div>
          <div className="hidden lg:block leading-tight">
            <p className="text-[12.5px] text-gray-700 font-medium">{admin ? `${admin.firstName} ${admin.lastName}` : '...'}</p>
          </div>
        </div>

        <div className="w-px h-5 bg-gray-200 mx-1 hidden sm:block" />

        <button
          onClick={logout}
          className="flex items-center gap-1.5 text-[12.5px] font-medium text-gray-500 hover:text-red-600 hover:bg-red-50 px-2 md:px-2.5 h-8 rounded-md transition-colors"
        >
          <IconLogout width={14} height={14} />
          <span className="hidden md:inline">Çıkış</span>
        </button>
      </div>
    </header>
  );
}

function SearchGroup({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="px-2 mb-1 last:mb-0">
      <p className="text-[10px] font-semibold text-gray-400 uppercase tracking-wide px-2 py-1">{title}</p>
      {children}
    </div>
  );
}

function SearchItem({ label, sub, onNavigate }: { label: string; sub?: string; href: string; onNavigate: () => void }) {
  return (
    <button onClick={onNavigate} className="w-full text-left px-2 py-2 rounded-lg hover:bg-gray-50 transition">
      <p className="text-[13px] text-gray-800 font-medium truncate">{label}</p>
      {sub && <p className="text-[11px] text-gray-400 truncate">{sub}</p>}
    </button>
  );
}
