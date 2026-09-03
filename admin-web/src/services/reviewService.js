import apiClient from './apiClient';
import { API_CONFIG } from '../config/apiConfig';

export const reviewService = {
  async getReviews() {
    const response = await apiClient.get(API_CONFIG.reviews);
    return response.data;
  },

  async reply(reviewId, replyText) {
    const response = await apiClient.post(`${API_CONFIG.reviews}${reviewId}/reply/`, { reply: replyText });
    return response.data;
  },

  async getFoodReviews() {
    const response = await apiClient.get(API_CONFIG.foodReviews);
    return response.data;
  },
};

export default reviewService;