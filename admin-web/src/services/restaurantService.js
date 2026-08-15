import apiClient, { multipartClient } from './apiClient';
import { API_CONFIG } from '../config/apiConfig';

export const restaurantService = {
  async getMyRestaurant() {
    const response = await apiClient.get(API_CONFIG.myRestaurant);
    return response.data[0] || null;
  },

  async updateRestaurant(id, data) {
    const response = await apiClient.patch(`${API_CONFIG.restaurants}${id}/`, data);
    return response.data;
  },

  async updateRestaurantImages(id, formData) {
    const response = await multipartClient.patch(`${API_CONFIG.restaurants}${id}/`, formData);
    return response.data;
  },

  async createCategory(data) {
    const response = await apiClient.post(API_CONFIG.categories, data);
    return response.data;
  },

  async updateCategory(id, data) {
    const response = await apiClient.patch(`${API_CONFIG.categories}${id}/`, data);
    return response.data;
  },

  async deleteCategory(id) {
    await apiClient.delete(`${API_CONFIG.categories}${id}/`);
  },

  async createMenuItem(formData) {
    const response = await multipartClient.post(API_CONFIG.menuItems, formData);
    return response.data;
  },

  async updateMenuItem(id, formData) {
    const response = await multipartClient.patch(`${API_CONFIG.menuItems}${id}/`, formData);
    return response.data;
  },

  async deleteMenuItem(id) {
    await apiClient.delete(`${API_CONFIG.menuItems}${id}/`);
  },

  async createVariant(data) {
    const response = await apiClient.post(API_CONFIG.menuItemVariants, data);
    return response.data;
  },

  async updateVariant(id, data) {
    const response = await apiClient.patch(`${API_CONFIG.menuItemVariants}${id}/`, data);
    return response.data;
  },

  async deleteVariant(id) {
    await apiClient.delete(`${API_CONFIG.menuItemVariants}${id}/`);
  },

  async getQRCode(id) {
    const response = await apiClient.get(`${API_CONFIG.restaurants}${id}/qr-code/`, {
      responseType: 'blob',
    });
    return URL.createObjectURL(response.data);
  },
};

export default restaurantService;