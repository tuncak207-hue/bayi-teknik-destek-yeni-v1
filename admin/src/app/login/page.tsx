'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await api.post('/auth/login', { email, password });
      localStorage.setItem('admin_token', res.data.accessToken);
      // ÖNEMLİ: Önceden sadece erişim token'ı (15 dakikada bir sona
      // eriyor) saklanıyordu, yenileme token'ı hiç kullanılmıyordu — bu
      // yüzden 15 dakikada bir otomatik çıkış yapılıyordu. Artık
      // yenileme token'ı da saklanıp otomatik kullanılıyor (api.ts).
      localStorage.setItem('admin_refresh_token', res.data.refreshToken);
      router.push('/');
    } catch (err: any) {
      setError(err.response?.data?.message || 'Giriş başarısız.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      className="min-h-screen flex items-center justify-center bg-[#FAFAFB] relative overflow-hidden"
      style={{
        backgroundImage:
          'linear-gradient(rgba(11,27,43,0.025) 1px, transparent 1px), linear-gradient(90deg, rgba(11,27,43,0.025) 1px, transparent 1px)',
        backgroundSize: '32px 32px',
      }}
    >
      <div className="absolute -top-40 left-1/2 -translate-x-1/2 w-[560px] h-[560px] rounded-full bg-brand/[0.06] blur-3xl pointer-events-none" />

      <div className="relative w-full max-w-sm mx-4">
        <div className="flex flex-col items-center mb-8">
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-brand to-brand-dark flex items-center justify-center text-white font-bold text-lg mb-4 shadow-lg shadow-brand/15">
            E
          </div>
          <h1 className="text-navy font-semibold text-lg tracking-tight">ENTPA Admin</h1>
          <p className="text-gray-400 text-xs mt-1">Bayi Teknik Destek Yönetim Paneli</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-white rounded-lg overflow-hidden shadow-xl shadow-gray-200/60 border border-gray-100">
          <div className="h-[3px] bg-brand" />
          <div className="p-8">
            {error && (
              <div className="mb-5 px-3 py-2.5 bg-red-50 border border-red-100 rounded-lg">
                <p className="text-sm text-red-600">{error}</p>
              </div>
            )}

            <div className="mb-4">
              <label className="block text-xs font-medium text-gray-500 mb-1.5">E-posta</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@example.com"
                className="w-full border border-gray-200 rounded-lg px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-navy/10 focus:border-navy transition"
                required
              />
            </div>
            <div className="mb-6">
              <label className="block text-xs font-medium text-gray-500 mb-1.5">Şifre</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full border border-gray-200 rounded-lg px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-navy/10 focus:border-navy transition"
                required
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-navy text-white rounded-lg py-2.5 text-sm font-semibold hover:bg-navy-light transition disabled:opacity-60"
            >
              {loading ? 'Giriş yapılıyor...' : 'Giriş Yap'}
            </button>
          </div>
        </form>

        <p className="text-center text-gray-300 text-[11px] mt-6">Sadece yetkili yöneticiler için</p>
      </div>
    </div>
  );
}
