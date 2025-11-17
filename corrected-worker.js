export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const filename = url.searchParams.get("filename");

    if (!filename) {
      return new Response("Missing filename", { status: 400 });
    }

    const BUCKET = "cloudflare-testing";
    const ACCOUNT_ID = "66c94044fd36e21988e02b74fcd4ccc0";
    
    // Return the original public URL that was working for 2 months
    const publicUrl = `https://pub-65e3d702de6e45c6810cabd0b0895357.r2.dev/${filename}`;

    return new Response(JSON.stringify({ url: publicUrl }), {
      headers: { "Content-Type": "application/json" },
    });
  },
};