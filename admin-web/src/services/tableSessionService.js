import apiClient from './apiClient';
import { API_CONFIG } from '../config/apiConfig';

export const tableSessionService = {
  async getSessions() {
    const response = await apiClient.get(API_CONFIG.tableSessions);
    return response.data;
  },

  async confirmPayment(sessionId) {
    const response = await apiClient.post(`${API_CONFIG.tableSessions}${sessionId}/confirm_payment/`);
    return response.data;
  },
};

export default tableSessionService;