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

test('existing target matching ignores display quotes and case without changing physical name', async () => {
  const { sourceTargetKey, sourceDetailsForm } = await import('../src/utils/prototypeSourceBatch.js');
  assert.equal(sourceTargetKey(' "BIP_/BIC/Name" '), sourceTargetKey('bip_/bic/name'));
  const form = { target_table: 'bip_/bic/name', fields: 'ALL', server_id: '', primary_key: '', source_schema: '' };
  const next = sourceDetailsForm(form, { table_name: 'BIP_/BIC/Name', fields: 'ID,KEY', primary_key: '"ID"', metadata: { source_id: 2, source_schema_name: 'SAPSR3' } });
  assert.equal(next.target_table, 'BIP_/BIC/Name');
  assert.equal(next.server_id, '2'); assert.equal(next.fields, 'ID,KEY'); assert.equal(next.source_schema, 'SAPSR3');
});
test('autofill preserves fields manually edited while the lookup was pending', async () => {
  const { sourceDetailsForm } = await import('../src/utils/prototypeSourceBatch.js');
  const next = sourceDetailsForm({ fields: 'CUSTOM', primary_key: 'MANUAL' },
    { fields: 'ID,KEY', primary_key: '"ID"', entity_name: 'DAILY' }, new Set(['fields', 'primary_key']));
  assert.equal(next.fields, 'CUSTOM'); assert.equal(next.primary_key, 'MANUAL'); assert.equal(next.entity_name, 'DAILY');
});

test('missing STG confirmation from an old server cannot look like complete success', async () => {
  const { sourceTaskWarning } = await import('../src/utils/prototypeSourceBatch.js');
  const loads = [{ target_schema: 'stg', target_table: 'First' }, { target_schema: 'stg', target_table: 'Second' }];
  assert.match(sourceTaskWarning({ issue: { issue_id: 'DWH-19' } }, loads), /не подтвердил/);
  assert.equal(sourceTaskWarning({ issue: { issue_id: 'DWH-19' }, task_contents: { source_targets: ['stg.Second', 'stg.First'] } }, loads), '');
  assert.match(sourceTaskWarning({ issue: { issue_id: 'DWH-19' }, task_contents: { source_targets: ['stg.First'] } }, loads), /не подтвердил/);
});
