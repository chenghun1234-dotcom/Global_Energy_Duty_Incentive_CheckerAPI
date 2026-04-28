import { renderHomePage } from "./ui.js";

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);
      const path = url.pathname;

      if (request.method === "GET" && path === "/") {
        return new Response(renderHomePage(), {
          status: 200,
          headers: { "content-type": "text/html; charset=utf-8" },
        });
      }

      if (request.method === "GET" && path === "/health") {
        return json({ status: "ok", timestamp: new Date().toISOString() }, 200);
      }

      if (request.method === "POST" && path === "/tax-lookup") {
        const auth = await authenticateAndCheckQuota(request, env, "/tax-lookup");
        if (auth.errorResponse) return auth.errorResponse;

        const body = await safeJson(request);
        const errors = validateTaxLookup(body);
        if (errors.length > 0) return badRequest(errors.join("; "));

        const declaredValue = Number(body.declared_value_usd ?? 0);
        const tradeDate = body.trade_date;
        const hsCode = body.hs_code ? String(body.hs_code) : null;

        let rule = null;
        if (hsCode) {
          rule = await env.DB.prepare(
            `
            SELECT base_tariff_rate, additional_tax_rate, vat_rate, source_url, version
            FROM tariff_rules
            WHERE origin_country = ?
              AND destination_country = ?
              AND trade_type = ?
              AND hs_code = ?
              AND (? >= effective_from)
              AND (effective_to IS NULL OR ? <= effective_to)
            ORDER BY effective_from DESC
            LIMIT 1
            `
          )
            .bind(
              body.origin_country,
              body.destination_country,
              body.trade_type,
              hsCode,
              tradeDate,
              tradeDate
            )
            .first();
        }

        if (!rule) {
          rule = await env.DB.prepare(
            `
            SELECT base_tariff_rate, additional_tax_rate, vat_rate, source_url, version
            FROM tariff_rules
            WHERE origin_country = ?
              AND destination_country = ?
              AND trade_type = ?
              AND asset_type = ?
              AND (? >= effective_from)
              AND (effective_to IS NULL OR ? <= effective_to)
            ORDER BY effective_from DESC
            LIMIT 1
            `
          )
            .bind(
              body.origin_country,
              body.destination_country,
              body.trade_type,
              body.asset_type,
              tradeDate,
              tradeDate
            )
            .first();
        }

        if (!rule) {
          return json(
            { error: { code: "RULE_NOT_FOUND", message: "No matching tariff rule found" } },
            404
          );
        }

        await incrementUsage(env, auth.apiKeyHash, "/tax-lookup");

        const baseTariff = Number(rule.base_tariff_rate);
        const additionalTax = Number(rule.additional_tax_rate);
        const vat = Number(rule.vat_rate);
        const totalRate = baseTariff + additionalTax + vat;
        const totalTax = round2(declaredValue * totalRate);

        return json(
          {
            request_id: crypto.randomUUID(),
            query: body,
            result: {
              base_tariff_rate: baseTariff,
              additional_tax_rate: additionalTax,
              vat_rate: vat,
              estimated_total_rate: round6(totalRate),
              estimated_total_tax_usd: totalTax,
            },
            meta: {
              rule_version: rule.version,
              last_updated_at: new Date().toISOString(),
              source_refs: [rule.source_url],
            },
          },
          200
        );
      }

      if (request.method === "GET" && path === "/incentive-zones") {
        const auth = await authenticateAndCheckQuota(request, env, "/incentive-zones");
        if (auth.errorResponse) return auth.errorResponse;

        const country = (url.searchParams.get("country") || "").toUpperCase();
        const assetType = url.searchParams.get("asset_type");
        const asOf = url.searchParams.get("as_of") || todayIsoDate();

        const errors = [];
        if (!/^[A-Z]{2}$/.test(country)) errors.push("country must be ISO2 uppercase");
        if (!isIsoDate(asOf)) errors.push("as_of must be YYYY-MM-DD");
        if (errors.length > 0) return badRequest(errors.join("; "));

        const hasAssetFilter = Boolean(assetType);
        const baseSql = `
          SELECT zone_code, zone_name, city, incentives_json, conditions, effective_from, effective_to, source_url, version
          FROM incentive_zones
          WHERE country_code = ?
            AND (? >= effective_from)
            AND (effective_to IS NULL OR ? <= effective_to)
        `;
        const sql = hasAssetFilter ? `${baseSql} AND asset_type = ?` : baseSql;

        const bound = hasAssetFilter
          ? env.DB.prepare(sql).bind(country, asOf, asOf, assetType)
          : env.DB.prepare(sql).bind(country, asOf, asOf);

        const rows = await bound.all();
        const results = (rows.results || []).map((r) => ({
          zone_code: r.zone_code,
          zone_name: r.zone_name,
          city: r.city,
          incentives: parseJsonArray(r.incentives_json),
          conditions: r.conditions,
          effective_from: r.effective_from,
          effective_to: r.effective_to,
          source_url: r.source_url,
        }));

        await incrementUsage(env, auth.apiKeyHash, "/incentive-zones");

        const version = (rows.results || [])[0]?.version || "unknown";

        return json(
          {
            country,
            asset_type: assetType || null,
            as_of: asOf,
            zones: results,
            meta: {
              rule_version: version,
              last_updated_at: new Date().toISOString(),
            },
          },
          200
        );
      }

      return json({ error: { code: "NOT_FOUND", message: "Endpoint not found" } }, 404);
    } catch (e) {
      return json(
        {
          error: { code: "INTERNAL_ERROR", message: e instanceof Error ? e.message : "Unexpected error" },
        },
        500
      );
    }
  },
};

