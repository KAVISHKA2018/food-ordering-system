import Sidebar from './Sidebar';

export default function Layout({ children }) {
  return (
    <div style={styles.container}>
      <div style={styles.sidebarWrapper}>
        <Sidebar />
      </div>
      <div style={styles.content}>{children}</div>
    </div>
  );
}

const styles = {
  container: {
    display: 'flex',
    height: '100vh',
    overflow: 'hidden', // prevents the whole page from scrolling
  },
  sidebarWrapper: {
    flexShrink: 0, // sidebar keeps its width, never gets squeezed
    height: '100vh',
    overflowY: 'auto', // only scrolls internally if the nav list itself ever grows very long
  },
  content: {
    flex: 1,
    backgroundColor: '#FFF8F3',
    height: '100vh',
    overflowY: 'auto', // this is the only part that scrolls
  },
};