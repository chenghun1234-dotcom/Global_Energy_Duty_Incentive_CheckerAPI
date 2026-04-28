export function renderHomePage() {
  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Global Energy Duty & Incentive Checker</title>
  <style>
    :root {
      --bg: #f6f7fb;
      --panel: #ffffff;
      --ink: #1b1e28;
      --muted: #647089;
      --line: #dde3ef;
      --brand: #0a7cff;
      --brand-ink: #ffffff;
      --ok: #1b9e62;
      --err: #d64646;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Segoe UI", "Noto Sans KR", sans-serif;
      color: var(--ink);
      background: radial-gradient(1200px 600px at -10% -20%, #dfeeff 0%, transparent 60%), var(--bg);
    }
    .wrap {
      max-width: 1100px;
      margin: 0 auto;
      padding: 20px;
    }
    .top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 14px;
    }
    h1 {
      margin: 0;
      font-size: 24px;
      font-weight: 700;
    }
    .small { color: var(--muted); font-size: 13px; }
    .apikey {
      display: flex;
      gap: 8px;
      align-items: center;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 8px;
    }
    .apikey input {
      border: 0;
      outline: 0;
      min-width: 260px;
      font-size: 14px;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 14px;
    }
    .card {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
    }
    h2 {
      margin: 0 0 10px;
      font-size: 18px;
    }
    label {
      display: block;
      margin: 10px 0 4px;
      font-size: 13px;
      color: var(--muted);
    }
    input, select {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 9px 10px;
      font-size: 14px;
      background: #fff;
    }
    .row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
    }
    button {
      margin-top: 12px;
      border: 0;
      border-radius: 8px;
      padding: 10px 12px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      background: var(--brand);
      color: var(--brand-ink);
    }
    pre {
      margin: 0;
      max-height: 360px;
      overflow: auto;
      background: #0f1420;
      color: #d8e5ff;
      border-radius: 8px;
      padding: 12px;
      font-size: 12px;
      line-height: 1.45;
    }
    .status { margin-top: 8px; font-size: 13px; }
    .ok { color: var(--ok); }
    .err { color: var(--err); }
    @media (max-width: 900px) {
      .grid { grid-template-columns: 1fr; }
      .top { flex-direction: column; align-items: stretch; }
      .apikey input { min-width: 100%; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="top">
      <div>
        <h1>Global Energy Duty & Incentive Checker API</h1>
        <div class="small">국가 간 에너지 자산 거래 관세/인센티브 조회</div>
      </div>
      <div class="apikey">
        <span class="small">x-api-key</span>
        <input id="apiKey" type="text" value="demo-free-key-001" />
      </div>
    </div>

    <div class="grid">
      <section class="card">
        <h2>/tax-lookup</h2>
        <div class="row">
          <div><label>Origin</label><input id="tOrigin" value="KR" /></div>
          <div><label>Destination</label><input id="tDest" value="JP" /></div>
        </div>
        <div class="row">
          <div><label>Trade Type</label><select id="tType"><option>export</option><option>import</option></select></div>
          <div><label>Asset Type</label><select id="tAsset"><option>diesel</option><option>lng</option><option>crude_oil</option><option>coal</option><option>battery_material</option></select></div>
        </div>
        <div class="row">
          <div><label>HS Code</label><input id="tHs" value="271019" /></div>
          <div><label>Trade Date</label><input id="tDate" type="date" value="2026-04-29" /></div>
        </div>
        <label>Declared Value (USD)</label>
        <input id="tValue" type="number" value="100000" />
        <button id="taxBtn">조회 실행</button>
        <div id="taxStatus" class="status"></div>
      </section>

      <section class="card">
        <h2>/incentive-zones</h2>
        <div class="row">
          <div><label>Country</label><input id="iCountry" value="AE" /></div>
          <div><label>Asset Type</label><input id="iAsset" value="energy" /></div>
        </div>
        <label>As of</label>
        <input id="iDate" type="date" value="2026-04-29" />
        <button id="incBtn">조회 실행</button>
        <div id="incStatus" class="status"></div>
      </section>

      <section class="card" style="grid-column: 1 / -1;">
        <h2>Response</h2>
        <pre id="out">{ "message": "Ready" }</pre>
      </section>
    </div>
  </div>

  <script>
    const out = document.getElementById("out");
    const apiKeyEl = document.getElementById("apiKey");
    const taxStatus = document.getElementById("taxStatus");
    const incStatus = document.getElementById("incStatus");

    function setStatus(el, ok, text) {
      el.className = "status " + (ok ? "ok" : "err");
      el.textContent = text;
    }

    async function callApi(method, path, body) {
      const res = await fetch(path, {
        method,
        headers: {
          "content-type": "application/json",
          "x-api-key": apiKeyEl.value.trim()
        },
        body: body ? JSON.stringify(body) : undefined
      });
      let data;
      try { data = await res.json(); } catch { data = { raw: await res.text() }; }
      out.textContent = JSON.stringify(data, null, 2);
      return { ok: res.ok, status: res.status, data };
    }

    document.getElementById("taxBtn").addEventListener("click", async () => {
      taxStatus.textContent = "";
      const payload = {
        origin_country: document.getElementById("tOrigin").value.trim().toUpperCase(),
        destination_country: document.getElementById("tDest").value.trim().toUpperCase(),
        trade_type: document.getElementById("tType").value,
        asset_type: document.getElementById("tAsset").value,
        hs_code: document.getElementById("tHs").value.trim(),
        trade_date: document.getElementById("tDate").value,
        declared_value_usd: Number(document.getElementById("tValue").value || 0)
      };
      try {
        const r = await callApi("POST", "/tax-lookup", payload);
        setStatus(taxStatus, r.ok, r.ok ? "조회 성공" : "조회 실패 (" + r.status + ")");
      } catch (e) {
        setStatus(taxStatus, false, "요청 오류");
      }
    });

    document.getElementById("incBtn").addEventListener("click", async () => {
      incStatus.textContent = "";
      const c = document.getElementById("iCountry").value.trim().toUpperCase();
      const a = document.getElementById("iAsset").value.trim();
      const d = document.getElementById("iDate").value;
      const q = new URLSearchParams({ country: c, asset_type: a, as_of: d });
      try {
        const r = await callApi("GET", "/incentive-zones?" + q.toString());
        setStatus(incStatus, r.ok, r.ok ? "조회 성공" : "조회 실패 (" + r.status + ")");
      } catch (e) {
        setStatus(incStatus, false, "요청 오류");
      }
    });
  </script>
</body>
</html>`;
}

