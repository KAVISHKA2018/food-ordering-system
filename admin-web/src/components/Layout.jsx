import Sidebar from './Sidebar';

export default function Layout({ children }) {
  return (
    <div style={{ display: 'flex' }}>
      <Sidebar />
      <div style={{ flex: 1, backgroundColor: '#FFF8F3', minHeight: '100vh' }}>
        {children}
      </div>
    </div>
  );
}