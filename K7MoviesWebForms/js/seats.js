// Seat selection for the seat map. Works for new bookings and for adding seats to a booking.
(function () {
  var map = document.getElementById('seatmap');
  if (!map) return;

  var seatIds = document.getElementById('seatIds');
  var selLabel = document.getElementById('sel');
  var countLabel = document.getElementById('count');
  var totalLabel = document.getElementById('total');
  var btn = document.getElementById('paybtn');
  var MAX = 10;
  var existing = parseInt(map.getAttribute('data-existing') || '0', 10);
  var closed = map.getAttribute('data-closed') === 'true';
  var selected = [];

  // seats already marked selected by the server (after a postback) are kept
  map.querySelectorAll('.seat.sel').forEach(function (el) {
    selected.push({ id: el.getAttribute('data-id'), label: el.getAttribute('data-label'), price: parseFloat(el.getAttribute('data-price')) || 0 });
  });

  function refresh() {
    seatIds.value = selected.map(function (s) { return s.id; }).join(',');
    selLabel.textContent = selected.length ? selected.map(function (s) { return s.label; }).join(', ') : 'None selected';
    countLabel.textContent = selected.length;
    totalLabel.textContent = selected.reduce(function (sum, s) { return sum + s.price; }, 0).toFixed(0);
    if (!closed) btn.disabled = selected.length === 0;
  }

  map.addEventListener('click', function (e) {
    if (closed) return;
    var el = e.target.closest('.seat');
    if (!el || el.disabled || el.classList.contains('booked') || el.classList.contains('owned')) return;
    var id = el.getAttribute('data-id');
    var idx = selected.findIndex(function (s) { return s.id === id; });
    if (idx >= 0) {
      selected.splice(idx, 1);
      el.classList.remove('sel');
    } else {
      if (selected.length + existing >= MAX) {
        alert('A booking can have at most ' + MAX + ' seats.');
        return;
      }
      selected.push({ id: id, label: el.getAttribute('data-label'), price: parseFloat(el.getAttribute('data-price')) || 0 });
      el.classList.add('sel');
    }
    refresh();
  });

  if (closed) btn.disabled = true;
  refresh();
})();
