import apiClient from './apiClient';
import { API_CONFIG } from '../config/apiConfig';

export const reservationService = {
  async getReservations() {
    const response = await apiClient.get(API_CONFIG.reservations);
    return response.data;
  },

  async updateStatus(reservationId, status) {
    const response = await apiClient.patch(
      `${API_CONFIG.reservations}${reservationId}/update_status/`,
      { status }
    );
    return response.data;
  },
};

export default reservationService;