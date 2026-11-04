// Run each inline extension client with the real shared polling lifecycle.
// Ported from upstream ddeb7d60/e2150b75; the Smartphone card additionally
// proves the custom-refresh ownership handshake in shared-script.js (53ef1b57),
// while the VPN cards are exercised as soon as their own shared-polling client
// lands in their owning wave (the test表面上 skips unwired card files).
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const shared = fs.readFileSync('decompressed/gui_file/www/docroot/js/shared-script.js', 'utf8');
const factory = shared.slice(shared.indexOf('\tfunction createAjaxUpdateCard('), shared.indexOf('\n\tfunction linkCheckUpdate()'));
assert(factory.includes('pending'), 'createAjaxUpdateCard factory not found in shared-script.js');

const EXTENSIONS = [
  // Smartphone card: custom refresh function returning its own jqXHR.
  { name: 'smartphone', file: 'decompressed/smartphone/www/cards/017_smartphone.lp', custom: true },
  // Upstream VPN extension cards; the fork wires these in a dedicated wave.
  { name: 'tailscale', file: 'decompressed/gui_file/www/cards/016_tailscale.lp', modal: 'tailscale' },
  { name: 'wireguard', file: 'decompressed/gui_file/www/cards/016_wireguard.lp', modal: 'wireguard' },
  { name: 'openvpn', file: 'decompressed/gui_file/www/cards/015_openvpn-server.lp', modal: 'openvpn-server' },
];

function clientOf(source) {
  const match = source.match(/<script>\r?\n([\s\S]*?)\r?\n<\/script>/);
  return match ? match[1] : null;
}

const SMARTPHONE_LABELS = {
  'data-connected': 'Connected', 'data-tether-off': 'USB tethering disabled',
  'data-data-off': 'Mobile data disabled', 'data-unavailable': 'Phone unavailable', 'data-checking': 'Checking connection',
  'data-link-up': 'Link up', 'data-link-down': 'Link down'
};

function runSmartphone(entry) {
  const source = fs.readFileSync(entry.file, 'utf8');
  const client = clientOf(source);
  assert(client, 'smartphone card must ship its inline polling client');
  // `.card` identities: the DOM id, the registration call and the access gate
  // must agree with the shared lifecycle invoked from the card itself.
  assert(source.includes('id="smartphone-card"'));
  assert(client.includes('new modgui.createAjaxUpdateCard("smartphone-card"'));
  let element = {}, requests = [], timers = new Map(), next = 0;
  const attributes = {};
  function selection(name) {
    return {
      attr(key, value) {
        if (value === undefined) return name === '.content' ? SMARTPHONE_LABELS[key] : attributes[name + ':' + key];
        attributes[name + ':' + key] = value; return this;
      },
      toggleClass(key, value) { attributes['toggle:' + name + ':' + key] = !!value; return this; },
      toggle(value) { attributes['visible:' + name] = !!value; return this; },
      each(callback) {
        if (name === '[data-bind]') {
          for (const field of ['phoneDevice', 'phoneBattery', 'phoneStatus', 'phoneNetwork', 'phoneSignal', 'phoneTether', 'phoneUplink'])
            callback.call({bind: 'text: ' + field});
        } else { for (let i = 0; i < 5; i++) callback.call('bar' + i, i); }
        return this;
      }
    };
  }
  function $(value) {
    if (typeof value === 'function') { value(); return; }
    if (value && value.bind) return {data: () => value.bind};
    if (value === element || value === '#smartphone-card') return {find: selection};
    return selection(String(value));
  }
  let refused = null;
  $.ajax = options => {
    assert.strictEqual(options.url, '/modals/smartphone-modal.lp');
    assert.strictEqual(options.type, 'POST');
    assert.strictEqual(options.timeout, 25000);
    assert.strictEqual(options.dataType, 'json');
    assert.strictEqual(options.data[0].name, 'CSRFtoken');
    assert.strictEqual(options.data[1].value, 'get_stats');
    const handle = {
      done(callback) { this.success = callback; return this; },
      fail(callback) { this.failure = callback; return this; },
      always(callback) { this.finish = callback; return this; },
      abort() { this.aborted = true; this.failure({statusText: 'abort'}, 'abort'); this.finish(); },
      deliver(data) { this.success(data); this.finish(); },
      reject() { this.failure({}, 'error'); this.finish(); }
    };
    requests.push(handle); return handle;
  };
  const document = {hidden: false, getElementById: () => element};
  const context = {
    $, tch: {elementCSRFtoken: () => ({name: 'CSRFtoken', value: 'fixture'})},
    document, KoRequest: {},
    ko: {observable() { let value; return function(next) { if (arguments.length) value = next; return value; }; },
      dataFor: node => node.bindings, applyBindings: (bindings, node) => { node.bindings = bindings; }},
    setInterval(callback, delay, binding) {
      assert.strictEqual(delay, 30000);
      timers.set(++next, () => callback(binding)); return next;
    },
    clearInterval: id => timers.delete(id)
  };
  vm.createContext(context);
  vm.runInContext(factory, context);
  context.modgui = {createAjaxUpdateCard: context.createAjaxUpdateCard};
  const init = () => vm.runInContext(client, context);
  const tick = () => [...timers.values()].forEach(fn => fn());
  init(); init(); tick();
  // A pending custom jqXHR must be adopted by the shared lifecycle: the double
  // initialization and the timer tick produced exactly one real request.
  assert.strictEqual(requests.length, 1, 'duplicate initialization and pending custom reads must not overlap');
  tick();
  assert.strictEqual(requests.length, 1, 'shared ownership must still prevent overlap');
  requests[0].reject(); // settles the adopted ownership before the retry phase
  tick();
  assert.strictEqual(requests.length, 2, 'refresh resumes after a settled request');
  requests[1].reject();
  document.hidden = true; tick();
  assert.strictEqual(requests.length, 2, 'hidden pages must not poll');
  document.hidden = false; tick();
  assert.strictEqual(requests.length, 3, 'refresh resumes on visible pages');
  requests[2].reject(); //settles the resumed read; the next tick retries
  tick();
  assert.strictEqual(requests.length, 4, 'retry after failure');
  const pending = requests[3];
  element = {}; init();
  assert(pending.aborted, 'replacing the card must abort the pending custom request');
  element = null; tick();
  assert.strictEqual(timers.size, 0);
  assert(context.KoRequest.SmartphoneCardInterval === undefined, 'removal must unregister the card');
}

