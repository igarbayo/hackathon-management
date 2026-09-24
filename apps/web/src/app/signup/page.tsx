"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { LogoHorizontal } from "@/components/brand/logo";
import { OAuthButtons } from "@/components/auth/oauth-buttons";
import { PasswordInput } from "@/components/auth/password-input";
import { useSignUp } from "@/hooks/use-me";
import { ApiError } from "@/lib/api-client";

export default function SignupPage() {
  const router = useRouter();
  const signUp = useSignUp();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await signUp.mutateAsync({ name, email, password });
      router.push("/onboarding");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se ha podido crear la cuenta");
    }
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6 p-4">
      <LogoHorizontal className="h-12" priority />
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>
            <h1>Crear cuenta en Hackboard</h1>
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
              <Label htmlFor="name">Nombre</Label>
              <Input id="name" required value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="email">Email</Label>
              <Input id="email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="password">Contraseña</Label>
              <PasswordInput
                id="password"
                required
                minLength={10}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <p className="text-muted-foreground text-sm">Mínimo 10 caracteres.</p>
            </div>
            {error && <p className="text-destructive text-base">{error}</p>}
            <Button type="submit" loading={signUp.isPending}>
              Crear cuenta
            </Button>
          </form>

          <p className="text-muted-foreground text-sm">
            Tienes que tener al menos 16 años. Al crear la cuenta trataré tus datos como explica la{" "}
            <Link href="/privacy" className="text-foreground underline">
              política de privacidad
            </Link>
            .
          </p>

          <p className="text-muted-foreground text-center text-base">
            ¿Ya tienes cuenta?{" "}
            <Link href="/login" className="text-foreground underline">
              Entra
            </Link>
          </p>
        </CardContent>
      </Card>
    </main>
  );
}
