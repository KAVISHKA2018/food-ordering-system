import Layout from '../components/Layout';
import { useAuth } from '../context/AuthContext';

export default function DashboardPage() {
  const { user } = useAuth();

  return (
    <Layout>
      <div style={{ padding: '32px' }}>
        <h1>Welcome, {user?.username}</h1>
        <p style={{ color: '#8E8E8E' }}>Role: {user?.role}</p>
      </div>
    </Layout>
  );
}