// Review links: remembered initials, search, and keyboard review.
(function () {
  var an = document.getElementById('analyst');
  if (an) {
    an.value = localStorage.getItem('sirens-analyst') || an.value || '';
    an.addEventListener('change', function () { localStorage.setItem('sirens-analyst', an.value); });
  }
  var flash = document.getElementById('flash'), list = document.getElementById('links');
  var find = document.getElementById('find'), nofind = document.getElementById('nofind');
  var cards = function () { return [].slice.call(list.querySelectorAll('.link:not([hidden])')); };
  var cur = null;

  function focusCard(card, open) {
    if (!card) return;
    if (cur) cur.classList.remove('cur');
    cur = card; card.classList.add('cur');
    if (open) card.querySelector('.cmp').open = true;
    card.scrollIntoView({block: 'nearest'});
  }
  function move(step) {
    var all = cards(), i = all.indexOf(cur);
    focusCard(all[Math.max(0, Math.min(all.length - 1, i + step))] || all[0]);
  }
  list.addEventListener('click', function (e) {
    var c = e.target.closest('.link'); if (c && c !== cur) focusCard(c);
  });

  // Search by incident ID or place.
  find.addEventListener('input', function () {
    var words = find.value.toLowerCase().split(/\s+/).filter(Boolean), shown = 0;
    [].forEach.call(list.querySelectorAll('.link'), function (c) {
      var ok = words.every(function (w) { return c.getAttribute('data-search').indexOf(w) >= 0; });
      c.hidden = !ok; if (ok) shown++;
    });
    nofind.hidden = shown > 0 || !list.children.length;
  });

  // Keyboard: J/K move, C/R/U decide, Z undo, Enter compare, N note.
  document.addEventListener('keydown', function (e) {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    var t = e.target, typing = t.matches && t.matches('input, textarea, select');
    if (typing) { if (e.key === 'Escape') t.blur(); return; }
    var k = e.key.toLowerCase();
    if (k === 'j' || e.key === 'ArrowDown') { e.preventDefault(); move(1); return; }
    if (k === 'k' || e.key === 'ArrowUp') { e.preventDefault(); move(-1); return; }
    if (!cur) { if ('cruzn'.indexOf(k) >= 0 || e.key === 'Enter') focusCard(cards()[0]); return; }
    if (e.key === 'Enter') { e.preventDefault(); var d = cur.querySelector('.cmp'); d.open = !d.open; return; }
    if (k === 'n') { e.preventDefault(); cur.querySelector('input[name="note"]').focus(); return; }
    var btn = cur.querySelector('.dbtn[data-key="' + k.toUpperCase() + '"]');
    if (btn) { e.preventDefault(); btn.click(); }
  });

  // After a decision or note the card is replaced by a fresh one (htmx:load
  // fires on the new card): keep the place, then step to the next open link.
  var lastPath = '', lastId = '';
  document.body.addEventListener('htmx:beforeRequest', function (e) {
    lastPath = (e.detail.requestConfig && e.detail.requestConfig.path) || '';
    var c = e.target.closest && e.target.closest('.link'); lastId = c ? c.id : '';
  });
  document.body.addEventListener('htmx:load', function (e) {
    var fresh = e.detail.elt;
    if (!fresh || !fresh.classList || !fresh.classList.contains('link') || fresh.id !== lastId) return;
    flash.style.display = 'none';
    if (cur && document.body.contains(cur) && cur.id !== fresh.id) return;   // user moved on meanwhile
    cur = null; focusCard(fresh);
    var decided = /is-(confirm|reject|unsure)/.test(fresh.className);
    if (decided && lastPath.indexOf('/review/decide') >= 0) {
      var all = cards(), next = all.slice(all.indexOf(fresh) + 1).filter(function (c) {
        return !/is-(confirm|reject|unsure)/.test(c.className); })[0];
      if (next) setTimeout(function () { if (cur === fresh) focusCard(next); }, 350);
    }
  });
  // Show server-side refusals (e.g. an empty note) instead of failing silently.
  document.body.addEventListener('htmx:responseError', function (e) {
    flash.textContent = 'Not saved: ' + (e.detail.xhr.responseText || e.detail.xhr.status);
    flash.style.display = 'block';
  });
})();
