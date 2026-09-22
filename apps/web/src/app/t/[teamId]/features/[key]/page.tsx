"use client";

import { use, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, Copy, ThumbsDown, ThumbsUp, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ErrorState, LoadingState } from "@/components/states";
import { useDeleteFeature, useFeature, useUpdateFeature } from "@/hooks/use-features";
import { useCreateArgument, useDeleteArgument, useVoteArgument } from "@/hooks/use-arguments";
import { useMe } from "@/hooks/use-me";
import { suggestedBranchName } from "@/lib/branch-name";
import type { Argument } from "@/types/api";

export default function FeatureDetailPage({ params }: { params: Promise<{ teamId: string; key: string }> }) {
  const { teamId, key } = use(params);
  const router = useRouter();
  const { data: feature, isLoading, isError, refetch } = useFeature(teamId, key);
  const { data: me } = useMe();
  const updateFeature = useUpdateFeature(teamId);
  const deleteFeature = useDeleteFeature(teamId);
  const createArgument = useCreateArgument(teamId, key);
  const voteArgument = useVoteArgument(teamId, key);
  const deleteArgument = useDeleteArgument(teamId, key);
  const [description, setDescription] = useState<string | null>(null);
  const [newArgumentText, setNewArgumentText] = useState({ pro: "", con: "" });

  if (isLoading) return <LoadingState />;
  if (isError || !feature) return <ErrorState onRetry={() => refetch()} />;

  const branchName = suggestedBranchName(feature.key, feature.title);
  const pros = (feature.arguments ?? []).filter((a) => a.kind === "pro").sort((a, b) => b.votes - a.votes);
  const cons = (feature.arguments ?? []).filter((a) => a.kind === "con").sort((a, b) => b.votes - a.votes);

  async function handleDiscard() {
    const reason = window.prompt("Motivo (opcional):") ?? undefined;
    await updateFeature.mutateAsync({ key, status: "discarded", discarded_reason: reason });
  }

  async function handleDelete() {
    await deleteFeature.mutateAsync(key);
    router.push(`/t/${teamId}/features`);
  }

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <Button variant="ghost" size="sm" className="w-fit" onClick={() => router.push(`/t/${teamId}/features`)}>
        <ArrowLeft className="size-4" /> Volver al kanban
      </Button>

      <div className="flex items-start justify-between gap-4">
        <div>
          <Badge variant="outline" className="mb-1">
            {feature.key}
          </Badge>
          <h1 className="text-2xl font-semibold">{feature.title}</h1>
        </div>
        <div className="flex gap-2">
          {feature.status !== "discarded" && (
            <Button variant="outline" onClick={handleDiscard}>
              Descartar
            </Button>
          )}
          <Button variant="ghost" size="icon" aria-label="Borrar feature" onClick={handleDelete}>
            <Trash2 className="size-4" />
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-sm">Descripción</CardTitle>
        </CardHeader>
        <CardContent>
          <Textarea
            value={description ?? feature.description ?? ""}
            onChange={(e) => setDescription(e.target.value)}
            onBlur={() => description !== null && updateFeature.mutate({ key, description })}
            rows={4}
          />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-sm">Cómo vincular trabajo</CardTitle>
        </CardHeader>
        <CardContent className="flex items-center gap-2">
          <code className="bg-muted rounded px-2 py-1 text-sm">{branchName}</code>
          <Button variant="outline" size="sm" onClick={() => navigator.clipboard.writeText(branchName)}>
            <Copy className="size-3.5" /> Copiar
          </Button>
        </CardContent>
      </Card>

      <div className="grid grid-cols-2 gap-4">
        <ArgumentColumn
          title="Pros"
          kind="pro"
          args={pros}
          myUserId={me?.id}
          text={newArgumentText.pro}
          onTextChange={(text) => setNewArgumentText((s) => ({ ...s, pro: text }))}
          onAdd={() => {
            createArgument.mutate({ kind: "pro", text: newArgumentText.pro });
            setNewArgumentText((s) => ({ ...s, pro: "" }));
          }}
          onVote={(id, voted) => voteArgument.mutate({ argumentId: id, voted })}
          onDelete={(id) => deleteArgument.mutate(id)}
        />
        <ArgumentColumn
          title="Contras"
          kind="con"
          args={cons}
          myUserId={me?.id}
          text={newArgumentText.con}
          onTextChange={(text) => setNewArgumentText((s) => ({ ...s, con: text }))}
          onAdd={() => {
            createArgument.mutate({ kind: "con", text: newArgumentText.con });
            setNewArgumentText((s) => ({ ...s, con: "" }));
          }}
          onVote={(id, voted) => voteArgument.mutate({ argumentId: id, voted })}
          onDelete={(id) => deleteArgument.mutate(id)}
        />
      </div>
    </div>
  );
}

function ArgumentColumn({
  title,
  kind,
  args,
  myUserId,
  text,
  onTextChange,
  onAdd,
  onVote,
  onDelete,
}: {
  title: string;
  kind: "pro" | "con";
  args: Argument[];
  myUserId: string | undefined;
  text: string;
  onTextChange: (text: string) => void;
  onAdd: () => void;
  onVote: (id: string, voted: boolean) => void;
  onDelete: (id: string) => void;
}) {
  const Icon = kind === "pro" ? ThumbsUp : ThumbsDown;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">{title}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {args.map((argument) => (
          <div key={argument.id} className="flex items-center gap-2 rounded-md border p-2 text-sm">
            <button
              onClick={() => onVote(argument.id, Boolean(argument.voted_by_me))}
              className="flex items-center gap-1"
              aria-label="Votar"
            >
              <Icon className={argument.voted_by_me ? "size-4 fill-current" : "size-4"} />
              {argument.votes}
            </button>
            <span className="flex-1">{argument.text}</span>
            {argument.author_id === myUserId && (
              <button onClick={() => onDelete(argument.id)} aria-label="Borrar">
                <Trash2 className="text-muted-foreground size-3.5" />
              </button>
            )}
          </div>
        ))}

        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (text.trim()) onAdd();
          }}
          className="flex gap-2"
        >
          <input
            className="flex-1 rounded-md border px-2 py-1 text-sm"
            placeholder={`Añadir ${title.toLowerCase()}…`}
            value={text}
            onChange={(e) => onTextChange(e.target.value)}
            maxLength={280}
          />
          <Button type="submit" size="sm">
            Añadir
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
