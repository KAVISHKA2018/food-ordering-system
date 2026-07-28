import apiClient from './apiClient';
import { API_CONFIG } from '../config/apiConfig';

export const authService = {
  async login(username, password) {
    const response = await apiClient.post(API_CONFIG.login, { username, password });
    const { access, refresh } = response.data;
    localStorage.setItem('access_token', access);
    localStorage.setItem('refresh_token', refresh);
    return response.data;
  },

  async getCurrentUser() {
    const response = await apiClient.get(API_CONFIG.me);
    return response.data;
  },

  logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
  },

  isLoggedIn() {
    return !!localStorage.getItem('access_token');
  },
};

export default authService;