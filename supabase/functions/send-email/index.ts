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
        const { email, subject, email_subject, html, email_html, smtp_settings, smtp_username, smtp_password } = body;

        const targetEmail = email;
        const targetSubject = subject || email_subject || 'Verification Code';
        const targetHtml = html || email_html;

        const username = smtp_settings?.username || smtp_username;
        const password = smtp_settings?.password || smtp_password;

        if (!targetEmail) throw new Error("Missing email");
        if (!username || !password) throw new Error("Missing SMTP credentials");

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

        // Handshake
        await read(); // Banner
        await write("EHLO localhost"); await read();
        await write("AUTH LOGIN"); await read();
        await write(base64.encode(username)); await read();
        await write(base64.encode(password));
        const authRes = await read();
        if (!authRes.includes("235")) throw new Error("SMTP Auth failed: " + authRes);

        await write("MAIL FROM: <" + username + ">"); await read();
        await write("RCPT TO: <" + targetEmail + ">"); await read();
        await write("DATA"); await read();

        const emailHeader = "From: OrderMate <" + username + ">\r\n" +
            "To: " + targetEmail + "\r\n" +
            "Subject: " + targetSubject + "\r\n" +
            "MIME-Version: 1.0\r\n" +
            "Content-Type: text/html; charset=utf-8";

        await write(emailHeader);
        await write("");
        await write(targetHtml.replace(/\r\n/g, '\n').replace(/\n/g, '\r\n'));
        await write(".");
        const sendRes = await read();
        if (!sendRes.includes("250")) throw new Error("Sending failed: " + sendRes);

        await write("QUIT");
        try { await read(); conn.close(); } catch (_) { }

        return new Response(
            JSON.stringify({ message: 'Success' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        );

    } catch (error) {
        console.error("Error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        );
    }
});
