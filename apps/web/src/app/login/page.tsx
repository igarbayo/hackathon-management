"use client";

import { Suspense, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { LogoHorizontal } from "@/components/brand/logo";
import { OAuthButtons } from "@/components/auth/oauth-buttons";
import { PasswordInput } from "@/components/auth/password-input";
import { useLogIn } from "@/hooks/use-me";
import { ApiError } from "@/lib/api-client";

function LoginContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const logIn = useLogIn();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const next = searchParams.get("next");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      const me = await logIn.mutateAsync({ email, password });
      router.push(next || (me.last_team_id ? `/t/${me.last_team_id}/home` : "/onboarding"));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido iniciar sesión");
    }
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6 p-4">
      <LogoHorizontal className="h-12" priority />
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>
            <h1>Entrar en Hackboard</h1>
          </CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <OAuthButtons />
          <div className="flex items-center gap-2">
            <Separator className="flex-1" />
            <span className="text-muted-foreground text-sm">o con email</span>
            <Separator className="flex-1" />
          </div>

          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="email">Email</Label>
              <Input id="email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="password">Contraseña</Label>
              <PasswordInput
                id="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            {error && <p className="text-destructive text-base">{error}</p>}
            <Button type="submit" loading={logIn.isPending}>
              Entrar
            </Button>
          </form>

          <p className="text-muted-foreground text-center text-base">
            ¿No tienes cuenta?{" "}
            <Link href="/signup" className="text-foreground underline">
              Regístrate
            </Link>
          </p>
        </CardContent>
      </Card>
      <p className="text-muted-foreground text-sm">
        <Link href="/privacy" className="underline">
          Política de privacidad
        </Link>
      </p>
    </main>
  );
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginContent />
    </Suspense>
  );
}
