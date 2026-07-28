import axios from 'axios';
import { API_CONFIG } from '../config/apiConfig';

const apiClient = axios.create({
  baseURL: API_CONFIG.baseURL,
  headers: {
    'Content-Type': 'application/json',
  },
});

export const multipartClient = axios.create({
  baseURL: API_CONFIG.baseURL,
});

function attachToken(config) {
  const token = localStorage.getItem('access_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
}

// For multipart requests, explicitly remove any Content-Type so the
// browser sets 'multipart/form-data; boundary=...' correctly itself.
function attachTokenMultipart(config) {
  const token = localStorage.getItem('access_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  if (config.headers) {
    delete config.headers['Content-Type'];
  }
  return config;
}

apiClient.interceptors.request.use(attachToken);
multipartClient.interceptors.request.use(attachTokenMultipart);

let isRefreshing = false;
let refreshQueue = [];

async function refreshAccessToken() {
  const refreshToken = localStorage.getItem('refresh_token');
  if (!refreshToken) throw new Error('No refresh token available');

  const response = await axios.post(`${API_CONFIG.baseURL}/accounts/token/refresh/`, {
    refresh: refreshToken,
  });
  const newAccessToken = response.data.access;
  localStorage.setItem('access_token', newAccessToken);
  return newAccessToken;
}

function createResponseInterceptor(client) {
  client.interceptors.response.use(
    (response) => response,
    async (error) => {
      const originalRequest = error.config;

      if (error.response?.status === 401 && !originalRequest._retry) {
        originalRequest._retry = true;

        if (isRefreshing) {
          return new Promise((resolve, reject) => {
            refreshQueue.push({ resolve, reject });
          }).then((token) => {
            originalRequest.headers.Authorization = `Bearer ${token}`;
            return client(originalRequest);
          });
        }

        isRefreshing = true;
        try {
          const newToken = await refreshAccessToken();
          refreshQueue.forEach((p) => p.resolve(newToken));
          refreshQueue = [];
          originalRequest.headers.Authorization = `Bearer ${newToken}`;
          return client(originalRequest);
        } catch (refreshError) {
          refreshQueue.forEach((p) => p.reject(refreshError));
          refreshQueue = [];
          localStorage.removeItem('access_token');
          localStorage.removeItem('refresh_token');
          window.location.href = '/login';
          return Promise.reject(refreshError);
        } finally {
          isRefreshing = false;
        }
      }

      return Promise.reject(error);
    }
  );
}

createResponseInterceptor(apiClient);
createResponseInterceptor(multipartClient);

export default apiClient;