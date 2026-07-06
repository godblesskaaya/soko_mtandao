#!/usr/bin/env node

import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";

const PROD_PROJECT_REF = "wqmarlzyzukreiwibwjs";
const PROD_URL = `https://${PROD_PROJECT_REF}.supabase.co`;
const DEFAULT_STAGING_CONFIG = "env/supabase.staging.local.json";
const NPX_BIN = process.platform === "win32"
  ? "C:/Program Files/nodejs/npx.cmd"
  : "npx";

function argValue(name, fallback = undefined) {
  const prefix = `${name}=`;
  const found = process.argv.find((arg) => arg.startsWith(prefix));
  return found ? found.slice(prefix.length) : fallback;
}

const dryRun = process.argv.includes("--dry-run");
const verifyTarget = process.argv.includes("--verify-target");
const stagingConfigPath = argValue("--staging-config", DEFAULT_STAGING_CONFIG);

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8").replace(/^\uFEFF/, ""));
}

function getProjectKeys(projectRef) {
  const raw = execSync(
    `"${NPX_BIN}" --yes --cache .npx-cache-supabase supabase@latest projects api-keys --project-ref ${projectRef} --reveal --output json`,
    { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
  );
  const keys = JSON.parse(raw);
  const service = keys.find((key) =>
    key.name === "service_role" || key.type === "secret" ||
    key.name === "secret"
  );
  if (!service?.api_key) {
    throw new Error(`Could not find service role key for ${projectRef}`);
  }
  return { serviceRoleKey: service.api_key };
}

function encodeObjectPath(path) {
  return path.split("/").map(encodeURIComponent).join("/");
}

async function storageFetch(baseUrl, serviceRoleKey, path, options = {}) {
  const res = await fetch(`${baseUrl}/storage/v1${path}`, {
    ...options,
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      ...(options.headers ?? {}),
    },
  });
  return res;
}

async function fetchJson(baseUrl, serviceRoleKey, path, options = {}) {
  const res = await storageFetch(baseUrl, serviceRoleKey, path, options);
  if (!res.ok) {
    throw new Error(`${options.method ?? "GET"} ${path} failed: ${res.status} ${await res.text()}`);
  }
  return await res.json();
}

async function listBuckets(baseUrl, serviceRoleKey) {
  return await fetchJson(baseUrl, serviceRoleKey, "/bucket");
}

async function listObjects(baseUrl, serviceRoleKey, bucketId, prefix = "") {
  const rows = await fetchJson(
    baseUrl,
    serviceRoleKey,
    `/object/list/${encodeURIComponent(bucketId)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        prefix,
        limit: 1000,
        offset: 0,
        sortBy: { column: "name", order: "asc" },
      }),
    },
  );

  const objects = [];
  for (const item of rows) {
    const objectPath = prefix ? `${prefix}/${item.name}` : item.name;
    if (item.id && item.metadata) {
      objects.push({ bucketId, path: objectPath, metadata: item.metadata });
    } else if (item.name) {
      objects.push(...await listObjects(baseUrl, serviceRoleKey, bucketId, objectPath));
    }
  }
  return objects;
}

async function copyObject(source, target, object) {
  const encodedPath = encodeObjectPath(object.path);
  const downloadPath = `/object/${encodeURIComponent(object.bucketId)}/${encodedPath}`;
  const sourceRes = await storageFetch(source.url, source.serviceRoleKey, downloadPath);
  if (!sourceRes.ok) {
    throw new Error(
      `Download failed for ${object.bucketId}/${object.path}: ${sourceRes.status} ${await sourceRes.text()}`,
    );
  }

  const bytes = new Uint8Array(await sourceRes.arrayBuffer());
  const contentType = sourceRes.headers.get("content-type") ||
    object.metadata?.mimetype ||
    "application/octet-stream";

  if (dryRun) {
    return { bytes: bytes.length, uploaded: false };
  }

  const uploadPath = `/object/${encodeURIComponent(object.bucketId)}/${encodedPath}`;
  const targetRes = await storageFetch(target.url, target.serviceRoleKey, uploadPath, {
    method: "POST",
    headers: {
      "Content-Type": contentType,
      "x-upsert": "true",
    },
    body: bytes,
  });
  if (!targetRes.ok) {
    throw new Error(
      `Upload failed for ${object.bucketId}/${object.path}: ${targetRes.status} ${await targetRes.text()}`,
    );
  }

  const verifyRes = await storageFetch(target.url, target.serviceRoleKey, uploadPath, {
    method: "HEAD",
  });
  if (!verifyRes.ok) {
    throw new Error(
      `Verify failed for ${object.bucketId}/${object.path}: ${verifyRes.status}`,
    );
  }

  return { bytes: bytes.length, uploaded: true };
}

async function main() {
  const staging = readJson(stagingConfigPath);
  if (!staging.supabase_url || !staging.service_role_key) {
    throw new Error(`${stagingConfigPath} is missing supabase_url or service_role_key`);
  }

  const target = {
    url: staging.supabase_url,
    serviceRoleKey: staging.service_role_key,
  };
  if (verifyTarget) {
    const buckets = await listBuckets(target.url, target.serviceRoleKey);
    let totalObjects = 0;
    let totalBytes = 0;

    for (const bucket of buckets) {
      const bucketId = bucket.id ?? bucket.name;
      const objects = await listObjects(target.url, target.serviceRoleKey, bucketId);
      let bucketBytes = 0;

      for (const object of objects) {
        const encodedPath = encodeObjectPath(object.path);
        const res = await storageFetch(
          target.url,
          target.serviceRoleKey,
          `/object/${encodeURIComponent(object.bucketId)}/${encodedPath}`,
        );
        if (!res.ok) {
          throw new Error(
            `Verify download failed for ${object.bucketId}/${object.path}: ${res.status} ${await res.text()}`,
          );
        }
        const bytes = (await res.arrayBuffer()).byteLength;
        bucketBytes += bytes;
        totalBytes += bytes;
      }

      totalObjects += objects.length;
      console.log(`verified ${bucketId}: ${objects.length} objects, ${bucketBytes} bytes`);
    }

    console.log(`verified target: ${totalObjects} objects, ${totalBytes} bytes`);
    return;
  }

  const prodKeys = getProjectKeys(PROD_PROJECT_REF);
  const source = { url: PROD_URL, serviceRoleKey: prodKeys.serviceRoleKey };

  const buckets = await listBuckets(source.url, source.serviceRoleKey);
  let totalObjects = 0;
  let totalBytes = 0;

  for (const bucket of buckets) {
    const bucketId = bucket.id ?? bucket.name;
    const objects = await listObjects(source.url, source.serviceRoleKey, bucketId);
    let bucketBytes = 0;

    for (const object of objects) {
      const result = await copyObject(source, target, object);
      bucketBytes += result.bytes;
      totalBytes += result.bytes;
    }

    totalObjects += objects.length;
    console.log(`${dryRun ? "would copy" : "copied"} ${bucketId}: ${objects.length} objects, ${bucketBytes} bytes`);
  }

  console.log(`${dryRun ? "dry-run" : "complete"}: ${totalObjects} objects, ${totalBytes} bytes`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
