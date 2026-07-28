import apiClient from './apiClient';
import { API_CONFIG } from '../config/apiConfig';

export const orderService = {
  async getOrders() {
    const response = await apiClient.get(API_CONFIG.orders);
    return response.data;
  },

  async updateStatus(orderId, status) {
    const response = await apiClient.patch(`${API_CONFIG.orders}${orderId}/update_status/`, { status });
    return response.data;
  },
};

export default orderService;