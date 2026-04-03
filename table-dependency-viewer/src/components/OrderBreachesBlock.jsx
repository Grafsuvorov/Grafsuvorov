import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

export default function OrderBreachesBlock() {
  const [items, setItems] = useState([]);
  const navigate = useNavigate();

  useEffect(() => {
    fetch("/api/order-breaches")
      .then(r => r.json())
      .then(data => setItems(data.slice(0, 5)));
  }, []);

  if (!items.length) return null;

  return (
    <div className="card">
      <div className="card-title">
        Load order breaches
      </div>

      <div className="grid grid-3">
        {items.map(item => (
          <div key={item.target_fqn} className="mini-card warning">
            <div className="mono title">
              {item.target_fqn}
            </div>

            <div className="badge warning">
              ORDER BREACH · {item.severity}
            </div>

            <div className="kv">
              <span>Target:</span>
              <span>{item.target_last_load}</span>

              <span>Upstream:</span>
              <span>{item.worst_upstream}</span>

              <span>Gap:</span>
              <span>+{item.gap_minutes} min</span>
            </div>

            <div className="actions">
              <button
                onClick={() =>
                  navigate(`/order-breach/${item.target_fqn}`)
                }
              >
                Details
              </button>

              <button
                className="secondary"
                onClick={() =>
                  navigate(`/dependency-graph/${item.target_fqn}`)
                }
              >
                Graph
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
