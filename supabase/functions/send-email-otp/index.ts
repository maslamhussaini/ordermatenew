import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import * as base64 from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { writeAll } from "https://deno.land/std@0.168.0/streams/write_all.ts";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const body = await req.json();
        const { email, otp, smtp_username, smtp_password } = body;

        if (!email || !otp) throw new Error("Missing email or otp");
        if (!smtp_username || !smtp_password) throw new Error("Missing SMTP credentials");

        // SMTP Config
        const hostname = "smtp.gmail.com";
        const port = 465;

        const conn = await Deno.connectTls({ hostname, port });
        const encoder = new TextEncoder();
        const decoder = new TextDecoder();

        const write = async (text: string) => {
            const data = encoder.encode(text + "\r\n");
            await writeAll(conn, data);
        };

        const read = async () => {
            const buf = new Uint8Array(1024);
            const n = await conn.read(buf);
            if (n === null) return "";
            return decoder.decode(buf.subarray(0, n));
        };

        await read();
        await write("EHLO localhost"); await read();
        await write("AUTH LOGIN"); await read();
        await write(base64.encode(smtp_username)); await read();
        await write(base64.encode(smtp_password));
        const authRes = await read();
        if (!authRes.includes("235")) throw new Error(`SMTP Auth failed: ${authRes}`);

        await write(`MAIL FROM: <${smtp_username}>`); await read();
        await write(`RCPT TO: <${email}>`); await read();
        await write("DATA"); await read();

        const emailHeader = `From: OrderMate <${smtp_username}>
To: ${email}
Subject: OrderMate App - Your Verification Code
MIME-Version: 1.0
Content-Type: text/html; charset=utf-8`;

        const html = `
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h2 style="color: #2196F3;">OrderMate App Verification</h2>
          <p>Hello,</p>
          <p>Your verification code is:</p>
          <div style="font-size: 32px; font-weight: bold; color: #333; margin: 20px 0;">${otp}</div>
          <p style="color: #666; font-size: 14px;">This code is valid for 10 minutes. If you did not request this, please ignore this email.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
          <p style="font-size: 12px; color: #999;">Sent safely via OrderMate App</p>
        </div>`;

        await write(emailHeader);
        await write("");
        await write(html.replace(/\r\n/g, '\n').replace(/\n/g, '\r\n'));
        await write(".");
        const sendRes = await read();
        if (!sendRes.includes("250")) throw new Error(`Sending failed: ${sendRes}`);

        await write("QUIT");
        try { await read(); conn.close(); } catch (_) { }

        return new Response(
            JSON.stringify({ message: 'Success' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        );

    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        );
    }
});
