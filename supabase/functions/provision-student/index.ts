import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return reply(405, { error: "Use POST." });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const initialPassword = Deno.env.get("STUDENT_DEFAULT_PASSWORD");
    if (!supabaseUrl || !anonKey || !serviceKey || !initialPassword || initialPassword.length < 8) {
      return reply(503, { error: "Student login provisioning is not configured yet." });
    }

    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return reply(401, { error: "Sign in as the class teacher first." });

    const callerClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: authorization } },
    });
    const { data: callerData, error: callerError } = await callerClient.auth.getUser();
    if (callerError || !callerData.user) return reply(401, { error: "Your session expired. Sign in again." });

    const body = await request.json();
    const studentId = String(body.student_id || "");
    const classroomId = String(body.classroom_id || "");
    const source = String(body.source || "");
    if (!studentId || !classroomId || !["TEACHER", "GOOGLE"].includes(source)) {
      return reply(400, { error: "A student, class, and valid source are required." });
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: callerProfile, error: profileError } = await admin
      .from("profiles")
      .select("role")
      .eq("user_id", callerData.user.id)
      .maybeSingle();
    if (profileError) return reply(500, { error: "Could not verify the teacher account." });
    if (callerProfile?.role !== "TEACHER") return reply(403, { error: "Only the assigned teacher can create student logins." });

    const { data: assignment, error: assignmentError } = await admin
      .from("classroom_teachers")
      .select("classroom_id")
      .eq("classroom_id", classroomId)
      .eq("user_id", callerData.user.id)
      .maybeSingle();
    if (assignmentError) return reply(500, { error: "Could not verify this class assignment." });
    if (!assignment) return reply(403, { error: "You are not assigned to this class." });

    const { data: student, error: studentError } = await admin
      .from("students")
      .select("id, school_id, classroom_id, name, email, google_student_id, active")
      .eq("id", studentId)
      .eq("classroom_id", classroomId)
      .maybeSingle();
    if (studentError) return reply(500, { error: "Could not load this student." });
    if (!student || !student.active) return reply(404, { error: "The active student was not found in this class." });
    if (source === "GOOGLE" && !student.google_student_id) {
      return reply(400, { error: "This student is not linked to the selected Google Classroom roster." });
    }

    const { data: linkedProfile, error: linkedError } = await admin
      .from("profiles")
      .select("user_id, role")
      .eq("student_id", student.id)
      .maybeSingle();
    if (linkedError) return reply(500, { error: "Could not check for an existing student account." });
    if (linkedProfile) return reply(200, { alreadyLinked: true });

    const email = String(student.email || "").trim().toLowerCase();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return reply(422, { error: "Add a valid student email before creating the login." });
    }

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password: initialPassword,
      email_confirm: true,
      user_metadata: {
        display_name: student.name,
        requested_role: "STUDENT",
        earlypass_must_change_password: true,
      },
    });
    if (createError || !created.user) {
      const duplicate = /already|registered|exists/i.test(createError?.message || "");
      return reply(duplicate ? 409 : 400, {
        error: duplicate
          ? "This email already has a login. Existing accounts and passwords were not changed."
          : createError?.message || "Could not create the student login.",
      });
    }

    const { error: linkError } = await admin.from("profiles").insert({
      user_id: created.user.id,
      school_id: student.school_id,
      role: "STUDENT",
      display_name: student.name,
      student_id: student.id,
    });
    if (linkError) {
      await admin.auth.admin.deleteUser(created.user.id);
      return reply(500, { error: "The login could not be linked to the student record. No account was kept." });
    }

    return reply(200, {
      created: true,
      email,
      password: initialPassword,
      display_name: student.name,
    });
  } catch {
    return reply(400, { error: "The student login request could not be completed." });
  }
});