let coreTablesReady = false;

async function authenticateAndCheckQuota(request, env, endpoint) {
  await ensureCoreTables(env);

  const apiKey = request.headers.get("x-api-key");
  if (!apiKey) {
    return {
      errorResponse: json(
        { error: { code: "UNAUTHORIZED", message: "x-api-key header is required" } },
        401
      ),
    };
  }

  const apiKeyHash = await sha256Hex(apiKey);
  const keyRow = await env.DB.prepare(
    `
    SELECT api_key_hash, plan, daily_limit, is_active
    FROM api_keys
    WHERE api_key_hash = ?
    LIMIT 1
    `
  )
    .bind(apiKeyHash)
    .first();

  if (!keyRow || Number(keyRow.is_active) !== 1) {
    return {
      errorResponse: json(
        { error: { code: "UNAUTHORIZED", message: "Invalid or inactive API key" } },
        401
      ),
    };
  }

  const today = todayIsoDate();
  const usageRow = await env.DB.prepare(
    `
    SELECT request_count
    FROM usage_daily
    WHERE usage_date = ? AND api_key_hash = ? AND endpoint = ?
    LIMIT 1
    `
  )
    .bind(today, apiKeyHash, endpoint)
    .first();

  const used = Number(usageRow?.request_count ?? 0);
  const limit = Number(keyRow.daily_limit ?? 1000);
  if (used >= limit) {
    return {
      errorResponse: json(
        {
          error: {
            code: "RATE_LIMIT_EXCEEDED",
            message: `Daily limit exceeded for endpoint ${endpoint}`,
          },
        },
        429
      ),
    };
  }

  return { apiKeyHash, plan: keyRow.plan };
}

