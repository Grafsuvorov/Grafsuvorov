import { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import './index.css';
import './style/app.css';

import DependencyViewer from './components/DependencyViewer.jsx';
import ErrorDashboard from './components/ErrorDashboard.jsx';
import Sidebar from './components/Sidebar.jsx';
import HomePage from './components/HomePage.jsx';
import SearchPage from './components/SearchPage.jsx';
import TableCard from './components/TableCard.jsx';
import TableSearch from './components/TableSearch.jsx';
import InconsistencyPage from './components/InconsistencyPage.jsx';
import SlowestTables from './components/SlowestTables.jsx';
import SlaPage from './components/SlaPage.jsx';
import EntityShedule from './components/EntityShedule.jsx';
import EntityTablesPage from './components/EntityTablesPage.jsx'; // ← новая страница

export default function App() {
  const [view, setView] = useState('home');
  const [selectedTable, setSelectedTable] = useState(null);
  const [fromErrors, setFromErrors] = useState(false);
  const [schema, setSchema] = useState(null);
  const [tableName, setTableName] = useState(null);
  const [lastSource, setLastSource] = useState(null);

  const navigate = useNavigate();
  const location = useLocation();

  // === ВАЖНО: НЕ перетираем deep-роут /entity/:id/tables ===
  useEffect(() => {
    const isEntityTables = /^\/entity\/\d+\/tables$/.test(location.pathname);
    if (isEntityTables) return;

    const routeForView = {
      home: '/',
      errors: '/errors',
      search: '/search',
      table_search: '/table_search',
      '__check_inconsistencies__': '/inconsistencies',
      sla: '/sla',
      slowest_tables: '/slowest_tables',
      entity_schedule: '/entity_schedule',
      dependencies: '/dependencies',
      table_info: '/table_info',
    };

    const target = routeForView[view];
    if (target && location.pathname !== target) {
      navigate(target);
    }
  }, [view, location.pathname, navigate]);

  // === Парсим URL → view, в т.ч. детальную страницу сущности ===
  useEffect(() => {
    const path = location.pathname;

    const entityMatch = path.match(/^\/entity\/(\d+)\/tables$/);
    if (entityMatch) {
      setView('entity_tables'); // спец-вид для EntityTablesPage
      return;
    }

    if (path === '/errors') setView('errors');
    else if (path === '/search') setView('search');
    else if (path === '/table_search') setView('table_search');
    else if (path === '/inconsistencies') setView('__check_inconsistencies__');
    else if (path === '/sla') setView('sla');
    else if (path === '/slowest_tables') setView('slowest_tables');
    else if (path === '/entity_schedule') setView('entity_schedule');
    else if (path === '/dependencies') setView('dependencies');
    else if (path === '/table_info') setView('table_info');
    else setView('home');
  }, [location.pathname]);

  useEffect(() => {
    if (schema && tableName && lastSource === 'card') {
      setSelectedTable(`${schema}.${tableName}`);
      setView('table_info');
    }
  }, [schema, tableName, lastSource]);

  const openDependencyView = (tableName, source = '') => {
    if (!tableName) {
      setSelectedTable(null);
      setFromErrors(false);
      setView('home');
    } else if (tableName === '__show_errors__') {
      setSelectedTable(null);
      setFromErrors(false);
      setView('errors');
    } else if (tableName === '__check_inconsistencies__') {
      setSelectedTable(null);
      setFromErrors(false);
      setView('__check_inconsistencies__');
    } else if (tableName === 'sla') {
      setSchema(null);
      setTableName(null);
      setView('sla');
    } else if (tableName === 'search') {
      setSelectedTable(null);
      setFromErrors(false);
      setView('search');
    } else if (tableName === '__slowest_tables__') {
      setSelectedTable(null);
      setFromErrors(false);
      setView('slowest_tables');
    } else if (tableName === '__entity_schedule__') {
      setSelectedTable(null);
      setFromErrors(false);
      setView('entity_schedule');
    } else if (tableName === 'table_search') {
      setSelectedTable(null);
      setFromErrors(false);
      setView('table_search');
    } else if (tableName.includes('.')) {
      setSelectedTable(tableName);
      tableName = tableName.replaceAll('/', '').replaceAll('-', '').replaceAll(' ', '');
      const [sch, tbl] = tableName.split('.');
      setSchema(sch);
      setTableName(tbl);
      setLastSource(source);
      if (source === 'errors' || source === 'graph') {
        setFromErrors(source === 'errors');
        setView('dependencies');
      } else if (source === 'card') {
        setView('table_info');
      }
    } else {
      setSelectedTable(tableName);
      setFromErrors(source === 'errors');
      setView('dependencies');
    }
  };

  const renderContent = () => {
    if (view === 'home') return <HomePage onSelectTable={openDependencyView} />;
    if (view === 'search') return <SearchPage onSelectTable={(name) => openDependencyView(name, 'graph')} />;
    if (view === 'errors') return <ErrorDashboard onSelectTable={(name) => openDependencyView(name, 'errors')} />;
    if (view === 'table_search') return <TableSearch onSelectTable={(name) => openDependencyView(name, 'card')} />;
    if (view === '__check_inconsistencies__') return <InconsistencyPage onBack={() => setView('home')} />;
    if (view === 'sla') return <SlaPage />;
    if (view === 'slowest_tables') return <SlowestTables />;
    if (view === 'entity_schedule') return <EntityShedule />;
    if (view === 'entity_tables') return <EntityTablesPage />; // ← детальная страница
    if (view === 'table_info') {
      return (
        <TableCard
          schema={schema}
          tableName={tableName}
          onBack={() => setView('table_search')}
          setSchema={setSchema}
          setTableName={setTableName}
        />
      );
    }
    if (view === 'dependencies') {
      return (
        <DependencyViewer
          table={selectedTable}
          onBack={() => {
            if (fromErrors) {
              setView('errors');
              setFromErrors(false);
            } else {
              setView('search');
            }
          }}
        />
      );
    }
    return <div>Раздел не найден</div>;
  };

  return (
    <div className="app-container">
      <Sidebar currentView={view} onChangeView={openDependencyView} />
      <main className="content">{renderContent()}</main>
    </div>
  );
}
