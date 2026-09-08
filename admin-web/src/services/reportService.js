import apiClient from './apiClient';
import { API_CONFIG } from '../config/apiConfig';

const reportService = {
  async getReports(startDate, endDate) {
    const params = new URLSearchParams();
    if (startDate) params.append('start_date', startDate);
    if (endDate) params.append('end_date', endDate);
    const response = await apiClient.get(`${API_CONFIG.baseURL}/reports/?${params.toString()}`);
    return response.data;
  },
};

export default reportService;