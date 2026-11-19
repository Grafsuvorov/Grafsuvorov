import test from "node:test";
import assert from "node:assert/strict";
import { mergeReviewRetry, reviewItemNeedsRetry, reviewResultWithItems } from "../src/utils/prototypeReviewRetry.js";

const build = (item) => ({ ...item, key_attributes_text: (item.key_attributes || []).join(", ") });
const previous = [
  { item_id: "good", sql_fingerprint: "good1", checks: { row_count: 100 }, execution: { status: "ok" }, comment: "Keep this", key_attributes_text: "id" },
  { item_id: "bad", sql_fingerprint: "bad1", execution: { status: "error" }, checks: {}, key_attributes_text: "new_key", filter_text: "active is true" },
];
const fresh = {
  source_manifest: [{ item_id: "good", sql_fingerprint: "good1" }, { item_id: "bad", sql_fingerprint: "bad2" }],
  review_items: [{ item_id: "bad", sql_fingerprint: "bad2", execution: { status: "ok" }, checks: { row_count: 200 }, key_attributes: ["new_key"], warnings: [] }],
  execution: [{ item_id: "bad", status: "ok" }], status: "ok",
};

test("retry preserves successful results and analyst edits, replacing failed execution", () => {
  const merged = mergeReviewRetry(previous, fresh, build);
  assert.deepEqual(merged[0].checks, { row_count: 100 });
  assert.equal(merged[0].comment, "Keep this");
  assert.equal(merged[1].filter_text, "active is true");
  assert.equal(merged[1].checks.row_count, 200);
  assert.equal(merged[1].execution.status, "ok");
  assert.equal(merged[1].last_checked_key_attributes_text, "new_key");
  assert.equal(merged[1].checks_stale, false);
});

test("changed SQL in an unselected object becomes stale without executing it", () => {
  const changed = { ...fresh, source_manifest: [{ item_id: "good", sql_fingerprint: "changed" }, fresh.source_manifest[1]] };
  const merged = mergeReviewRetry(previous, changed, build);
  assert.equal(merged[0].source_stale, true);
  assert.equal(merged[0].checks.row_count, 100);
  assert.equal(reviewItemNeedsRetry(merged[0]), true);
});

test("summary removes old failed execution and keeps successful neighbours", () => {
  const merged = mergeReviewRetry(previous, fresh, build);
  const result = reviewResultWithItems({ execution: [{ item_id: "good", status: "ok" }, { item_id: "bad", status: "error" }] }, fresh, merged, ["bad"]);
  assert.equal(result.status, "ok");
  assert.deepEqual(result.execution, [{ item_id: "good", status: "ok" }, { item_id: "bad", status: "ok" }]);
  assert.equal(result.composition_stale, false);
});

test("new objects in MR require a full review", () => {
  const changed = { ...fresh, source_manifest: [...fresh.source_manifest, { item_id: "new", sql_fingerprint: "new1" }] };
  assert.equal(reviewResultWithItems({}, changed, mergeReviewRetry(previous, changed, build), ["bad"]).composition_stale, true);
});

test("dependent results become stale after upstream rerun without losing their data", () => {
  const merged = mergeReviewRetry(previous, { ...fresh, invalidated_item_ids: ["good"] }, build);
  assert.equal(merged[0].source_stale, true);
  assert.equal(merged[0].checks.row_count, 100);
});

test("key edits made while retry is running remain visible and require rechecking", () => {
  const edited = [previous[0], { ...previous[1], key_attributes_text: "another_key", comment: "Typed during retry" }];
  const merged = mergeReviewRetry(edited, fresh, build);
  assert.equal(merged[1].comment, "Typed during retry");
  assert.equal(merged[1].key_attributes_text, "another_key");
  assert.equal(merged[1].checks_stale, true);
});

test("failed preparation, duplicate checks and validation errors are retryable", () => {
  assert.equal(reviewItemNeedsRetry({ preparation: { status: "error" } }), true);
  assert.equal(reviewItemNeedsRetry({ checks: { duplicate_groups: 2 } }), true);
  assert.equal(reviewItemNeedsRetry({ validation_errors: ["invalid SQL"] }), true);
  assert.equal(reviewItemNeedsRetry(previous[0]), false);
});
