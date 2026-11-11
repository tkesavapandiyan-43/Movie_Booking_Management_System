// Small interactions: Now showing / Coming soon tabs and showtime date tabs.
(function () {
  document.querySelectorAll('.seg-btn[data-tab]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      document.querySelectorAll('.seg-btn[data-tab]').forEach(function (b) {
        var on = b === btn;
        b.classList.toggle('active', on);
        b.setAttribute('aria-selected', on ? 'true' : 'false');
      });
      document.querySelectorAll('.tabpanel').forEach(function (p) {
        p.hidden = p.id !== 'tab-' + btn.dataset.tab;
      });
    });
  });

  var dateTabs = document.querySelectorAll('.date-tab[data-date]');
  dateTabs.forEach(function (tab) {
    tab.addEventListener('click', function () {
      dateTabs.forEach(function (t) { t.classList.toggle('active', t === tab); });
      document.querySelectorAll('.show-row').forEach(function (row) {
        row.hidden = row.dataset.date !== tab.dataset.date;
      });
    });
  });
})();
