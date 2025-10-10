const { Client } = require("pg");
(async () => {
  const url = process.env.TEST_URL;
  const safe = url.replace(/:\/\/([^:]+):([^@]+)@/,"://$1:***@");
  try {
    const client = new Client({ connectionString: url, ssl: { rejectUnauthorized: true } });
    await client.connect();
    const r = await client.query("select current_database() db, current_user usr");
    console.log("✅ OK:", safe, r.rows[0]);
    await client.end();
    process.exitCode = 0;
  } catch (e) {
    console.log("❌ FAIL:", safe);
    console.log(e && e.message ? e.message : e);
    process.exitCode = 2;
  }
})();