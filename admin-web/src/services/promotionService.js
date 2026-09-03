import apiClient, { multipartClient } from './apiClient';
import { API_CONFIG } from '../config/apiConfig';

export const promotionService = {
  async getPromotions() {
    const response = await apiClient.get(API_CONFIG.promotions);
    return response.data;
  },

  async createPromotion(formData) {
    const response = await multipartClient.post(API_CONFIG.promotions, formData);
    return response.data;
  },

  async updatePromotion(id, formData) {
    const response = await multipartClient.patch(`${API_CONFIG.promotions}${id}/`, formData);
    return response.data;
  },

  async deletePromotion(id) {
    await apiClient.delete(`${API_CONFIG.promotions}${id}/`);
  },
};

export default promotionService;