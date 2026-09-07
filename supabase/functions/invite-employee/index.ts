import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import * as base64 from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { writeAll } from "https://deno.land/std@0.168.0/streams/write_all.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    const logs: string[] = [];
    const log = (msg: string) => {
        console.log(msg);
        logs.push(msg);
    };

    try {
        const body = await req.json();
        const { email, full_name, password: userPassword, smtp_settings, email_subject, email_html, generate_link, redirect_to } = body;

        if (!email) throw new Error("Missing email");
        if (!smtp_settings?.username || !smtp_settings?.password) throw new Error("Missing SMTP credentials");

        const { username, password } = smtp_settings;
        let finalHtml = email_html;
        let authUserId = null;

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        log(`Processing Auth for: ${email}`);

        // Try creating the user
        const { data: userData, error: createError } = await supabaseAdmin.auth.admin.createUser({
            email: email,
            password: userPassword,
            email_confirm: true,
            user_metadata: { full_name: full_name }
        });

        if (userData?.user) {
            authUserId = userData.user.id;
            log(`New user created: ${authUserId}`);
        } else if (createError && (createError.message.toLowerCase().includes('already registered') || createError.status === 422)) {
            log("User exists. Finding user to update...");

            // Re-fetch users to find the ID. 
            // Note: In large systems, this should be a direct lookup if possible, 
            // but getUserByEmail is missing in this version.
            const { data: { users }, error: listError } = await supabaseAdmin.auth.admin.listUsers();
            if (listError) throw new Error(`List Users Error: ${listError.message}`);

            const existing = users.find(u => u.email?.toLowerCase() === email.toLowerCase());
            if (!existing) {
                // If not in first 50, try searching the profiles if they exist or just throw
                throw new Error("Email already registered but not found in user list (check pagination).");
            }

            authUserId = existing.id;
            log(`Updating existing user: ${authUserId}`);

            const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(authUserId, {
                password: userPassword,
                user_metadata: { full_name: full_name }
            });

            if (updateError) log(`Update note: ${updateError.message}`);
        } else if (createError) {
            throw new Error(`Auth Error: ${createError.message}`);
        }

        if (!authUserId) throw new Error("Failed to resolve Auth User ID");

        // 2. Generate Link
        if (generate_link) {
            log("Generating invitation link...");
            try {
                const redirectUrl = redirect_to ?? 'https://ordermate-app.com/login';
                const { data, error } = await supabaseAdmin.auth.admin.generateLink({
                    type: 'recovery',
                    email: email,
                    options: { redirectTo: redirectUrl }
                });

                if (error) {
                    log(`Link Gen Error: ${error.message}`);
                    finalHtml = finalHtml.replace('{{ACTION_URL}}', redirectUrl);
                } else {
                    const actionLink = data.properties?.action_link ?? redirectUrl;
                    finalHtml = finalHtml.replace('{{ACTION_URL}}', actionLink);
                }
            } catch (linkError) {
                log(`Link Logic error: ${linkError}`);
                finalHtml = finalHtml.replace('{{ACTION_URL}}', redirect_to ?? '#');
            }
        } else {
            finalHtml = finalHtml.replace('{{ACTION_URL}}', redirect_to ?? '#');
        }

        // 3. Send Email
        log(`Sending email...`);
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
        await write(base64.encode(username)); await read();
        await write(base64.encode(password));
        const authRes = await read();
        if (!authRes.includes("235")) throw new Error(`SMTP Auth failed: ${authRes}`);

        await write(`MAIL FROM: <${username}>`); await read();
        await write(`RCPT TO: <${email}>`); await read();
        await write("DATA"); await read();

        const emailHeader = `From: OrderMate <${username}>
To: ${email}
Subject: ${email_subject ?? 'Welcome to OrderMate'}
MIME-Version: 1.0
Content-Type: text/html; charset=utf-8`;

        await write(emailHeader);
        await write("");
        await write(finalHtml.replace(/\r\n/g, '\n').replace(/\n/g, '\r\n'));
        await write(".");
        const sendRes = await read();
        if (!sendRes.includes("250")) throw new Error(`Sending failed: ${sendRes}`);

        await write("QUIT");
        try { await read(); conn.close(); } catch (_) { }

        return new Response(
            JSON.stringify({ message: 'Success', user_id: authUserId, debug_logs: logs }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        );

    } catch (error) {
        console.error("Error:", error);
        return new Response(
            JSON.stringify({ error: error.message, debug_logs: logs }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        );
    }
});
