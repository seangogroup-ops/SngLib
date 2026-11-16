/* SngLib · ghi lượt truy cập + hiển thị thông báo / liên kết từ Supabase.
   Không có cấu hình thì file này không làm gì cả. */
(function () {
  "use strict";
  var C = window.SNGLIB || {};
  if (!C.SUPABASE_URL || !C.SUPABASE_ANON_KEY) return;

  var API = C.SUPABASE_URL.replace(/\/$/, "") + "/rest/v1/";
  var H = { apikey: C.SUPABASE_ANON_KEY, "Content-Type": "application/json" };
  if (/^eyJ/.test(C.SUPABASE_ANON_KEY)) H.Authorization = "Bearer " + C.SUPABASE_ANON_KEY;

  var ls = {
    get: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  };
  var uid = function () {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    return "v" + Date.now().toString(36) + Math.random().toString(36).slice(2, 12);
  };

  /* ---------- Thống kê ---------- */
  var skip =
    location.protocol === "file:" ||
    /^(localhost|127\.|0\.0\.0\.0)/.test(location.hostname) ||
    navigator.doNotTrack === "1" ||
    ls.get("sl_ignore") === "1" ||                       /* admin đã đăng nhập thì không tính */
    /bot|crawl|spider|headless|lighthouse/i.test(navigator.userAgent);

  var vid = ls.get("sl_vid");
  if (!vid) { vid = uid(); ls.set("sl_vid", vid); }
  var sid;
  try { sid = sessionStorage.getItem("sl_sid"); if (!sid) { sid = uid(); sessionStorage.setItem("sl_sid", sid); } } catch (e) { sid = uid(); }

  function ua() {
    var s = navigator.userAgent, b = "Khác", o = "Khác";
    if (/Edg\//.test(s)) b = "Edge";
    else if (/OPR\/|Opera/.test(s)) b = "Opera";
    else if (/SamsungBrowser/.test(s)) b = "Samsung";
    else if (/CriOS|Chrome\//.test(s)) b = "Chrome";
    else if (/FxiOS|Firefox\//.test(s)) b = "Firefox";
    else if (/Safari\//.test(s)) b = "Safari";
    if (/Windows/.test(s)) o = "Windows";
    else if (/Android/.test(s)) o = "Android";
    else if (/iPhone|iPad|iPod/.test(s)) o = "iOS";
    else if (/Mac OS X/.test(s)) o = "macOS";
    else if (/Linux/.test(s)) o = "Linux";
    var d = /iPad|Tablet/.test(s) ? "Máy tính bảng" : /Mobi|iPhone|Android/.test(s) ? "Điện thoại" : "Máy tính";
    return { b: b, o: o, d: d };
  }
  function refHost() {
    try {
      if (!document.referrer) return "";
      var h = new URL(document.referrer).hostname.replace(/^www\./, "");
      return h === location.hostname ? "" : h.slice(0, 120);
    } catch (e) { return ""; }
  }
  function track(kind, q) {
    if (skip) return;
    var u = ua(), tz = "";
    try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || ""; } catch (e) {}
    var row = {
      kind: kind, visitor_id: vid, session_id: sid,
      path: (location.pathname || "/").slice(0, 200),
      referrer: kind === "view" ? refHost() : null,
      device: u.d, browser: u.b, os: u.o,
      lang: (navigator.language || "").slice(0, 20), tz: tz.slice(0, 60),
      screen: screen.width + "x" + screen.height,
      q: q ? String(q).slice(0, 200) : null
    };
    try {
      fetch(API + "visits", {
        method: "POST", keepalive: true,
        headers: Object.assign({ Prefer: "return=minimal" }, H),
        body: JSON.stringify(row)
      }).catch(function () {});
    } catch (e) {}
  }

  track("view");
  setInterval(function () { if (!document.hidden) track("ping"); }, 60000);

  var form = document.getElementById("f");
  if (form) form.addEventListener("submit", function () {
    var q = (document.getElementById("q") || {}).value;
    if (q && q.trim()) track("search", q.trim());
  });

  /* ---------- Thông báo + liên kết ---------- */
  function get(path) {
    return fetch(API + path, { headers: H }).then(function (r) { return r.ok ? r.json() : []; }).catch(function () { return []; });
  }
  function safeUrl(u) {
    if (!u) return "";
    u = String(u).trim();
    return /^(https?:\/\/|mailto:|\/|\.\/|#)/i.test(u) ? u : "";
  }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  var css = document.createElement("style");
  css.textContent =
    "#bulletin{display:grid;gap:.6rem;margin:0 0 1rem}" +
    ".bn{position:relative;display:flex;gap:.8rem;align-items:flex-start;background:var(--panel);border:2px solid var(--line);border-left:6px solid var(--lime);border-radius:16px;padding:.85rem 3rem .85rem 1.1rem;box-shadow:var(--sh)}" +
    ".bn.warn{border-left-color:#f97316}.bn.success{border-left-color:#16a34a}" +
    ".bn b{display:block;font-size:1.02rem;line-height:1.35}" +
    ".bn p{margin:.15rem 0 0;color:var(--mut);font-size:.96rem;line-height:1.5;white-space:pre-line}" +
    ".bn a{display:inline-block;margin-top:.4rem;font-weight:700;color:var(--ring)}" +
    ".bn button{position:absolute;top:.5rem;right:.55rem;width:2rem;height:2rem;border:0;border-radius:10px;background:transparent;color:var(--mut);font-size:1.3rem;line-height:1;cursor:pointer}" +
    ".bn button:hover{background:var(--soft);color:var(--ink)}" +
    "#sitelinks{margin-top:2.4rem;padding-top:1.1rem;border-top:2px solid var(--line);display:flex;flex-wrap:wrap;gap:.5rem .6rem;align-items:center}" +
    "#sitelinks span{font-weight:700;color:var(--mut);margin-right:.3rem}" +
    "#sitelinks a{text-decoration:none;font-weight:600;font-size:.95rem;padding:.4rem .9rem;border-radius:99px;background:var(--panel);border:2px solid var(--line)}" +
    "#sitelinks a:hover{border-color:var(--ring)}";
  document.head.appendChild(css);

  var col = document.querySelector(".col");
  if (!col) return;

  get("announcements?select=id,title,body,link_url,link_label,level&order=created_at.desc&limit=5").then(function (rows) {
    if (!rows.length) return;
    var gone = [];
    try { gone = JSON.parse(ls.get("sl_dismissed") || "[]"); } catch (e) {}
    rows = rows.filter(function (r) { return gone.indexOf(r.id) < 0; });
    if (!rows.length) return;
    var box = el("div"); box.id = "bulletin";
    rows.forEach(function (r) {
      var n = el("div", "bn " + (r.level === "warn" || r.level === "success" ? r.level : "info"));
      var t = el("div");
      t.appendChild(el("b", "", r.title));
      if (r.body) t.appendChild(el("p", "", r.body));
      var href = safeUrl(r.link_url);
      if (href) {
        var a = el("a", "", (r.link_label || "Xem thêm") + " →");
        a.href = href;
        if (/^https?:/i.test(href)) { a.target = "_blank"; a.rel = "noopener noreferrer"; }
        t.appendChild(a);
      }
      var x = el("button", "", "×");
      x.type = "button"; x.setAttribute("aria-label", "Đóng thông báo");
      x.onclick = function () {
        n.remove(); gone.push(r.id); ls.set("sl_dismissed", JSON.stringify(gone.slice(-50)));
        if (!box.children.length) box.remove();
      };
      n.appendChild(t); n.appendChild(x); box.appendChild(n);
    });
    col.insertBefore(box, col.firstChild);
  });

  get("links?select=title,url&order=sort.asc,id.asc&limit=20").then(function (rows) {
    rows = rows.filter(function (r) { return safeUrl(r.url); });
    if (!rows.length) return;
    var f = el("nav"); f.id = "sitelinks"; f.setAttribute("aria-label", "Liên kết");
    f.appendChild(el("span", "", "Liên kết"));
    rows.forEach(function (r) {
      var a = el("a", "", r.title);
      a.href = safeUrl(r.url);
      if (/^https?:/i.test(a.href)) { a.target = "_blank"; a.rel = "noopener noreferrer"; }
      f.appendChild(a);
    });
    col.appendChild(f);
  });
})();
