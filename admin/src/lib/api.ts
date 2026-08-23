import axios from 'axios';

export const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1',
});

api.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('admin_token');
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// ÖNEMLİ: Erişim token'ı sadece 15 dakikada bir sona eriyor — önceden
// süresi dolduğunda hiç yenileme denenmeden direkt çıkış yapılıyordu
// ("sürekli kapanıyor" sorununun kök sebebi buydu). Artık 401 alınca
// önce sessizce yenileme token'ıyla (30 gün geçerli) yeni bir erişim
// token'ı isteniyor; bu da başarısız olursa (örn. 30 gün de dolmuşsa)
// ancak o zaman çıkış yapılıyor.
let isRefreshing = false;
let refreshWaiters: Array<(token: string | null) => void> = [];

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = localStorage.getItem('admin_refresh_token');
  if (!refreshToken) return null;
  try {
    const res = await axios.post(
      `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api/v1'}/auth/refresh`,
      {},
      { headers: { Authorization: `Bearer ${refreshToken}` } },
    );
    localStorage.setItem('admin_token', res.data.accessToken);
    localStorage.setItem('admin_refresh_token', res.data.refreshToken);
    return res.data.accessToken;
  } catch {
    return null;
  }
}

api.interceptors.response.use(
  (res) => res,
  async (err) => {
    const originalRequest = err.config;
    if (err.response?.status === 401 && typeof window !== 'undefined' && !originalRequest._retried) {
      originalRequest._retried = true;

      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          refreshWaiters.push((token) => {
            if (token) {
              originalRequest.headers.Authorization = `Bearer ${token}`;
              resolve(api(originalRequest));
            } else {
              reject(err);
            }
          });
        });
      }

      isRefreshing = true;
      const newToken = await refreshAccessToken();
      isRefreshing = false;
      refreshWaiters.forEach((waiter) => waiter(newToken));
      refreshWaiters = [];

      if (newToken) {
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        return api(originalRequest);
      }

      localStorage.removeItem('admin_token');
      localStorage.removeItem('admin_refresh_token');
      window.location.href = '/login';
    }
    return Promise.reject(err);
  },
);
