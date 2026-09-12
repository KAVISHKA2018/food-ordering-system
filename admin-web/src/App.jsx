import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import MenuManagementPage from './pages/MenuManagementPage';
import OrdersPage from './pages/OrdersPage';
import ReservationsPage from './pages/ReservationsPage';
import TablesPage from './pages/TablesPage';
import PromotionsPage from './pages/PromotionsPage';
import ReviewsPage from './pages/ReviewsPage';
import ReportsPage from './pages/ReportsPage';
import DeliveryStaffPage from './pages/DeliveryStaffPage';

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
          <Route path="/menu" element={<ProtectedRoute><MenuManagementPage /></ProtectedRoute>} />
          <Route path="/orders" element={<ProtectedRoute><OrdersPage /></ProtectedRoute>} />
          <Route path="/reservations" element={<ProtectedRoute><ReservationsPage /></ProtectedRoute>} />
          <Route path="/tables" element={<ProtectedRoute><TablesPage /></ProtectedRoute>} />
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="/promotions" element={<ProtectedRoute><PromotionsPage /></ProtectedRoute>} />
          <Route path="/reviews" element={<ProtectedRoute><ReviewsPage /></ProtectedRoute>} />
          <Route path="/reports" element={<ProtectedRoute><ReportsPage /></ProtectedRoute>} />
          <Route path="/delivery-staff" element={<ProtectedRoute><DeliveryStaffPage /></ProtectedRoute>} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;