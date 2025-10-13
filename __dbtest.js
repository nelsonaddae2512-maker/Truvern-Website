const { Client } = require("pg");
(async ()=>{
  try{
    const c1 = new Client({ connectionString: process.env.DATABASE_URL });
    await c1.connect(); await c1.end();
    console.log("POOLER: OK");

    const c2 = new Client({ connectionString: process.env.DIRECT_DATABASE_URL });
    await c2.connect(); await c2.end();
    console.log("DIRECT: OK");
    process.exit(0);
  }catch(e){
    console.error("DB TEST FAILED:", e.message);
    process.exit(2);
  }
})();