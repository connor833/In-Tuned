export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const filename = url.searchParams.get("filename");

    if (!filename) {
      return new Response("Missing filename", { status: 400 });
    }

    try {
      const BUCKET = "attuned-production";
      const ACCOUNT_ID = "98ee3438200df3fa05fc0f36d43b503e";
      const ACCESS_KEY_ID = "017588d23a9367a8f07ebfbc72d212f0";
      const SECRET_ACCESS_KEY = "4284770ac7b04c65b6ef2700526cdebd432f3ce90ddb4ac3e44d3f6fbbd6220f";
      const REGION = "auto";

      const presignedUrl = await generatePresignedUrl({
        bucket: BUCKET,
        key: filename,
        accessKeyId: ACCESS_KEY_ID,
        secretAccessKey: SECRET_ACCESS_KEY,
        region: REGION,
        accountId: ACCOUNT_ID,
        expiresIn: 3600 // 1 hour
      });

      return new Response(JSON.stringify({ url: presignedUrl }), {
        headers: { "Content-Type": "application/json" },
      });
    } catch (error) {
      console.error("Error generating presigned URL:", error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  },
};

async function generatePresignedUrl({ bucket, key, accessKeyId, secretAccessKey, region, accountId, expiresIn }) {
  const endpoint = `https://${accountId}.r2.cloudflarestorage.com`;
  const method = "PUT";
  
  const now = new Date();
  const dateString = now.toISOString().replace(/[:\-]|\.\d{3}/g, '').slice(0, 15) + 'Z';
  const dateStamp = dateString.slice(0, 8);
  
  const credentialScope = `${dateStamp}/${region}/s3/aws4_request`;
  const credential = `${accessKeyId}/${credentialScope}`;
  
  const queryParams = new URLSearchParams({
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': credential,
    'X-Amz-Date': dateString,
    'X-Amz-Expires': expiresIn.toString(),
    'X-Amz-SignedHeaders': 'host'
  });
  
  const canonicalQueryString = queryParams.toString();
  const canonicalHeaders = `host:${accountId}.r2.cloudflarestorage.com\n`;
  const signedHeaders = 'host';
  const payloadHash = 'UNSIGNED-PAYLOAD';
  
  const canonicalRequest = [
    method,
    `/${bucket}/${key}`,
    canonicalQueryString,
    canonicalHeaders,
    signedHeaders,
    payloadHash
  ].join('\n');
  
  const algorithm = 'AWS4-HMAC-SHA256';
  const stringToSign = [
    algorithm,
    dateString,
    credentialScope,
    await sha256(canonicalRequest)
  ].join('\n');
  
  const signingKey = await getSignatureKey(secretAccessKey, dateStamp, region, 's3');
  const signature = await hmacSha256(signingKey, stringToSign);
  
  queryParams.set('X-Amz-Signature', signature);
  
  return `${endpoint}/${bucket}/${key}?${queryParams.toString()}`;
}

async function sha256(message) {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

async function hmacSha256(key, message) {
  const keyBuffer = typeof key === 'string' ? new TextEncoder().encode(key) : key;
  const msgBuffer = new TextEncoder().encode(message);
  
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyBuffer,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, msgBuffer);
  return Array.from(new Uint8Array(signature)).map(b => b.toString(16).padStart(2, '0')).join('');
}

async function getSignatureKey(key, dateStamp, regionName, serviceName) {
  const kDate = await hmacSha256(`AWS4${key}`, dateStamp);
  const kRegion = await hmacSha256(stringToHex(kDate), regionName);
  const kService = await hmacSha256(stringToHex(kRegion), serviceName);
  const kSigning = await hmacSha256(stringToHex(kService), 'aws4_request');
  return stringToHex(kSigning);
}

function stringToHex(str) {
  return new Uint8Array(str.match(/.{1,2}/g).map(byte => parseInt(byte, 16)));
}