async function ensureCoreTables(env) {
  if (coreTablesReady) return;

  await env.DB.batch([
    env.DB.prepare(`
      CREATE TABLE IF NOT EXISTS tariff_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        origin_country TEXT NOT NULL,
        destination_country TEXT NOT NULL,
        trade_type TEXT NOT NULL,
        asset_type TEXT NOT NULL,
        hs_code TEXT,
        base_tariff_rate REAL NOT NULL,
        additional_tax_rate REAL NOT NULL DEFAULT 0,
        vat_rate REAL NOT NULL DEFAULT 0,
        effective_from TEXT NOT NULL,
        effective_to TEXT,
        source_url TEXT NOT NULL,
        version TEXT NOT NULL
      )
    `),
    env.DB.prepare(`
      CREATE TABLE IF NOT EXISTS incentive_zones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        country_code TEXT NOT NULL,
        zone_code TEXT NOT NULL,
        zone_name TEXT NOT NULL,
        city TEXT,
        asset_type TEXT,
        incentives_json TEXT NOT NULL,
        conditions TEXT,
        effective_from TEXT NOT NULL,
        effective_to TEXT,
        source_url TEXT NOT NULL,
        version TEXT NOT NULL
      )
    `),
    env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_tariff_lookup
      ON tariff_rules(origin_country, destination_country, trade_type, asset_type, effective_from, effective_to)
    `),
    env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_tariff_lookup_hs
      ON tariff_rules(origin_country, destination_country, trade_type, hs_code, effective_from, effective_to)
    `),
    env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_zone_lookup
      ON incentive_zones(country_code, asset_type, effective_from, effective_to)
    `),
    env.DB.prepare(`
      CREATE TABLE IF NOT EXISTS api_keys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        api_key_hash TEXT NOT NULL UNIQUE,
        client_name TEXT NOT NULL,
        plan TEXT NOT NULL,
        daily_limit INTEGER NOT NULL DEFAULT 1000,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    `),
    env.DB.prepare(`
      CREATE TABLE IF NOT EXISTS usage_daily (
        usage_date TEXT NOT NULL,
        api_key_hash TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        request_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (usage_date, api_key_hash, endpoint)
      )
    `),
    env.DB.prepare(`
      INSERT OR IGNORE INTO api_keys (api_key_hash, client_name, plan, daily_limit, is_active)
      VALUES ('f28dd4e2d4fb7ae946cff14ede2047cd08974df5533670855fb5e2f54bd4a26f', 'demo-client', 'free', 1000, 1)
    `),
  ]);

  const tariffCountRow = await env.DB.prepare("SELECT COUNT(*) AS cnt FROM tariff_rules").first();
  const zoneCountRow = await env.DB.prepare("SELECT COUNT(*) AS cnt FROM incentive_zones").first();
  const tariffCount = Number(tariffCountRow?.cnt ?? 0);
  const zoneCount = Number(zoneCountRow?.cnt ?? 0);

  if (tariffCount === 0) {
    await env.DB.batch([
      env.DB.prepare(`
        INSERT INTO tariff_rules (
          origin_country, destination_country, trade_type, asset_type, hs_code,
          base_tariff_rate, additional_tax_rate, vat_rate,
          effective_from, effective_to, source_url, version
        ) VALUES
          ('KR', 'JP', 'export', 'diesel', '271019', 0.03, 0.00, 0.10, '2026-01-01', NULL, 'https://www.customs.go.jp/english/tariff/index.htm', 'v2026.04.28'),
          ('KR', 'JP', 'export', 'lng', '271111', 0.02, 0.00, 0.10, '2026-01-01', NULL, 'https://www.customs.go.jp/english/tariff/index.htm', 'v2026.04.28'),
          ('KR', 'JP', 'export', 'crude_oil', '270900', 0.00, 0.00, 0.10, '2026-01-01', NULL, 'https://www.customs.go.jp/english/tariff/index.htm', 'v2026.04.28')
      `),
    ]);
  }

  if (zoneCount === 0) {
    await env.DB.batch([
      env.DB.prepare(`
        INSERT INTO incentive_zones (
          country_code, zone_code, zone_name, city, asset_type, incentives_json,
          conditions, effective_from, effective_to, source_url, version
        ) VALUES
          ('AE', 'AE-DMCC', 'DMCC Free Zone', 'Dubai', 'energy', '["corporate_tax_reduction","import_duty_exemption"]', 'licensed entities only', '2025-01-01', NULL, 'https://example.gov/freezone/dmcc', 'v2026.04.20')
      `),
    ]);
  }

  coreTablesReady = true;
}

async function incrementUsage(env, apiKeyHash, endpoint) {
  const today = todayIsoDate();
  await env.DB.prepare(
    `
    INSERT INTO usage_daily (usage_date, api_key_hash, endpoint, request_count)
    VALUES (?, ?, ?, 1)
    ON CONFLICT(usage_date, api_key_hash, endpoint)
    DO UPDATE SET request_count = request_count + 1
    `
  )
    .bind(today, apiKeyHash, endpoint)
    .run();
}

function validateTaxLookup(body) {
  const errors = [];
  if (!body || typeof body !== "object") return ["Body must be JSON object"];

  if (!/^[A-Z]{2}$/.test(body.origin_country || "")) errors.push("origin_country must be ISO2 uppercase");
  if (!/^[A-Z]{2}$/.test(body.destination_country || "")) errors.push("destination_country must be ISO2 uppercase");
  if (!["import", "export"].includes(body.trade_type)) errors.push("trade_type must be import or export");
  if (!["crude_oil", "diesel", "lng", "coal", "battery_material"].includes(body.asset_type)) {
    errors.push("asset_type is invalid");
  }
  if (!isIsoDate(body.trade_date || "")) errors.push("trade_date must be YYYY-MM-DD");
  if (body.hs_code != null) {
    const hs = String(body.hs_code);
    if (hs.length < 4 || hs.length > 10) errors.push("hs_code length must be 4..10");
  }
  if (body.declared_value_usd != null && (typeof body.declared_value_usd !== "number" || body.declared_value_usd < 0)) {
    errors.push("declared_value_usd must be a non-negative number");
  }
  return errors;
}

async function safeJson(request) {
  try {
    return await request.json();
  } catch {
    throw new Error("Invalid JSON body");
  }
}

async function sha256Hex(input) {
  const enc = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", enc);
  const bytes = new Uint8Array(digest);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function badRequest(message) {
  return json({ error: { code: "BAD_REQUEST", message } }, 400);
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function isIsoDate(value) {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function todayIsoDate() {
  return new Date().toISOString().slice(0, 10);
}

function round2(n) {
  return Math.round(n * 100) / 100;
}

function round6(n) {
  return Math.round(n * 1_000_000) / 1_000_000;
}

function parseJsonArray(value) {
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}
