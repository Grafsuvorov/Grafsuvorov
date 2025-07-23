// src/App.jsx
import { useState, useEffect } from 'react';
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

export default function App() {
  const [view, setView] = useState('home');
  const [selectedTable, setSelectedTable] = useState(null);
  const [fromErrors, setFromErrors] = useState(false);
  const [schema, setSchema] = useState(null);
  const [tableName, setTableName] = useState(null);

  useEffect(() => {
    console.log("selectedTable:", selectedTable, "schema:", schema, "tableName:", tableName);
  }, [selectedTable, schema, tableName]);

  useEffect(() => {
    if (schema && tableName) {
      setSelectedTable(`${schema}.${tableName}`);
      setView('table_info');
      console.log(" useEffect: schema =", schema, "tableName =", tableName);
    }
  }, [schema, tableName]);

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
    } else if (tableName === 'search') {
      setSelectedTable(null);
      setFromErrors(false);
      setView('search');
    } else if (tableName === '__slowest_tables__') {
      setSelectedTable(null);
      setFromErrors(false);
      setView('slowest_tables');
    } else if (tableName === 'table_search') {
      setSelectedTable(null);
      setFromErrors(false);
      setView('table_search');
    } else if (tableName.includes('.')) {
      setSelectedTable(tableName);
      const [sch, tbl] = tableName.split(".");
      setSchema(sch);
      setTableName(tbl);
      if (source === 'errors' || source === 'graph') {
        setFromErrors(source === 'errors');
        setView('dependencies');
      } else {
        setView('table_info');
      }
    } else {
      setSelectedTable(tableName);
      setFromErrors(source === 'errors');
      setView('dependencies');
    }
  };

  const renderContent = () => {
    if (view === 'home') {
      return <HomePage onSelectTable={openDependencyView} />;
    }
    if (view === 'search') {
      return <SearchPage onSelectTable={(name) => openDependencyView(name, 'graph')} />;
    }
    if (view === 'errors') {
      return <ErrorDashboard onSelectTable={(name) => openDependencyView(name, 'errors')} />;
    }
    if (view === 'table_search') {
      return <TableSearch onSelectTable={(name) => openDependencyView(name, 'card')} />;
    }
    if (view === '__check_inconsistencies__') {
      return <InconsistencyPage onBack={() => setView('home')} />;
    }
    if (view === 'slowest_tables') {
      return <SlowestTables />;
    }
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
