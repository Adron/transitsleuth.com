// Vanilla port of the Editor theme's toggle-bar behaviour (menu tab / sidebar tab).
document.addEventListener("DOMContentLoaded", function () {
  var tabs = document.querySelectorAll("ul.toggle-bar a[data-tab]");
  var nav = document.querySelector(".main-navigation");
  var mq = window.matchMedia("(max-width: 840px)");

  function syncNav() { if (nav) nav.style.display = mq.matches ? "none" : ""; }
  syncNav();
  mq.addEventListener("change", syncNav);

  tabs.forEach(function (link) {
    link.addEventListener("click", function (e) {
      e.preventDefault();
      var wasCurrent = link.classList.contains("current");
      tabs.forEach(function (t) {
        t.classList.remove("current");
        t.setAttribute("aria-selected", "false");
        t.parentElement.classList.remove("current");
      });
      document.querySelectorAll(".tab-content").forEach(function (p) {
        p.classList.remove("current");
        p.setAttribute("aria-hidden", "true");
      });
      link.classList.add("current");
      link.setAttribute("aria-selected", "true");
      link.parentElement.classList.add("current");
      var panel = document.getElementById(link.dataset.tab);
      panel.classList.add("current");
      panel.setAttribute("aria-hidden", "false");

      var sidebarOpen = link.classList.contains("folder-toggle");
      document.querySelectorAll(".toggle-bar .fa-folder").forEach(function (i) { i.style.display = sidebarOpen ? "none" : ""; });
      document.querySelectorAll(".toggle-bar .fa-folder-open").forEach(function (i) { i.style.display = sidebarOpen ? "inline-block" : "none"; });

      // On narrow screens the menu tab toggles the nav open/closed, like the original.
      if (nav && mq.matches) {
        var open = link.classList.contains("nav-toggle") && !(wasCurrent && nav.style.display !== "none");
        nav.style.display = open ? "" : "none";
      }
    });
  });
});
