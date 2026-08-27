import axios from 'axios';

const configuredApiUrl = process.env.NEXT_PUBLIC_API_URL;
const defaultApiUrl = process.env.NODE_ENV === 'production' ? '/api/v1' : 'http://localhost:3000/api/v1';

export const api = axios.create({
  baseURL: configuredApiUrl || defaultApiUrl,
  withCredentials: true,
});

// Admin JWT’leri HttpOnly cookie olarak tutulur; böylece JavaScript ve
// localStorage üzerinden okunamaz. Mobil istemciler Bearer token kullanmaya
// devam eder ve bu istemciye ait değildir.
let isRefreshing = false;
let refreshWaiters: Array<(success: boolean) => void> = [];

async function refreshAccessToken(): Promise<boolean> {
  try {
    await axios.post(
      `${configuredApiUrl || defaultApiUrl}/auth/refresh`,
      {},
      { withCredentials: true },
    );
    return true;
  } catch {
    return false;
  }
}

api.interceptors.response.use(
  (res) => res,
  async (err) => {
    const originalRequest = err.config;
    if (err.response?.status === 401 && typeof window !== 'undefined' && !originalRequest?._retried) {
      originalRequest._retried = true;

      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          refreshWaiters.push((success) => {
            if (success) resolve(api(originalRequest));
            else reject(err);
          });
        });
      }

      isRefreshing = true;
      const refreshed = await refreshAccessToken();
      isRefreshing = false;
      refreshWaiters.forEach((waiter) => waiter(refreshed));
      refreshWaiters = [];

      if (refreshed) return api(originalRequest);

      window.location.replace(new URL('/login', window.location.origin).toString());
    }
    return Promise.reject(err);
  },
);
