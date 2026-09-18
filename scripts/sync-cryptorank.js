/*
  Server-side sync starter.
  1) Create a CRYPTORANK_API_KEY environment variable.
  2) Run: npm run sync
  3) Replace the demo writer with your DB upsert once the data model is finalized.

  CryptoRank API v2 uses X-Api-Key authentication and exposes:
  GET https://api.cryptorank.io/v2/drophunting/activities
*/
const endpoint = "https://api.cryptorank.io/v2/drophunting/activities";
const key = process.env.CRYPTORANK_API_KEY;

if (!key) {
  console.error("Missing CRYPTORANK_API_KEY");
  process.exit(1);
}

const url = new URL(endpoint);
url.searchParams.set("limit", "100");
url.searchParams.set("sortBy", "lastStatusUpdate");
url.searchParams.set("sortDirection", "DESC");

fetch(url, { headers: { "X-Api-Key": key } })
  .then(async (r) => {
    if (!r.ok) throw new Error(`CryptoRank HTTP ${r.status}: ${await r.text()}`);
    return r.json();
  })
  .then((json) => {
    console.log(`Received ${json.data?.length ?? 0} activities.`);
    console.log("Next step: normalize fields and upsert into your database.");
    console.dir(json.data?.slice(0, 2), { depth: 5 });
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });