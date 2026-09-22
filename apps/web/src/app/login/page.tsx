"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { OAuthButtons } from "@/components/auth/oauth-buttons";
import { useLogIn } from "@/hooks/use-me";
import { ApiError } from "@/lib/api-client";

export default function LoginPage() {
  const router = useRouter();
  const logIn = useLogIn();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      const me = await logIn.mutateAsync({ email, password });
      router.push(me.last_team_id ? `/t/${me.last_team_id}/home` : "/onboarding");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido iniciar sesión");
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Entrar en Hackboard</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <OAuthButtons />
          <div className="flex items-center gap-2">
            <Separator className="flex-1" />
            <span className="text-muted-foreground text-xs">o con email</span>
            <Separator className="flex-1" />
          </div>

          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="email">Email</Label>
              <Input id="email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="password">Contraseña</Label>
              <Input
                id="password"
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            {error && <p className="text-destructive text-sm">{error}</p>}
            <Button type="submit" disabled={logIn.isPending}>
              {logIn.isPending ? "Entrando…" : "Entrar"}
            </Button>
          </form>

          <p className="text-muted-foreground text-center text-sm">
            ¿No tienes cuenta?{" "}
            <Link href="/signup" className="text-foreground underline">
              Regístrate
            </Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
