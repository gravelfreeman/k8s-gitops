#!/usr/bin/env bash
set -euo pipefail

mkdir -p /usr/src/app/upload/{backups,encoded-video,library,profile,thumbs,upload}
for folder in backups encoded-video library profile thumbs upload; do
  touch "/usr/src/app/upload/$${folder}/.immich"
done

users="$(cd /usr/src/app/server && node <<'NODE'
const { Client } = require("pg");

const client = new Client({
  host: process.env.DB_HOSTNAME,
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_DATABASE_NAME,
});

const quoteIdent = (value) => `"$${value.replaceAll('"', '""')}"`;

(async () => {
  await client.connect();

  const tableResult = await client.query(`
    select table_name
    from information_schema.tables
    where table_schema = 'public' and table_name in ('users', 'user')
    order by case table_name when 'users' then 0 else 1 end
    limit 1
  `);
  if (tableResult.rowCount === 0) {
    throw new Error("Immich users table not found");
  }

  const tableName = tableResult.rows[0].table_name;
  const statusResult = await client.query(`
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = $1
      and column_name = 'status'
  `, [tableName]);

  const where = [
    `"deletedAt" is null`,
    `"storageLabel" is not null`,
    `"storageLabel" <> ''`,
  ];
  if (statusResult.rowCount > 0) {
    where.push(`status = 'active'`);
  }

  const users = await client.query(`
    select id, "storageLabel" as label
    from $${quoteIdent(tableName)}
    where $${where.join(" and ")}
  `);

  for (const user of users.rows) {
    process.stdout.write(`$${user.label}\t$${user.id}\n`);
  }
})()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => client.end());
NODE
)"

printf '%s\n' "$${users}" | while IFS="$(printf '\t')" read -r label uuid; do
  [ -n "$${label}" ] || continue
  case "$${label}" in ""|.|..|*/*) continue;; esac
  [ -d "/mnt/users/$${label}" ] || continue

  mkdir -p "/mnt/users/$${label}"/{encoded-video,library,upload}

  ln -sfn "/mnt/users/$${label}/library" "/usr/src/app/upload/library/$${label}"
  ln -sfn "/mnt/users/$${label}/encoded-video" "/usr/src/app/upload/encoded-video/$${uuid}"
  ln -sfn "/mnt/users/$${label}/upload" "/usr/src/app/upload/upload/$${uuid}"
done