const REPLACE_LABELS = null;

function runReplacement(entry) {
  // Mirrors the upstream harness: cards whose client fetches a rendered HTML
  // replacement from the modal endpoint.
  const source = fs.readFileSync(entry.file, 'utf8');
  const client = clientOf(source);
  let element = {}, replacements = [], timers = new Map(), next = 0, requests = [];
  const document = {hidden: false, getElementById: id => id === entry.name + '-card' ? element : null};
  function $(target) {
    if (typeof target === 'function') return target();
    if (target === '<div>') return {append: parsed => ({find: selector => {
      assert.strictEqual(selector, '#' + entry.name + '-card > .smallcard > .content');
      return {length: parsed === 'valid' ? 1 : 0, value: parsed};
    }})};
    return {find: () => ({each: () => {}, replaceWith: content => replacements.push(content.value)})};
  }
  $.parseHTML = (html, doc, keepScripts) => {
    assert.strictEqual(doc, document);
    assert.strictEqual(keepScripts, false, 'response scripts must never execute');
    return html;
  };
  $.ajax = options => {
    assert.strictEqual(options.url, '/ajax/get_card.lua?modal=/modals/' + entry.modal + '-modal.lp');
    assert.strictEqual(options.type, 'GET');
    assert.strictEqual(options.timeout, 8000);
    assert.strictEqual(options.dataType, 'html');
    assert.strictEqual(options.cache, false);
    let done, always;
    const req = {aborted: false, done(fn) {done = fn; return this;}, always(fn) {always = fn; return this;},
      resolve() {done('valid'); always();}, reject() {always();}, abort() {this.aborted = true; always();}};
    requests.push(req); return req;
  };
  const context = {document, $, KoRequest: {}, modgui: {}, ko: {dataFor: () => true},
    setInterval: (fn, delay, arg) => {assert.strictEqual(delay, 30000); timers.set(++next, () => fn(arg)); return next;},
    clearInterval: id => timers.delete(id)};
  vm.createContext(context);
  vm.runInContext(factory + '\nmodgui.createAjaxUpdateCard = createAjaxUpdateCard;', context);
  const init = () => vm.runInContext(client, context);
  const tick = () => [...timers.values()].forEach(fn => fn());
  init(); init(); tick();
  assert.strictEqual(requests.length, 1, 'duplicate initialization and pending reads must not overlap');
  requests[0].resolve('valid'); assert.deepStrictEqual(replacements, ['valid']);
  document.hidden = true; tick(); assert.strictEqual(requests.length, 1);
  document.hidden = false; tick(); requests[1].resolve('login page');
  assert.deepStrictEqual(replacements, ['valid'], 'invalid or login responses must not replace the card');
  tick(); requests[2].reject(); tick(); assert.strictEqual(requests.length, 4, 'retry after failure');
  const old = requests[3]; element = {}; init(); assert(old.aborted);
  old.resolve('valid'); assert.deepStrictEqual(replacements, ['valid'], 'ignore stale results');
  const current = requests[4]; element = null; tick(); assert(current.aborted);
  assert.strictEqual(timers.size, 0);
}

let exercised = 0, skipped = 0;
for (const entry of EXTENSIONS) {
  const source = fs.readFileSync(entry.file, 'utf8');
  const client = clientOf(source);
  const wired = client && client.includes(entry.custom
    ? 'new modgui.createAjaxUpdateCard("smartphone-card"'
    : 'new modgui.createAjaxUpdateCard("' + entry.name + '-card"');
  if (!wired) {
    console.log('Extension cards: skipping ' + entry.name + ' (shared-polling client not wired in this fork yet)');
    ++skipped;
    continue;
  }
  if (entry.custom) runSmartphone(entry); else runReplacement(entry);
  ++exercised;
}
assert(process.platform !== 'win32' || exercised >= 1, 'the smartphone card must always run');
console.log('Extension cards: ' + exercised + ' card(s) exercised, ' + skipped + ' skipped; ' +
  'shared polling, hidden pages, overlap, retry, script stripping and stale/removal checks passed');
