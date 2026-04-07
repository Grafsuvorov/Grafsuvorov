import React, { useEffect, useMemo, useRef, useState } from "react";
import { devMetaApi } from "../api/devMeta.js";
import { formatRuDateTime } from "../utils/datetime.js";

const SCHEMA_OPTIONS = [
  { value: "dm", label: "dm" },
  { value: "dm_view", label: "dm_view" },
];

function DagLoadingMiniGame({ active }) {
  const trackRef = useRef(null);
  const frameRef = useRef(null);
  const lastFrameTimeRef = useRef(0);
  const lastSpawnTimeRef = useRef(0);
  const entityIdRef = useRef(1);
  const bestScoreRef = useRef(0);
  const stateRef = useRef({
    runnerY: 0,
    velocityY: 0,
    jumpCount: 0,
    score: 0,
    packets: 0,
    speed: 5.2,
    entities: [],
    crashed: false,
    crashLabel: "",
  });
  const [gameState, setGameState] = useState({
    runnerY: 0,
    score: 0,
    packets: 0,
    entities: [],
    crashed: false,
    crashLabel: "",
    bestScore: 0,
  });

  const spawnEntity = (trackWidth, currentScore) => {
    const spawnX = trackWidth + 24;
    const hazardPool = [
      { kind: "hazard", variant: "error", label: "ERROR", width: 64, height: 32, y: 14 },
      { kind: "hazard", variant: "sql", label: "SQL", width: 58, height: 26, y: 14 },
      { kind: "hazard", variant: "warning", label: "WARN", width: 52, height: 36, y: 14 },
      { kind: "hazard", variant: "null", label: "NULL", width: 46, height: 24, y: 66 },
      { kind: "hazard", variant: "proxy", label: "407", width: 48, height: 48, y: 24 },
    ];
    const bonusPool = [
      { kind: "collectible", variant: "cache", label: "C", width: 24, height: 24, y: 88 },
      { kind: "collectible", variant: "ok", label: "+", width: 22, height: 22, y: 60 },
      { kind: "collectible", variant: "rows", label: "R", width: 26, height: 26, y: 98 },
    ];
    const pool = Math.random() < Math.max(0.26, 0.46 - currentScore * 0.01) ? bonusPool : hazardPool;
    const template = pool[Math.floor(Math.random() * pool.length)];
    return {
      id: entityIdRef.current++,
      x: spawnX,
      ...template,
    };
  };

  const resetGame = () => {
    stateRef.current = {
      runnerY: 0,
      velocityY: 0,
      jumpCount: 0,
      score: 0,
      packets: 0,
      speed: 5.2,
      entities: [],
      crashed: false,
      crashLabel: "",
    };
    lastFrameTimeRef.current = 0;
    lastSpawnTimeRef.current = 0;
    setGameState({
      runnerY: 0,
      score: 0,
      packets: 0,
      entities: [],
      crashed: false,
      crashLabel: "",
      bestScore: bestScoreRef.current,
    });
  };

  const triggerJump = () => {
    const currentState = stateRef.current;
    if (currentState.crashed || currentState.jumpCount >= 2) {
      return;
    }
    currentState.velocityY = currentState.jumpCount === 0 ? 13.8 : 11.6;
    currentState.jumpCount += 1;
  };

  const triggerDashJump = () => {
    const currentState = stateRef.current;
    if (currentState.crashed) {
      return;
    }
    if (currentState.jumpCount < 2) {
      currentState.velocityY = currentState.jumpCount === 0 ? 13.8 : 11.6;
      currentState.jumpCount += 1;
    }
    currentState.entities = currentState.entities.map((entity) => ({
      ...entity,
      x: entity.x - 42,
    }));
    currentState.score += 1.2;
  };

  useEffect(() => {
    if (!active) {
      resetGame();
      return undefined;
    }
    const onKeyDown = (event) => {
      if (event.code === "Space" || event.code === "ArrowUp") {
        event.preventDefault();
        triggerJump();
      } else if (event.code === "ArrowRight") {
        event.preventDefault();
        triggerDashJump();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [active]);

  useEffect(() => {
    if (!active) {
      if (frameRef.current) {
        window.cancelAnimationFrame(frameRef.current);
        frameRef.current = null;
      }
      return undefined;
    }
    resetGame();
    const tick = (timestamp) => {
      const trackWidth = trackRef.current?.clientWidth || 420;
      if (!lastFrameTimeRef.current) {
        lastFrameTimeRef.current = timestamp;
        lastSpawnTimeRef.current = timestamp;
      }
      const delta = Math.min(32, timestamp - lastFrameTimeRef.current);
      lastFrameTimeRef.current = timestamp;
      const step = delta / 16.6667;
      const currentState = stateRef.current;

      if (!currentState.crashed) {
        currentState.velocityY -= 1.06 * step;
        currentState.runnerY = Math.max(0, currentState.runnerY + currentState.velocityY * step);
        if (currentState.runnerY === 0) {
          currentState.velocityY = 0;
          currentState.jumpCount = 0;
        }
        currentState.speed = Math.min(9.8, 5.2 + currentState.score * 0.075);

        if (timestamp - lastSpawnTimeRef.current > Math.max(620, 1140 - currentState.score * 18)) {
          currentState.entities.push(spawnEntity(trackWidth, currentState.score));
          lastSpawnTimeRef.current = timestamp;
        }

        currentState.entities = currentState.entities
          .map((entity) => ({ ...entity, x: entity.x - currentState.speed * step }))
          .filter((entity) => entity.x + entity.width > -24);

        const runnerBox = {
          left: 34,
          right: 62,
          bottom: 14 + currentState.runnerY,
          top: 14 + currentState.runnerY + 28,
        };

        currentState.entities = currentState.entities.filter((entity) => {
          const entityBox = {
            left: entity.x,
            right: entity.x + entity.width,
            bottom: entity.y,
            top: entity.y + entity.height,
          };
          const overlaps =
            runnerBox.left < entityBox.right &&
            runnerBox.right > entityBox.left &&
            runnerBox.bottom < entityBox.top &&
            runnerBox.top > entityBox.bottom;
          if (!overlaps) {
            return true;
          }
          if (entity.kind === "collectible") {
            currentState.packets += 1;
            currentState.score += entity.variant === "rows" ? 3 : 2;
            return false;
          }
          currentState.crashed = true;
          currentState.crashLabel = entity.label;
          bestScoreRef.current = Math.max(bestScoreRef.current, currentState.score);
          return true;
        });

        currentState.score += delta / 220;
      }

      setGameState({
        runnerY: currentState.runnerY,
        score: Math.floor(currentState.score),
        packets: currentState.packets,
        entities: currentState.entities,
        crashed: currentState.crashed,
        crashLabel: currentState.crashLabel,
        bestScore: bestScoreRef.current,
      });
      frameRef.current = window.requestAnimationFrame(tick);
    };

    frameRef.current = window.requestAnimationFrame(tick);
    return () => {
      if (frameRef.current) {
        window.cancelAnimationFrame(frameRef.current);
        frameRef.current = null;
      }
    };
  }, [active]);

  if (!active) {
    return null;
  }

  return (
    <div className="dev-meta-game">
      <div className="dev-meta-game-head">
        <div>
          <div className="section-subtitle">Pipeline Hopper</div>
          <div className="muted">Пробел или стрелка вверх. Есть двойной прыжок, ошибки и бонусы.</div>
        </div>
        <div className="dev-meta-game-stats">
          <div className="dev-meta-game-score">Очки: {gameState.score}</div>
          <div className="dev-meta-game-score">Пакеты: {gameState.packets}</div>
          <div className="dev-meta-game-score">Рекорд: {gameState.bestScore}</div>
        </div>
      </div>
      <div className="dev-meta-game-track" ref={trackRef}>
        <div className="dev-meta-game-skyline" />
        <div className="dev-meta-game-runner" style={{ bottom: `${gameState.runnerY + 14}px` }}>
          <span className="dev-meta-game-runner-face">
            <span className="dev-meta-game-runner-eye" />
            <span className="dev-meta-game-runner-eye" />
          </span>
          <span className="dev-meta-game-runner-leg dev-meta-game-runner-leg-left" />
          <span className="dev-meta-game-runner-leg dev-meta-game-runner-leg-right" />
        </div>
        {gameState.entities.map((entity) => (
          <div
            key={entity.id}
            className={`dev-meta-game-entity dev-meta-game-entity-${entity.kind} dev-meta-game-entity-${entity.variant}`}
            style={{
              left: `${entity.x}px`,
              bottom: `${entity.y}px`,
              width: `${entity.width}px`,
              height: `${entity.height}px`,
            }}
          >
            <span aria-hidden="true">{entity.label}</span>
          </div>
        ))}
        <div className="dev-meta-game-ground" />
      </div>
      {gameState.crashed ? (
        <div className="dev-meta-game-footer">
          <button className="btn btn-secondary" onClick={resetGame}>
            Еще раз
          </button>
        </div>
      ) : (
        <div className="dev-meta-game-footer">
          <span>Прыжок: пробел или стрелка вверх. Бонусы собираются автоматически.</span>
          <span className="muted">Игра скрывается сама, когда загрузка завершена.</span>
        </div>
      )}
    </div>
  );
}

export default function DevMetaAdminPage({ userProfile }) {
  const [schemaName, setSchemaName] = useState("dm");
  const [generator, setGenerator] = useState({
    schema_name_gp: "dm",
    object_name: "",
    order_by: "",
  });
  const [status, setStatus] = useState(null);
  const [files, setFiles] = useState({ dev_files: [], locks: [] });
  const [selectedFile, setSelectedFile] = useState(null);
  const [content, setContent] = useState("");
  const [loading, setLoading] = useState(false);
  const [deploying, setDeploying] = useState(false);
  const [validating, setValidating] = useState(false);
  const [lockInfo, setLockInfo] = useState(null);
  const [validation, setValidation] = useState(null);
  const [message, setMessage] = useState(null);
  const [messageType, setMessageType] = useState("info");
  const [error, setError] = useState(null);
  const [fileSearch, setFileSearch] = useState("");
  const [runningDag, setRunningDag] = useState(false);
  const [dagStatus, setDagStatus] = useState(null);

  const isAdmin = userProfile?.role === "admin";
  const currentUser = userProfile?.email || userProfile?.username || "";

  const refreshStatus = async () => {
    const data = await devMetaApi.status();
    setStatus(data || null);
  };

  const refreshFiles = async (schema = schemaName) => {
    const data = await devMetaApi.files(schema);
    setFiles(data || { dev_files: [], locks: [] });
  };

  useEffect(() => {
    if (!isAdmin) return;
    refreshStatus().catch((err) => setError(err.message || "Не удалось загрузить статус"));
    refreshFiles().catch((err) => setError(err.message || "Не удалось загрузить файлы"));
  }, [isAdmin]);

  useEffect(() => {
    if (!isAdmin) return;
    refreshFiles(schemaName).catch((err) => setError(err.message || "Не удалось загрузить файлы"));
  }, [schemaName, isAdmin]);

  const formatDateTime = (value) => (value ? formatRuDateTime(value) : "—");
  const dagIsActive = ["queued", "running"].includes(String(dagStatus?.dag_run_state || "").toLowerCase());
  const dagRunState = String(dagStatus?.dag_run_state || "").toLowerCase();

  const lockRow = useMemo(() => {
    if (!selectedFile) return null;
    return (files.locks || []).find(
      (item) => item.schema_name === schemaName && item.file_name === selectedFile
    );
  }, [files.locks, schemaName, selectedFile]);

  const isLockedByAnother = Boolean(
    (lockInfo?.locked_by || lockRow?.locked_by) &&
      (lockInfo?.locked_by || lockRow?.locked_by) !== currentUser
  );

  const acquireLock = async (fileName) => {
    const data = await devMetaApi.lock({ schema_name: schemaName, file_name: fileName });
    setLockInfo(data || null);
    return data;
  };

  const handleSchemaChange = (nextSchema) => {
    setSchemaName(nextSchema);
    setSelectedFile(null);
    setContent("");
    setValidation(null);
    setLockInfo(null);
    setMessage(null);
    setMessageType("info");
    setError(null);
    setFileSearch("");
    setDagStatus(null);
  };

  const filteredFiles = useMemo(() => {
    const term = fileSearch.trim().toLowerCase();
    const rows = [...(files.dev_files || [])].sort((left, right) => {
      const leftTs = new Date(left.updated_at || 0).getTime();
      const rightTs = new Date(right.updated_at || 0).getTime();
      return rightTs - leftTs;
    });
    if (!term) {
      return rows;
    }
    return rows.filter((file) => file.file_name.toLowerCase().includes(term));
  }, [files.dev_files, fileSearch]);

  const openFile = async (fileName) => {
    setLoading(true);
    setError(null);
    setMessage(null);
    setMessageType("info");
    setValidation(null);
    try {
      await acquireLock(fileName);
      const data = await devMetaApi.readFile({ schema_name: schemaName, file_name: fileName, source: "dev" });
      setSelectedFile(fileName);
      setContent(data?.content || "");
      setMessage("Файл открыт и автоматически взят в работу.");
      await refreshFiles();
    } catch (err) {
      setError(err.message || "Не удалось открыть файл");
    } finally {
      setLoading(false);
    }
  };

  const handleValidate = async () => {
    if (!selectedFile) return;
    setValidating(true);
    setError(null);
    try {
      const data = await devMetaApi.validate({
        schema_name: schemaName,
        file_name: selectedFile,
        content,
      });
      setValidation(data);
      setMessageType(data?.valid ? "success" : "warning");
      setMessage(
        data?.valid
          ? "Проверка пройдена: файл корректен и готов к сохранению."
          : "Проверка завершилась с ошибками. Исправь их перед сохранением."
      );
    } catch (err) {
      setError(err.message || "Не удалось провалидировать файл");
    } finally {
      setValidating(false);
    }
  };

  const handleSaveAndDeploy = async () => {
    if (!selectedFile) return;
    setDeploying(true);
    setError(null);
    setMessage(null);
    setMessageType("info");
    try {
      const data = await devMetaApi.deploy({
        schema_name: schemaName,
        file_name: selectedFile,
        content,
      });
      setValidation(data?.validation || null);
      await refreshFiles();
      setMessageType("success");
      setMessage(`Файл сохранен локально и отправлен на DEV сервер: ${data?.remote_path || "успешно"}`);
    } catch (err) {
      setError(err.message || "Не удалось сохранить и отправить файл на DEV сервер");
    } finally {
      setDeploying(false);
    }
  };

  const handleRunDag = async () => {
    if (!selectedFile) return;
    setRunningDag(true);
    setError(null);
    setMessage(null);
    setMessageType("info");
    try {
      const data = await devMetaApi.runDag({
        schema_name: schemaName,
        file_name: selectedFile,
      });
      const dagRun = data?.response?.response || data?.response || {};
      setDagStatus({
        dag_id: data?.response?.dag_id || dagRun?.dag_id || selectedFile.replace(/\.[^.]+$/, ""),
        dag_run_id: dagRun?.dag_run_id,
        dag_run_state: dagRun?.state || "queued",
        failed_tasks: [],
        auto_unpaused: Boolean(data?.response?.auto_unpaused),
        dag_is_paused: Boolean(data?.response?.was_paused),
      });
      setMessageType("success");
      setMessage(`DEV DAG запущен: ${data?.response?.dag_id || dagRun?.dag_id || selectedFile.replace(/\.[^.]+$/, "")}`);
    } catch (err) {
      setError(err.message || "Не удалось запустить DEV DAG");
    } finally {
      setRunningDag(false);
    }
  };

  useEffect(() => {
    if (!dagStatus?.dag_id || !dagStatus?.dag_run_id) {
      return undefined;
    }
    const isTerminal = ["success", "failed"].includes(String(dagStatus.dag_run_state || "").toLowerCase());
    if (isTerminal) {
      return undefined;
    }
    let cancelled = false;
    const poll = async () => {
      try {
        const data = await devMetaApi.dagStatus({
          schema_name: schemaName,
          file_name: selectedFile,
          dag_id: dagStatus.dag_id,
          dag_run_id: dagStatus.dag_run_id,
          auto_unpaused: Boolean(dagStatus.auto_unpaused),
        });
        if (!cancelled) {
          setDagStatus(data?.response || null);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err.message || "Не удалось получить статус DAG");
        }
      }
    };
    poll();
    const timer = window.setInterval(poll, 7000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [dagStatus?.dag_id, dagStatus?.dag_run_id, dagStatus?.dag_run_state]);

  const handleGenerate = async () => {
    setError(null);
    setMessage(null);
    setMessageType("info");
    try {
      const orderBy = generator.order_by
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
      const targetSchema = "dm";
      const data = await devMetaApi.generate({
        schema_name_gp: generator.schema_name_gp,
        object_name: generator.object_name,
        schema_name_click: targetSchema,
        greenplum_table_name: null,
        order_by: orderBy,
      });
      if (data?.file_name) {
        await devMetaApi.lock({ schema_name: targetSchema, file_name: data.file_name });
      }
      setSchemaName(targetSchema);
      setSelectedFile(data?.file_name || null);
      setContent(data?.content || "");
      setValidation(null);
      setLockInfo(
        data?.file_name
          ? {
              schema_name: targetSchema,
              file_name: data.file_name,
              locked_by: currentUser,
            }
          : null
      );
      await refreshFiles(targetSchema);
      setMessage(`Черновик YAML создан и открыт в DEV-схеме dm: ${data?.file_name || ""}`);
    } catch (err) {
      setError(err.message || "Не удалось сгенерировать YAML");
    }
  };

  if (!isAdmin) {
    return (
      <div className="container cc-page">
        <div className="cc-surface">
          <div className="section-title">Доступ запрещён</div>
          <div className="muted">Раздел доступен только администраторам.</div>
        </div>
      </div>
    );
  }

  return (
    <div className="container cc-page">
      <section className="cc-surface dev-meta-page">
        <div className="section-title">DEV Meta Generator</div>
        <div className="section-subtitle">
          Отдельный admin-only контур для генерации, ручной правки, валидации и выкладки meta-файлов на DEV сервер без пересечения с основным набором meta.
        </div>

        <div className="dev-meta-toolbar">
          <div className="dev-meta-tabs">
            {SCHEMA_OPTIONS.map((option) => (
              <button
                key={option.value}
                className={`btn ${schemaName === option.value ? "btn-primary" : "btn-secondary"}`}
                onClick={() => handleSchemaChange(option.value)}
              >
                {option.label}
              </button>
            ))}
          </div>
          <div className="muted">
            Lock TTL: {status?.lock_ttl_minutes ?? 30} минут. Сейчас блокировок: {status?.locks_count ?? 0}
          </div>
        </div>

        {(message || error) && (
          <div className={`dev-meta-feedback ${error ? "error" : messageType}`}>
            <div className="dev-meta-feedback-title">
              {error
                ? "Операция не выполнена"
                : messageType === "success"
                  ? "Успешно"
                  : messageType === "warning"
                    ? "Нужно исправить"
                    : "Статус"}
            </div>
            <div className="dev-meta-feedback-text">{error || message}</div>
          </div>
        )}

        <div className="dev-meta-generator">
          <div className="section-subtitle">Новый YAML из параметров</div>
          <div className="dev-meta-generator-grid">
            <label className="admin-field">
              <span>GP схема</span>
              <input
                value={generator.schema_name_gp}
                onChange={(e) => setGenerator((prev) => ({ ...prev, schema_name_gp: e.target.value }))}
                placeholder="dm"
              />
            </label>
            <label className="admin-field">
              <span>Имя таблицы / объекта</span>
              <input
                value={generator.object_name}
                onChange={(e) => setGenerator((prev) => ({ ...prev, object_name: e.target.value }))}
                placeholder="counterparty_profile"
              />
            </label>
            <label className="admin-field dev-meta-generator-wide">
              <span>ORDER BY</span>
              <input
                value={generator.order_by}
                onChange={(e) => setGenerator((prev) => ({ ...prev, order_by: e.target.value }))}
                placeholder="counterparty_code, dttm_updated"
              />
            </label>
          </div>
          <div className="dev-meta-generator-actions">
            <button className="btn btn-primary" onClick={handleGenerate}>
              Сгенерировать черновик
            </button>
          </div>
        </div>

        <div className="dev-meta-browser">
          <div className="dev-meta-file-block">
            <div className="dev-meta-file-head">
              <div>
                <div className="section-subtitle">DEV файлы</div>
                <div className="muted">Открытие файла сразу берет его в работу для текущего администратора.</div>
              </div>
              <div className="dev-meta-file-tools">
                <input
                  className="dev-meta-file-search"
                  value={fileSearch}
                  onChange={(e) => setFileSearch(e.target.value)}
                  placeholder="Поиск по имени файла"
                />
                <div className="muted">Сортировка: сначала последние изменения</div>
              </div>
            </div>
            <div className="dev-meta-file-list">
              {filteredFiles.map((file) => (() => {
                const fileLock = (files.locks || []).find(
                  (item) => item.schema_name === schemaName && item.file_name === file.file_name
                );
                const blocked = fileLock?.locked_by && fileLock.locked_by !== currentUser;
                return (
                  <button
                    key={`dev-${file.file_name}`}
                    className={`dev-meta-file ${selectedFile === file.file_name ? "active" : ""} ${blocked ? "blocked" : ""}`}
                    onClick={() => openFile(file.file_name)}
                    disabled={blocked}
                  >
                    <span className="mono dev-meta-file-name" title={file.file_name}>{file.file_name}</span>
                    <span className="muted">{formatDateTime(file.updated_at)}</span>
                    {file.last_action_by ? (
                      <span className="dev-meta-file-meta">
                        {file.last_action_by} · {formatDateTime(file.last_action_at)}
                      </span>
                    ) : null}
                    {blocked ? <span className="dev-meta-file-badge">Занят</span> : null}
                  </button>
                );
              })())}
            </div>
          </div>
        </div>

        <div className="dev-meta-layout">
          <div className="dev-meta-editor-shell">
            <div className="dev-meta-editor-head">
              <div>
                <div className="section-subtitle">Редактор</div>
                <div className="muted">
                  {selectedFile ? `${schemaName}/${selectedFile}` : "Сгенерируйте новый YAML или выберите DEV-файл"}
                </div>
              </div>
              <div className="dev-meta-actions">
                <button className="btn btn-secondary" onClick={handleValidate} disabled={!selectedFile || validating}>
                  {validating ? "Проверяем..." : "Проверить"}
                </button>
                <button
                  className="btn btn-primary"
                  onClick={handleSaveAndDeploy}
                  disabled={!selectedFile || deploying || isLockedByAnother || !status?.deploy?.configured}
                >
                  {deploying ? "Сохраняем и отправляем..." : "Сохранить и отправить на DEV"}
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={handleRunDag}
                  disabled={!selectedFile || runningDag || isLockedByAnother || !status?.airflow?.configured}
                >
                  {runningDag ? "Запускаем DAG..." : "Запустить DEV DAG"}
                </button>
              </div>
            </div>

            <div className="dev-meta-lock-bar">
              <span>Lock:</span>
              <strong>{lockInfo?.locked_by || lockRow?.locked_by || "нет"}</strong>
              <span className="muted">
                {lockInfo?.expires_at || lockRow?.expires_at ? `до ${formatDateTime(lockInfo?.expires_at || lockRow?.expires_at)}` : ""}
              </span>
            </div>

            {dagStatus && (
              <div className="dev-meta-dag-status">
                <div className="section-subtitle">Статус DEV DAG</div>
                <div className="dev-meta-dag-grid">
                  <div className="dev-meta-dag-card">
                    <span className="label">Run</span>
                    <strong className="mono">{dagStatus.dag_run_id || "—"}</strong>
                  </div>
                  <div className={`dev-meta-dag-card dev-meta-dag-state dev-meta-dag-state-${dagRunState || "idle"}`}>
                    <span className="label">Статус запуска</span>
                    <strong>{dagStatus.dag_run_state || "—"}</strong>
                  </div>
                </div>
                {dagStatus.failed_tasks?.length ? (
                  <div className="dev-meta-dag-failed">
                    Ошибки: {dagStatus.failed_tasks.map((task) => `${task.task_id} (${task.state})`).join(", ")}
                  </div>
                ) : null}
                <DagLoadingMiniGame active={dagIsActive} />
              </div>
            )}

            {validation && (
              <div className="dev-meta-validation">
                <div className="section-subtitle">Результат проверки</div>
                <div className={`dev-meta-validation-pill ${validation.valid ? "ok" : "bad"}`}>
                  {validation.valid ? "Файл валиден" : "Есть ошибки"}
                </div>
                {validation.errors?.length ? (
                  <ul className="dev-meta-validation-list">
                    {validation.errors.map((item, idx) => (
                      <li key={`err-${idx}`}>{item}</li>
                    ))}
                  </ul>
                ) : null}
                {validation.warnings?.length ? (
                  <ul className="dev-meta-validation-list warning">
                    {validation.warnings.map((item, idx) => (
                      <li key={`warn-${idx}`}>{item}</li>
                    ))}
                  </ul>
                ) : null}
              </div>
            )}

            <textarea
              className="dev-meta-editor"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              disabled={isLockedByAnother}
              placeholder="Сгенерируйте новый YAML или откройте DEV-файл, чтобы начать работу"
            />

          </div>
        </div>
      </section>
    </div>
  );
}
