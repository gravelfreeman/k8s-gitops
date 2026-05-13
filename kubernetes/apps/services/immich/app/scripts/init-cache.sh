#!/usr/bin/env bash
set -euo pipefail

export REDIS_URL="$(node <<'NODE'
const fs = require("fs");
const certDir = "/certs/dragonfly";
const readCert = (name) => fs.readFileSync(`${certDir}/${name}`, "utf8");

const options = {
  host: "immich-dragonfly.immich.svc.cluster.local",
  port: 6379,
  db: 0,
  tls: {
    ca: readCert("ca.crt"),
    cert: readCert("tls.crt"),
    key: readCert("tls.key"),
  },
};

process.stdout.write(`ioredis://${Buffer.from(JSON.stringify(options)).toString("base64")}`);
NODE
)"
