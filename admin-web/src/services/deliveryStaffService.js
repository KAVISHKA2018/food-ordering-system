import apiClient from './apiClient';
import { API_CONFIG } from '../config/apiConfig';

const deliveryStaffService = {
  async getMyStaff() {
    const response = await apiClient.get(`${API_CONFIG.baseURL}/accounts/delivery-staff/mine/`);
    return response.data;
  },

  async createStaff({ firstName, lastName, username, password, phoneNumber }) {
    const response = await apiClient.post(`${API_CONFIG.baseURL}/accounts/delivery-staff/create/`, {
      first_name: firstName,
      last_name: lastName,
      username,
      password,
      phone_number: phoneNumber,
    });
    return response.data;
  },

  async toggleActive(staffId) {
    const response = await apiClient.post(`${API_CONFIG.baseURL}/accounts/delivery-staff/${staffId}/toggle-active/`);
    return response.data;
  },

  async assignOrder(orderId, staffId) {
    const response = await apiClient.post(`${API_CONFIG.orders}${orderId}/assign_delivery_staff/`, {
      staff_id: staffId,
    });
    return response.data;
  },
};

export default deliveryStaffService;