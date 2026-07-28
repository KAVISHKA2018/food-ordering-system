const BASE_URL = 'http://127.0.0.1:8000/api';

export const API_CONFIG = {
  baseURL: BASE_URL,
  login: `${BASE_URL}/accounts/login/`,
  register: `${BASE_URL}/accounts/register/`,
  me: `${BASE_URL}/accounts/me/`,
  restaurants: `${BASE_URL}/restaurants/`,
  myRestaurant: `${BASE_URL}/restaurants/mine/`,
  categories: `${BASE_URL}/categories/`,
  menuItems: `${BASE_URL}/menu-items/`,
  orders: `${BASE_URL}/orders/`,
  reservations: `${BASE_URL}/reservations/`,
};

export default API_CONFIG;