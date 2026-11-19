export function variantMappingPayload(groups, choices) {
  return groups.map((group) => {
    const choice = choices[group.target_fqn] || {};
    if (choice.mode === "shared") return { target_fqn: group.target_fqn, mode: "shared", entity_name: choice.entity_name || "" };
    const variants = new Map();
    for (const path of group.writer_paths) {
      const name = (choice.assignments?.[path] || "").trim();
      if (!name) throw new Error(`Укажите сущность для SQL-файла ${path}`);
      const key = name.split(",").map((n) => n.trim().toLowerCase()).filter(Boolean).sort().join(",");
      const variant = variants.get(key) || { entity_name: name, paths: [] };
      variant.paths.push(path); variants.set(key, variant);
    }
    if (choice.mode !== "separate" || variants.size < 2) throw new Error(`Выберите разные сущности алгоритмов ${group.target_fqn} или общий режим SQL`);
    return { target_fqn: group.target_fqn, mode: "separate", variants: [...variants.values()] };
  });
}
