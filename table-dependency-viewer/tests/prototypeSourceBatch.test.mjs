import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizeSourceBatch } from '../src/utils/prototypeSourceBatch.js';
const a = { selected: true, ready: { target_schema: 'stg', target_table: 'First' }, busy: false };
test('another unfinished table blocks submission while preserving successful result', () => {
  const state = summarizeSourceBatch([a, { selected: true, ready: null }]);
  assert.equal(state.valid, false); assert.equal(state.ready, 1); assert.deepEqual(state.loads, [a.ready]);
});
test('deselecting a failed table permits submitting remaining successful tables', () => {
  const state = summarizeSourceBatch([a, { selected: false, ready: null }]);
  assert.equal(state.valid, true); assert.equal(state.selected, 1);
});
test('duplicate targets cannot silently overwrite one another', () => {
  const state = summarizeSourceBatch([a, { ...a, ready: { target_schema: 'stg', target_table: 'FIRST' } }]);
  assert.equal(state.valid, false); assert.equal(state.errors.length, 1);
});
test('editing or regenerating a row invalidates only that row and never submits a running result', () => {
  assert.equal(summarizeSourceBatch([a, { ...a, busy: true }]).valid, false);
  assert.deepEqual(summarizeSourceBatch([a, { ...a, ready: null }]).loads, [a.ready]);
});
