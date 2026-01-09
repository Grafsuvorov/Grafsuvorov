export default function AppLayout({ sidebar, children }) {
  return (
    <div className="app-layout">
      <aside className="sidebar">
        {sidebar}
      </aside>
      <main className="content">
        {children}
      </main>
    </div>
  );
}
