(function () {
  function renderTable(url, keyColumns, renderRow) {
    var sortKey = "";
    var reverseOrder = false;
    makeHeadersSortable();
    var raw = localStorage.getItem(url);
    if (raw) updateTable(raw);
    fetchAndUpdate();
    var updateTimer = setInterval(fetchAndUpdate, 5000);

    function makeHeadersSortable() {
      document.querySelectorAll("#table th[data-sort-key]").forEach(function (cell) {
        cell.addEventListener("click", function (e) {
          // var column = e.target.cellIndex;
          // var newSortColumn = e.target.textContent.toLowerCase();
          var newSortKey = e.target.getAttribute("data-sort-key");
          if (newSortKey === newSortKey) {
            reverseOrder = !reverseOrder;
          } else {
            sortKey = newSortKey;
            reverseOrder = false;
          }
          clearInterval(updateTimer);
          var t = document.getElementById("table").tBodies[0];
          clearRows(t);
          var raw = localStorage.getItem(url);
          updateTable(raw);
        });
      });
    }

    function clearRows(t) {
      while (t.rows.length) t.deleteRow(-1);
    }

    function fetchAndUpdate() {
      var tableError = document.getElementById("table-error");
      var xhr = new XMLHttpRequest();
      xhr.open('GET', url);
      xhr.onload = function () {
        tableError.textContent = "";
        localStorage.setItem(url, this.response);
        updateTable(this.response);
      };
      xhr.onerror = function (e) {
        tableError.textContent = "Error fetching data";
        console.error(e);
      };
      xhr.ontimeout = function (e) {
        tableError.textContent = "Error fetching data";
        console.error(e);
      };
      xhr.timeout = 5000;
      xhr.send();
    }

    function updateTable(raw) {
      var data = JSON.parse(raw);
      data.sort(byColumn);
      document.getElementById("table-count").textContent = data.length;
      var t = document.getElementById("table").tBodies[0];
      for (var i = 0; i < data.length; i++) {
        var item = data[i];
        var foundIndex = findIndex(t.rows, i, item);
        if (foundIndex !== -1) {
          var d = foundIndex - i;
          while (d--) t.deleteRow(i);
          renderRow(t.rows[i], item);
        } else {
          var tr = t.insertRow(i);
          setKeyAttributes(tr, item);
          renderRow(tr, item);
        }
      }

      var rowsToDelete = t.rows.length - data.length;
      while (0 < rowsToDelete--)
        t.deleteRow(t.rows.length - 1);
    }

    function byColumn(a, b) {
      var sortColumns = sortKey === "" ? keyColumns : [sortKey].concat(keyColumns);
      for (var i = 0; i < sortColumns.length; i++) {
        if (a[sortColumns[i]] > b[sortColumns[i]])
          return 1 * (reverseOrder ? -1 : 1);
        if (a[sortColumns[i]] < b[sortColumns[i]])
          return -1 * (reverseOrder ? -1 : 1);
      }
      return 0;
    }

    function findIndex(rows, start, item) {
      for (var i = start; i < rows.length; i++) {
        for (var k = 0; k < keyColumns.length; k++) {
          if (rows[i].getAttribute("data-" + keyColumns[k]) !== item[keyColumns[k]]) {
            break;
          } else if (k === keyColumns.length - 1) {
            return i;
          }
        }
      }
      return -1;
    }

    function setKeyAttributes(tr, item) {
      keyColumns.forEach(function (key) {
        tr.setAttribute("data-" + key, item[key]);
      });
    }
  }

  function renderCell(tr, column, value) {
    var cell = tr.cells[column] || tr.insertCell(-1);
    var text = value.toString();
    if (cell.textContent !== text) {
      cell.textContent = text;
    }
  }

  window.avalanchemq = window.avalanchemq || {};
  Object.assign(window.avalanchemq, {
    table: {
      renderCell: renderCell,
      renderTable: renderTable
    }
  });
})();