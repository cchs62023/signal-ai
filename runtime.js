/* ------------------------------------------------------------------
   Minimal stand-in for the Design canvas runtime.
   Supports exactly what this prototype uses: {{dotted.holes}},
   <sc-if>, <sc-for>, <dc-import name="Logo">, onClick / onContextMenu,
   and an in-place update on setState.

   Every emitted node carries a slot key derived from its position in the
   TEMPLATE, not in the output. Conditionals and whitespace therefore do
   not shift identities, so the diff reuses the same DOM nodes across
   renders: no empty frame, no re-decoded wallpaper, no restarted CSS
   animations, no lost scroll positions.
------------------------------------------------------------------ */
(function () {
  var TPL = null, ROOT = null;
  function els() {                    // resolved lazily; script order is then irrelevant
    if (!TPL) TPL = document.getElementById('tpl').content;
    if (!ROOT) ROOT = document.getElementById('stage');
  }

  function get(scope, path) {
    if (path === 'true') return true;
    if (path === 'false') return false;
    var parts = path.split('.'), cur = scope[parts[0]];
    for (var i = 1; i < parts.length && cur != null; i++) cur = cur[parts[i]];
    return cur;
  }
  var WHOLE = /^\{\{\s*([\w.$]+)\s*\}\}$/;
  function interp(str, scope) {
    return str.replace(/\{\{\s*([\w.$]+)\s*\}\}/g, function (_, p) {
      var v = get(scope, p); return v == null ? '' : String(v);
    });
  }

  /* ---- render ------------------------------------------------- */
  function renderChildren(src, scope, out, path) {
    var i = 0;
    for (var n = src.firstChild; n; n = n.nextSibling, i++) {
      renderNode(n, scope, out, path + '.' + i);
    }
  }

  function renderNode(node, scope, out, key) {
    if (node.nodeType === 3) {
      var t = node.nodeValue;
      var tn = document.createTextNode(t.indexOf('{{') < 0 ? t : interp(t, scope));
      tn.__slot = key;
      out.appendChild(tn);
      return;
    }
    if (node.nodeType !== 1) return;
    var tag = node.tagName.toLowerCase();

    if (tag === 'sc-if') {
      var m = (node.getAttribute('value') || '').match(WHOLE);
      if (m && get(scope, m[1])) renderChildren(node, scope, out, key);
      return;
    }
    if (tag === 'sc-for') {
      var lm = (node.getAttribute('list') || '').match(WHOLE);
      var as = node.getAttribute('as');
      var arr = lm ? get(scope, lm[1]) : null;
      if (Array.isArray(arr)) {
        for (var i = 0; i < arr.length; i++) {
          var s2 = Object.create(scope);
          s2[as] = arr[i]; s2.$index = i;
          renderChildren(node, s2, out, key + '#' + i);
        }
      }
      return;
    }
    if (tag === 'dc-import') {
      if (node.getAttribute('name') === 'Logo') {
        var a = node.getAttribute('app') || '', sz = node.getAttribute('size') || '24';
        var am = a.match(WHOLE); if (am) a = get(scope, am[1]);
        var holder = document.createElement('span');
        holder.innerHTML = window.SIGNAL_LOGO(a, parseFloat(sz));
        var c = 0;
        while (holder.firstChild) {
          var child = holder.firstChild;
          child.__slot = key + '/' + (c++);
          out.appendChild(child);
        }
      }
      return;
    }

    var el = node.cloneNode(false);          // shallow clone keeps the SVG namespace
    var attrs = Array.prototype.slice.call(el.attributes);
    for (var k = 0; k < attrs.length; k++) {
      var name = attrs[k].name, val = attrs[k].value;
      if (/^on[a-z]/.test(name)) {
        el.removeAttribute(name);            // never let the browser eval "{{ x }}"
        var hm = val.match(WHOLE);
        var fn = hm ? get(scope, hm[1]) : null;
        el[name] = (typeof fn === 'function') ? fn : null;
        continue;
      }
      var wm = val.match(WHOLE);
      if (wm) {
        var v = get(scope, wm[1]);
        if (typeof v === 'boolean') { if (v) el.setAttribute(name, ''); else el.removeAttribute(name); }
        else el.setAttribute(name, v == null ? '' : String(v));
      } else if (val.indexOf('{{') >= 0) {
        el.setAttribute(name, interp(val, scope));
      }
    }
    el.__slot = key;
    renderChildren(node, scope, el, key);
    out.appendChild(el);
  }

  /* ---- diff --------------------------------------------------- */
  var HANDLER_PROPS = ['onclick', 'oncontextmenu'];

  function patchEl(oldEl, newEl) {
    var oa = oldEl.attributes, i, tabSwitched = false;
    for (i = oa.length - 1; i >= 0; i--) {
      if (!newEl.hasAttribute(oa[i].name)) oldEl.removeAttribute(oa[i].name);
    }
    var na = newEl.attributes;
    for (i = 0; i < na.length; i++) {
      if (oldEl.getAttribute(na[i].name) !== na[i].value) {
        if (na[i].name === 'data-tabkey') tabSwitched = true;
        oldEl.setAttribute(na[i].name, na[i].value);
      }
    }
    for (i = 0; i < HANDLER_PROPS.length; i++) {
      oldEl[HANDLER_PROPS[i]] = newEl[HANDLER_PROPS[i]] || null;
    }
    patchChildren(oldEl, newEl);
    if (tabSwitched) oldEl.scrollTop = 0;     // a freshly opened tab starts at the top
  }

  function reusable(oldN, newN) {
    return oldN && oldN.nodeType === newN.nodeType &&
           (newN.nodeType !== 1 || oldN.nodeName === newN.nodeName);
  }

  function patchChildren(oldParent, newParent) {
    var bySlot = Object.create(null), o, next;
    for (o = oldParent.firstChild; o; o = o.nextSibling) {
      if (o.__slot !== undefined) bySlot[o.__slot] = o;
    }
    var incoming = [];
    for (var n = newParent.firstChild; n; n = next) { next = n.nextSibling; incoming.push(n); }

    var targets = [], i;
    for (i = 0; i < incoming.length; i++) {
      var nn = incoming[i], m = bySlot[nn.__slot], target;
      if (reusable(m, nn)) {
        if (nn.nodeType === 1) patchEl(m, nn);
        else if (m.nodeValue !== nn.nodeValue) m.nodeValue = nn.nodeValue;
        target = m;
      } else {
        target = nn;
      }
      delete bySlot[nn.__slot];
      targets.push(target);
    }

    // put them in order, moving only what actually moved
    var ref = oldParent.firstChild;
    for (i = 0; i < targets.length; i++) {
      if (targets[i] === ref) { ref = ref.nextSibling; continue; }
      oldParent.insertBefore(targets[i], ref);
    }
    while (ref) { next = ref.nextSibling; oldParent.removeChild(ref); ref = next; }
  }

  /* ---- component host ----------------------------------------- */
  window.DCLogic = function (props) { this.props = props || {}; };
  window.DCLogic.prototype.setState = function (o) {
    Object.assign(this.state, o);
    this.forceUpdate();
  };
  window.DCLogic.prototype.forceUpdate = function () { mount(); };

  var instance = null, mounted = false;
  function mount() {
    els();
    var frag = document.createDocumentFragment();
    renderChildren(TPL, instance.renderVals(), frag, 'r');
    if (!mounted) { ROOT.appendChild(frag); mounted = true; return; }
    patchChildren(ROOT, frag);
  }

  window.SIGNAL_START = function (Component) {
    instance = new Component({ demoSpeed: 1 });
    instance.forceUpdate = mount;
    mount();
  };

  /* ---- fit the 1440x900 desktop to the viewport ----------------
     #fit keeps its true 1440x900 layout size and is scaled about its
     top-left corner; the centring offset is computed, not left to a
     percentage translate (which resolves against the element's own box
     and fought with the scale).                                      */
  function fit() {
    var vv = window.visualViewport;
    var w = vv ? vv.width : window.innerWidth;
    var h = vv ? vv.height : window.innerHeight;
    var s = Math.min(w / 1440, h / 900);
    var wrap = document.getElementById('fit');
    wrap.style.transform = 'translate(' + ((w - 1440 * s) / 2) + 'px,' +
                           ((h - 900 * s) / 2) + 'px) scale(' + s + ')';
    var small = document.getElementById('small');
    if (small && !window.__signalForce) small.hidden = w >= 720;
  }
  window.addEventListener('resize', fit);
  window.addEventListener('orientationchange', fit);
  if (window.visualViewport) window.visualViewport.addEventListener('resize', fit);
  document.addEventListener('click', function (e) {
    if (e.target && e.target.id === 'anyway') {
      window.__signalForce = true;
      document.getElementById('small').hidden = true;
    }
  });
  window.SIGNAL_FIT = fit;
})();
