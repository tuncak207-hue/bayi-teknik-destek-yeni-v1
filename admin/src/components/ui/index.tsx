/**
 * Admin panel ortak Design System bileşenleri — mobil uygulamadaki
 * StatusBadge/StandardCard ile aynı görsel dili taşır, masaüstüne göre
 * uyarlanmıştır.
 */

/**
 * Admin panel ortak Design System bileşenleri.
 *
 * ÖNEMLİ (kullanıcı geri bildirimi üzerine): Önceki sürüm çok "genel
 * SaaS şablonu" hissi veriyordu (aşırı yuvarlak köşe, gereksiz gölge).
 * Bu sürüm, Linear/Stripe/Vercel gibi referans panellerin ortak
 * özelliklerini taşıyor: daha ince kenarlıklar, DAHA AZ gölge, daha
 * küçük/sıkı köşe yuvarlaklığı, daha kompakt boşluklar, daha küçük ve
 * kesin tipografi. Tek accent renk (brand) tutarlı kullanılıyor.
 */

type BadgeTone = 'success' | 'inProgress' | 'pending' | 'danger' | 'neutral';

const toneStyles: Record<BadgeTone, string> = {
  success: 'bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-600/15',
  inProgress: 'bg-blue-50 text-blue-700 ring-1 ring-inset ring-blue-600/15',
  pending: 'bg-amber-50 text-amber-700 ring-1 ring-inset ring-amber-600/15',
  danger: 'bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/15',
  neutral: 'bg-gray-100 text-gray-600 ring-1 ring-inset ring-gray-500/10',
};

export function Badge({ label, tone = 'neutral' }: { label: string; tone?: BadgeTone }) {
  return (
    <span className={`inline-flex items-center text-[11px] font-semibold px-2 py-0.5 rounded-md ${toneStyles[tone]}`}>
      {label}
    </span>
  );
}

// Renkli, gradyanlı ikon rozeti — kullanıcı isteği: "göz kamaştırıcı"
// olsun. Her modül/kategori kendi rengiyle görsel olarak ayırt ediliyor.
export type IconColor = 'blue' | 'violet' | 'amber' | 'emerald' | 'rose' | 'cyan' | 'navy' | 'slate';

const iconGradients: Record<IconColor, string> = {
  blue: 'from-blue-500 to-blue-600',
  violet: 'from-violet-500 to-purple-600',
  amber: 'from-amber-500 to-orange-600',
  emerald: 'from-emerald-500 to-teal-600',
  rose: 'from-rose-500 to-red-600',
  cyan: 'from-cyan-500 to-sky-600',
  navy: 'from-slate-700 to-navy',
  slate: 'from-gray-400 to-gray-500',
};

export function IconBadge({ icon, color = 'navy', size = 'md' }: { icon: React.ReactNode; color?: IconColor; size?: 'sm' | 'md' | 'lg' }) {
  const sizeClasses = { sm: 'w-8 h-8 rounded-lg', md: 'w-10 h-10 rounded-xl', lg: 'w-12 h-12 rounded-xl' };
  return (
    <div className={`bg-gradient-to-br ${iconGradients[color]} ${sizeClasses[size]} flex items-center justify-center text-white shadow-sm shrink-0`}>
      {icon}
    </div>
  );
}

export function Card({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={`bg-white rounded-xl border border-gray-200/70 ${className}`}>
      {children}
    </div>
  );
}

export function CardHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between px-5 py-4 border-b border-gray-100">
      <div>
        <h3 className="text-[13px] font-semibold text-gray-900">{title}</h3>
        {subtitle && <p className="text-[12px] text-gray-400 mt-0.5">{subtitle}</p>}
      </div>
      {action}
    </div>
  );
}

export function PillButton({
  children,
  onClick,
  variant = 'secondary',
  type = 'button',
  disabled = false,
}: {
  children: React.ReactNode;
  onClick?: () => void;
  variant?: 'primary' | 'secondary' | 'danger';
  type?: 'button' | 'submit';
  disabled?: boolean;
}) {
  const variants = {
    primary: 'bg-gradient-to-r from-brand to-brand-dark text-white hover:opacity-90 shadow-sm shadow-brand/20',
    secondary: 'bg-white text-gray-700 border border-gray-200 hover:bg-gray-50',
    danger: 'bg-white text-red-600 border border-gray-200 hover:bg-red-50 hover:border-red-200',
  };
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`text-[13px] font-medium h-8 px-3.5 rounded-lg transition-colors disabled:opacity-50 ${variants[variant]}`}
    >
      {children}
    </button>
  );
}

/** Ortak yükleniyor durumu — tüm sayfalarda tutarlı görünüm için. */
export function LoadingState({ label = 'Yükleniyor...' }: { label?: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-gray-400">
      <div className="w-5 h-5 border-2 border-gray-200 border-t-gray-500 rounded-full animate-spin mb-3" />
      <p className="text-[13px]">{label}</p>
    </div>
  );
}

/** Ortak "veri yok" durumu. */
export function EmptyState({ title, description }: { title: string; description?: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center px-4">
      <div className="w-10 h-10 rounded-xl bg-gray-50 border border-gray-100 flex items-center justify-center mb-3">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="text-gray-300">
          <rect x="3" y="3" width="18" height="18" rx="4" />
          <path d="M8 12h8" />
        </svg>
      </div>
      <p className="text-[13px] font-medium text-gray-600">{title}</p>
      {description && <p className="text-[12px] text-gray-400 mt-1 max-w-xs">{description}</p>}
    </div>
  );
}

/** Ortak "sonuç bulunamadı" (arama/filtre) durumu. */
export function NoResultsState({ query }: { query?: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-14 text-center px-4">
      <p className="text-[13px] font-medium text-gray-600">{query ? `"${query}" ile eşleşen sonuç yok` : 'Sonuç bulunamadı'}</p>
      <p className="text-[12px] text-gray-400 mt-1">Farklı bir arama terimi ya da filtre deneyin.</p>
    </div>
  );
}

/** Ortak hata durumu — tekrar deneme butonuyla. */
export function ErrorState({ onRetry }: { onRetry?: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center px-4">
      <div className="w-10 h-10 rounded-xl bg-red-50 border border-red-100 flex items-center justify-center mb-3">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-red-400">
          <circle cx="12" cy="12" r="9" />
          <path d="M12 8v5M12 16h.01" />
        </svg>
      </div>
      <p className="text-[13px] font-medium text-gray-700">Bir şeyler ters gitti</p>
      <p className="text-[12px] text-gray-400 mt-1">Veriler yüklenirken bir hata oluştu.</p>
      {onRetry && (
        <button onClick={onRetry} className="text-[12px] font-medium text-gray-700 border border-gray-200 rounded-lg px-3 py-1.5 mt-4 hover:bg-gray-50 transition">
          Tekrar Dene
        </button>
      )}
    </div>
  );
}
