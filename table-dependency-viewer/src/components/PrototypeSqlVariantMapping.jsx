import { useId } from "react";

export { variantMappingPayload } from "../utils/prototypeSqlVariants";

export default function PrototypeSqlVariantMapping({ groups, choices, onChange, disabled = false }) {
  const id = useId();
  return <section className="card" style={{ marginTop: 16, padding: 20 }}>
    <fieldset disabled={disabled} style={{ border: 0, margin: 0, padding: 0, minWidth: 0 }}>
    <div className="section-title">Одна таблица · разные алгоритмы?</div>
    <p className="muted">Несколько файлов записывают в одну таблицу. Перед выполнением SQL в DEV укажите, какие файлы относятся к одному алгоритму и в каких сущностях он должен работать.</p>
    {groups.map((group, index) => {
      const choice = choices[group.target_fqn] || {};
      const update = (value) => onChange({ ...choices, [group.target_fqn]: { ...choice, ...value } });
      return <div key={group.target_fqn} style={{ borderTop: "1px solid rgba(148,163,184,.25)", paddingTop: 16, marginTop: 16 }}>
        <strong className="mono">{group.target_fqn}</strong>
        <label className="prototype-step-field" style={{ marginTop: 12 }}><span className="slow-select-label">Как используются SQL-файлы</span><select className="slow-entity-select" value={choice.mode || ""} onChange={(e) => update({ mode: e.target.value })}>
          <option value="">Выберите режим</option><option value="shared">Общий алгоритм для нескольких сущностей</option><option value="separate">Разные алгоритмы — сопоставить файлы сущностям</option>
        </select></label>
        <datalist id={`${id}-${index}`}>{group.entity_options.map((name) => <option key={name} value={name} />)}</datalist>
        {choice.mode === "shared" ? <label className="prototype-step-field" style={{ marginTop: 12 }}><span className="slow-select-label">Сущности общего алгоритма · через запятую</span><input className="slow-entity-select" list={`${id}-${index}`} value={choice.entity_name || ""} onChange={(e) => update({ entity_name: e.target.value })} placeholder={group.entity_options.join(", ") || "NIGHT, TWO_HOURS"} /><span className="muted">Все выбранные SQL-файлы образуют один алгоритм. Дополнительные YAML ссылаются на SQL первой сущности.</span></label> : null}
        {choice.mode === "separate" && <><div className="muted" style={{ marginTop: 12 }}>Одинаковая сущность у нескольких файлов объединит их в один алгоритм. Разные сущности будут проверены отдельно.</div>{group.writer_paths.map((path) => <label key={path} className="prototype-step-field" style={{ marginTop: 12 }}><span className="slow-select-label mono">{path}</span><input className="slow-entity-select" list={`${id}-${index}`} value={choice.assignments?.[path] || ""} onChange={(e) => update({ assignments: { ...choice.assignments, [path]: e.target.value } })} placeholder="Сущность этого алгоритма, например TWO_HOURS" /></label>)}</>}
        {group.common_paths.length > 0 && <details style={{ marginTop: 12 }}><summary className="muted">Общие вспомогательные SQL-файлы · {group.common_paths.length}</summary>{group.common_paths.map((path) => <div className="mono muted" key={path}>{path}</div>)}</details>}
      </div>;
    })}
    <p className="muted" style={{ marginTop: 16 }}>После сопоставления нажмите «Запустить review». У каждого алгоритма будут свои результаты проверки, YAML и INSERT SQL. Изменение сопоставления требует повторной проверки.</p>
    </fieldset>
  </section>;
}
