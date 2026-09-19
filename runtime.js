/* ------------------------------------------------------------------
   Minimal stand-in for the Design canvas runtime.
   Supports exactly what this prototype uses: {{dotted.holes}},
   <sc-if>, <sc-for>, <dc-import name="Logo">, onClick / onContextMenu,
   and a re-render on setState.
------------------------------------------------------------------ */
(function () {
  var TPL = document.getElementById('tpl').content;
  var ROOT = document.getElementById('stage');

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

  function renderChildren(src, scope, out) {
    for (var n = src.firstChild; n; n = n.nextSibling) renderNode(n, scope, out);
  }

  function renderNode(node, scope, out) {
    if (node.nodeType === 3) {
      var t = node.nodeValue;
      out.appendChild(document.createTextNode(t.indexOf('{{') < 0 ? t : interp(t, scope)));
      return;
    }
    if (node.nodeType !== 1) return;
    var tag = node.tagName.toLowerCase();

    if (tag === 'sc-if') {
      var m = (node.getAttribute('value') || '').match(WHOLE);
      if (m && get(scope, m[1])) renderChildren(node, scope, out);
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
          renderChildren(node, s2, out);
        }
      }
      return;
    }
    if (tag === 'dc-import') {
      if (node.getAttribute('name') === 'Logo') {
        var a = node.getAttribute('app') || '', s = node.getAttribute('size') || '24';
        var am = a.match(WHOLE); if (am) a = get(scope, am[1]);
        var holder = document.createElement('span');
        holder.innerHTML = window.SIGNAL_LOGO(a, parseFloat(s));
        while (holder.firstChild) out.appendChild(holder.firstChild);
      }
      return;
    }

    // clone shallowly so SVG elements keep their namespace
    var el = node.cloneNode(false);
    var attrs = Array.prototype.slice.call(el.attributes);
    for (var k = 0; k < attrs.length; k++) {
      var name = attrs[k].name, val = attrs[k].value;
      if (/^on[a-z]/.test(name)) {
        el.removeAttribute(name);
        var hm = val.match(WHOLE);
        if (hm) {
          var fn = get(scope, hm[1]);
          if (typeof fn === 'function') el.addEventListener(name.slice(2), fn);
        }
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
    renderChildren(node, scope, el);
    out.appendChild(el);
  }

  /* ---- component host ---------------------------------------- */
  window.DCLogic = function (props) { this.props = props || {}; };
  window.DCLogic.prototype.setState = function (o) {
    Object.assign(this.state, o);
    this.forceUpdate();
  };
  window.DCLogic.prototype.forceUpdate = function () { mount(); };

  var instance = null, first = true;
  function mount() {
    var vals = instance.renderVals();
    var frag = document.createDocumentFragment();
    renderChildren(TPL, vals, frag);

    // Carry live nodes across renders so their CSS animations keep running
    // instead of restarting on every click.
    if (!first) {
      var olds = {};
      ROOT.querySelectorAll('[data-keep]').forEach(function (n) { olds[n.getAttribute('data-keep')] = n; });
      frag.querySelectorAll('[data-keep]').forEach(function (fresh) {
        var old = olds[fresh.getAttribute('data-keep')];
        if (!old) return;
        if (old.getAttribute('class') !== fresh.getAttribute('class')) {
          old.setAttribute('class', fresh.getAttribute('class'));
        }
        fresh.parentNode.replaceChild(old, fresh);
      });
    }
    ROOT.textContent = '';
    ROOT.appendChild(frag);
    first = false;
  }

  window.SIGNAL_START = function (Component) {
    instance = new Component({ demoSpeed: 1 });
    instance.forceUpdate = mount;
    mount();
  };

  /* ---- fit the 1440x900 desktop to the viewport ---------------
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
    // below this width the desktop mock is too small to read; offer a way out
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
