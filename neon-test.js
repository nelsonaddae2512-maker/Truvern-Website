const { Client } = require("pg");
(async () => {
  const url = process.env.DIRECT_DATABASE_URL || process.env.DATABASE_URL;
  const safe = url.replace(/:\/\/([^:]+):([^@]+)@/,"://$1:***@");
  try {
    const client = new Client({ connectionString: url, ssl: { rejectUnauthorized: true } });
    await client.connect();
    const r = await client.query("select current_database() db, current_user usr, version()");
    console.log("OK connected:", safe);
    console.log(r.rows[0]);
    await client.end();
    process.exitCode = 0;
  } catch (e) {
    console.error("FAILED:", safe);
    console.error(e && e.message ? e.message : e);
    process.exitCode = 2; // DO NOT exit PowerShell host
  }
})();