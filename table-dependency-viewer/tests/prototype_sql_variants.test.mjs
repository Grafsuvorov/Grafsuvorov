import test from "node:test";
import assert from "node:assert/strict";
import { variantMappingPayload } from "../src/utils/prototypeSqlVariants.js";

const groups = [{ target_fqn: "dm.sb_wuc", writer_paths: ["dm.sb_wuc.sql", "dm_update.sb_wuc.sql", "extra.sql"] }];

test("keeps shared SQL choice and multiple entities", () => {
  assert.deepEqual(variantMappingPayload(groups, { "dm.sb_wuc": { mode: "shared", entity_name: "SB_WUC, 2HOURS" } }), [
    { target_fqn: "dm.sb_wuc", mode: "shared", entity_name: "SB_WUC, 2HOURS" },
  ]);
});

test("groups files belonging to the same algorithm, keeping alternatives separate", () => {
  const payload = variantMappingPayload(groups, { "dm.sb_wuc": { mode: "separate", assignments: {
    "dm.sb_wuc.sql": "SB_WUC", "dm_update.sb_wuc.sql": "2HOURS", "extra.sql": "sb_wuc",
  } } });
  assert.deepEqual(payload[0].variants, [
    { entity_name: "SB_WUC", paths: ["dm.sb_wuc.sql", "extra.sql"] },
    { entity_name: "2HOURS", paths: ["dm_update.sb_wuc.sql"] },
  ]);
});

test("every writer file needs an explicit assignment", () => {
  assert.throws(() => variantMappingPayload(groups, { "dm.sb_wuc": { mode: "separate", assignments: {} } }), /Укажите сущность/);
});

test("separate mode requires different algorithms", () => {
  assert.throws(() => variantMappingPayload(groups, { "dm.sb_wuc": { mode: "separate", assignments: {
    "dm.sb_wuc.sql": "SB_WUC", "dm_update.sb_wuc.sql": "sb_wuc", "extra.sql": "SB_WUC",
  } } }), /Выберите разные сущности/);
});
