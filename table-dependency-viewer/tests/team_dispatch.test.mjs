import test from 'node:test';
import assert from 'node:assert/strict';
import { currentEmployees, recommendEngineers, taskStage, parseObjects } from '../src/utils/teamDispatch.js';
const people = [1, 2, 3].map(id => ({user_id:id,engineer:`Engineer ${id}`,email:`u${id}@example.com`,is_active:id!==3}));
const task = (id, owner, state='В работе', extra={}) => ({issue_id:id, owner_id:owner, is_open:true, state, objects:[], remaining_hours:null,...extra});
const data = (tasks, extra={}) => ({engineers:people,tasks,object_links:[],...extra});

test('all open statuses are grouped without treating release as development', () => {
  assert.equal(taskStage(task('1',1,'В работе')),'active');
  assert.equal(taskStage(task('1',1,'ПРОД. Подлежит проверке')),'active');
  assert.equal(taskStage(task('1',1,'Зарегистрирована')),'queue');
  assert.equal(taskStage(task('1',1,'Ожидание релиза')),'release');
  assert.equal(taskStage(task('1',1,'Требуется уточнение')),'paused');
});
test('closed work and historical hours never increase current load', () => {
  const d=data([task('1',1,'Done',{is_open:false,lifetime_hours:9999}),task('2',2)]);
  assert.equal(currentEmployees(d)[0].load,0);
  assert.equal(recommendEngineers(d)[0].user_id,1);
  assert.deepEqual(recommendEngineers({...d,days:30}).map(e=>e.score),recommendEngineers({...d,days:365}).map(e=>e.score));
});
test('capacity mode prefers fewer working tasks and excludes disabled people', () => {
  const candidates=recommendEngineers(data([task('1',1),task('2',1),task('3',2)]),{strategy:'capacity'});
  assert.equal(candidates[0].user_id,2);
  assert.equal(candidates.length,2);
});
test('selected task is excluded from comparison, avoiding self-assignment penalty', () => {
  const d=data([task('new',1)]);
  assert.equal(recommendEngineers(d,{taskId:'new'}).find(e=>e.user_id===1).open.length,0);
  assert.equal(currentEmployees(d)[0].open.length,1);
});
test('exact shared objects supply concrete reasons and favour continuity', () => {
  const d=data([task('existing',1,'В работе',{objects:['dm.sales']}),task('new',null,'New',{objects:['dm.sales']})]);
  const c=recommendEngineers(d,{taskId:'new'});
  assert.equal(c[0].user_id,1);
  assert.equal(c[0].exactCount,1);
  assert.equal(c[0].matches[0].task.issue_id,'existing');
});
test('real direct dependency is matched in either direction', () => {
  const d=data([task('existing',1,'В работе',{objects:['dds.sales']})],{object_links:[{source:'dds.sales',target:'dm.report'}]});
  const c=recommendEngineers(d,{objects:['dm.report'],strategy:'context'});
  assert.equal(c[0].user_id,1);
  assert.equal(c[0].relatedCount,1);
  assert.deepEqual(c[0].matches[0].related,[{source:'dds.sales',target:'dm.report'}]);
});
test('same schema or same upstream ancestor alone do not invent a relationship', () => {
  const c=recommendEngineers(data([task('a',1,'В работе',{objects:['dm.other']})]),{objects:['dm.report']});
  assert.equal(c.find(e=>e.user_id===1).matches.length,0);
});
test('unknown and exhausted estimates remain visible rather than imply free capacity', () => {
  const e=currentEmployees(data([task('1',1),task('2',1,'В работе',{remaining_hours:0,estimate_exhausted:true})]))[0];
  assert.equal(e.unknown,2);
  assert.equal(e.load,6);
});
test('estimated queue remaining counts, release effort does not count as development remainder', () => {
  const e=currentEmployees(data([task('1',1,'New',{remaining_hours:16}),task('2',1,'Ожидание релиза',{remaining_hours:90})]))[0];
  assert.equal(e.remaining,16);
  assert.equal(e.load,3.25);
});
test('manual object input normalizes, extracts and deduplicates qualified names', () => {
  assert.deepEqual(parseObjects('DM.Report, dds.sales\nDM.Report'),['dm.report','dds.sales']);
});
