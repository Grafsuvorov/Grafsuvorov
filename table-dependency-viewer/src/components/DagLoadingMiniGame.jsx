import React, { useEffect, useRef, useState } from "react";

export default function DagLoadingMiniGame({ active }) {
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
    if (currentState.crashed || currentState.jumpCount >= 2) return;
    currentState.velocityY = currentState.jumpCount === 0 ? 13.8 : 11.6;
    currentState.jumpCount += 1;
  };

  const triggerDashJump = () => {
    const currentState = stateRef.current;
    if (currentState.crashed) return;
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
          if (!overlaps) return true;
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

  if (!active) return null;

  return (
    <div className="dev-meta-game">
      <div className="dev-meta-game-head">
        <div>
          <div className="section-subtitle">Pipeline Hopper</div>
          <div className="muted">Пробел или стрелка вверх. Есть двойной прыжок.</div>
        </div>
        <div className="dev-meta-game-stats">
          <div className="dev-meta-game-score">Очки: {gameState.score}</div>
          <div className="dev-meta-game-score">Пакеты: {gameState.packets}</div>
          <div className="dev-meta-game-score">Рекорд: {Math.floor(gameState.bestScore)}</div>
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
          <span>Прыжок: пробел или стрелка вверх.</span>
          <span className="muted">Игра скрывается сама после завершения загрузки.</span>
        </div>
      )}
    </div>
  );
}
