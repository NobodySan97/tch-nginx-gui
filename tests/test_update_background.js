// Exercise the check-update lifecycle and the upgrade_gui anchor with the
// real shared-script.js code (ported from upstream efeb7642, adapted to the
// fork watchdog polling toward commandlogread.lua and its state machine).
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const source = fs.readFileSync('decompressed/gui_file/www/docroot/js/shared-script.js', 'utf8');
const handlers = {}, requests = [], errors = [], removed = [], actions = [], timers = new Map();
let spinning = false, label = '', upgraded = 0;

// Every selector shares one chainable object so assertions can observe text.
const nodes = {};
function chain(select) {
  const self = {
    off() {return self;},
    on(name, fn) {if (name === 'click.guiUpdate') handlers[select] = fn; return self;},
    attr() {return self;},
    addClass(name) {if (name === 'fa-spin') spinning = true; return self;},
    removeClass(name) {if (name === 'fa-spin') spinning = false; return self;},
    add(name) {return self;},
    remove() {removed.push(select); return self;},
    parent() {return self;},
    appendTo() {errors.push(this.value); return self;},
    text(value) {this.value = value; if (select === '.gui_version_status_text' && value !== undefined) label = value; return self;},
    each() {return self;},
    toggleClass() {return self;},
    fadeOut() {return self;},
    fadeIn() {return self;}
  };
  nodes[select] = self;
  return self;
}
function $(value) {
  if (typeof value === 'function') {value(); return undefined;}
  return chain(String(value));
}
$.ajax = options => {
  const request = {
    options, failures: 0,
    respond(data) {options.success && options.success(data);},
    fail() {options.error && options.error();}
  };
  requests.push(request); return request;
};

const context = {$, KoRequest: {}, gui_var: {gui_updated: 'updated', gui_outdated: 'outdated'},
  postAction(action, logModal, close, target) {actions.push({action, logModal, target});},
  tch: {elementCSRFtoken: () => ({})},
  setInterval(fn, delay) {assert.strictEqual(delay, 1000); timers.set(timers.size + 1, fn); return timers.size;},
  clearInterval(id) {timers.delete(id);}};
vm.createContext(context);
vm.runInContext(source.slice(source.indexOf('\tfunction linkCheckUpdate()'), source.indexOf('\n\tfunction freshStyle')), context);
context.linkCheckUpdate();
assert(handlers['.check_update'] && handlers['.upgrade_gui'], 'both click handlers must be registered');
const event = {preventDefault() {}, stopPropagation() {}};
const tick = () => [...timers.values()].forEach(fn => fn());
const latest = () => requests[requests.length - 1];

// Acceptance + duplicate suppression: a second click while running must not
// start another background check nor open a modal.
handlers['.check_update'](event); handlers['.check_update'](event);
assert.strictEqual(actions.length, 1);
assert.strictEqual(actions[0].action, 'checkver');
assert.strictEqual(actions[0].target, '/modals/modgui-modal.lp?auto_update=true');
assert(spinning); assert.strictEqual(timers.size, 1);

// The poll goes through the fork commandlogread endpoint with the CSRF token.
tick(); const first = latest();
assert.strictEqual(first.options.url, '/ajax/commandlogread.lua?auto_update=true');
assert.strictEqual(first.options.type, 'POST');
first.respond({state: 'Checking'});
assert.strictEqual(label, '');

// Transient poll failures below the fork threshold keep waiting in silence.
first.fail(); tick(); latest().fail(); assert(spinning); assert.strictEqual(timers.size, 1);

// Exhaust the fork threshold: the watch finally reports the failure visibly.
for (let i = 4; i < 18; ++i) {tick(); latest().fail();}
assert(!spinning); assert.strictEqual(timers.size, 0);
assert.strictEqual(errors.pop(), 'Unable to check updates. Please retry.');
assert.strictEqual(actions.length, 1);

// Restart after the failure clears the stale error banner first.
handlers['.check_update'](event);
assert.strictEqual(removed[removed.length - 1], '.check_update_error');
tick(); latest().respond({state: 'Complete', new_version_text: '9.9.0'});
assert.strictEqual(label, 'outdated'); assert(!spinning); assert.strictEqual(timers.size, 0);

// Known-updated result renders the updated label instead.
handlers['.check_update'](event);
tick(); latest().respond({state: 'Complete', new_version_text: 'Unknown'});
assert.strictEqual(label, 'updated'); assert(!spinning); assert.strictEqual(timers.size, 0);

// The hardened watchdog: a stalled background check must time out visibly.
handlers['.check_update'](event);
for (let i = 0; i < 21; ++i) tick();
assert(!spinning); assert.strictEqual(timers.size, 0);
assert.strictEqual(errors.pop(), 'Update check timed out. Please retry.');

// The anchor added by upstream efeb7642 to 001_modgui.lp starts the upgrade
// from the card itself, opening the stream log modal (logModal hint).
handlers['.upgrade_gui'](event);
assert.strictEqual(actions[actions.length - 1].action, 'system_upgrade_gui');
assert.strictEqual(actions[actions.length - 1].logModal, 1);
assert.strictEqual(actions[actions.length - 1].target, '/modals/modgui-modal.lp?auto_update=true');
assert.strictEqual(upgraded, 0);

console.log('Background update: acceptance, duplicates, fork watchdog polling, visible errors, timeout and upgrade anchor passed');
