"use client";

import { use, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { ArrowLeftIcon, CopyIcon, EllipsisVerticalIcon, ThumbsDownIcon, ThumbsUpIcon, Trash2Icon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { DatePicker } from "@/components/ui/date-picker";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ErrorState, LoadingState } from "@/components/states";
import { PageHeader } from "@/components/f0/page-header";
import { useDeleteFeature, useFeature, useUpdateFeature } from "@/hooks/use-features";
import { useCreateArgument, useDeleteArgument, useVoteArgument } from "@/hooks/use-arguments";
import { useMe } from "@/hooks/use-me";
import { suggestedBranchName } from "@/lib/branch-name";
import { BranchTag } from "@/components/github/branch-tag";
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
  // `null` = not edited yet, show the server value.
  const [deadline, setDeadline] = useState<Date | undefined | null>(null);
  const [newArgumentText, setNewArgumentText] = useState({ pro: "", con: "" });
  const [discardOpen, setDiscardOpen] = useState(false);
  const [discardReason, setDiscardReason] = useState("");
  const [confirmDelete, setConfirmDelete] = useState(false);

  if (isLoading) return <LoadingState />;
  if (isError || !feature) return <ErrorState onRetry={() => refetch()} />;

  const branchName = suggestedBranchName(feature.key, feature.title);
  const pros = (feature.arguments ?? []).filter((a) => a.kind === "pro").sort((a, b) => b.votes - a.votes);
  const cons = (feature.arguments ?? []).filter((a) => a.kind === "con").sort((a, b) => b.votes - a.votes);

  const shownDeadline = deadline !== null ? deadline : feature.deadline ? new Date(feature.deadline) : undefined;
  const overdue = shownDeadline && shownDeadline < new Date() && !["done", "discarded"].includes(feature.status);

  // RF-FEAT-015, RF-DL-012: date and time, because a hackathon can last only a
  // few hours.
  function handleDeadlineChange(next: Date | undefined) {
    setDeadline(next);
    updateFeature.mutate(
      { key, deadline: next ? next.toISOString() : null },
      { onError: () => toast.error("Could not save the deadline") },
    );
  }

  async function handleDiscard() {
    await updateFeature.mutateAsync({ key, status: "discarded", discarded_reason: discardReason || undefined });
    setDiscardOpen(false);
    setDiscardReason("");
  }

  async function handleDelete() {
    await deleteFeature.mutateAsync(key);
    router.push(`/t/${teamId}/features`);
  }

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <Button variant="ghost" size="sm" className="w-fit" onClick={() => router.push(`/t/${teamId}/features`)}>
        <ArrowLeftIcon className="size-4" /> Back to kanban
      </Button>

      <PageHeader
        title={feature.title}
        breadcrumbs={
          <>
            <span>Features</span>
            <span aria-hidden>›</span>
            <Badge variant="outline">{feature.key}</Badge>
          </>
        }
        actions={
          <>
            {feature.status !== "discarded" && (
              <Dialog open={discardOpen} onOpenChange={setDiscardOpen}>
                <Button variant="outline" onClick={() => setDiscardOpen(true)}>
                  Drop feature
                </Button>
                <DialogContent>
                  <DialogHeader>
                    <DialogTitle>Drop “{feature.title}”</DialogTitle>
                    <DialogDescription>The reason is optional and is recorded in the activity.</DialogDescription>
                  </DialogHeader>
                  <Input
                    placeholder="Reason (optional)"
                    value={discardReason}
                    onChange={(e) => setDiscardReason(e.target.value)}
                  />
                  <DialogFooter>
                    <DialogClose render={<Button variant="ghost" />}>Cancel</DialogClose>
                    <Button onClick={handleDiscard} loading={updateFeature.isPending}>
                      Drop feature
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
            )}
            <AlertDialog open={confirmDelete} onOpenChange={setConfirmDelete}>
              <DropdownMenu>
                <DropdownMenuTrigger
                  render={<Button variant="ghost" size="icon" aria-label="More feature actions" />}
                >
                  <EllipsisVerticalIcon />
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem variant="destructive" onClick={() => setConfirmDelete(true)}>
                    <Trash2Icon className="size-4" /> Delete feature
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Delete “{feature.title}”</AlertDialogTitle>
                  <AlertDialogDescription>
                    This cannot be undone. Its pros and cons are lost.
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancel</AlertDialogCancel>
                  <AlertDialogAction variant="destructive" onClick={handleDelete}>
                    Delete feature
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </>
        }
      />

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Description</CardTitle>
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
          <CardTitle className="text-base">Deadline</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-1.5">
          <Label htmlFor="feature-deadline">Date and time</Label>
          <div className="flex items-center gap-2">
            <DatePicker id="feature-deadline" value={shownDeadline} onChange={handleDeadlineChange} />
            {shownDeadline && (
              <Button variant="ghost" size="sm" onClick={() => handleDeadlineChange(undefined)}>
                Remove
              </Button>
            )}
          </div>
          {overdue && <p className="text-sm text-f1-foreground-critical">Overdue</p>}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">How to link work</CardTitle>
        </CardHeader>

        <CardContent className="flex flex-col gap-3">
          <div className="flex items-center gap-2">
            <code className="rounded bg-muted px-2 py-1 text-sm">{branchName}</code>
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                navigator.clipboard.writeText(branchName);
                toast.success("Branch copied");
              }}
            >
              <CopyIcon className="size-3.5" /> Copy
            </Button>
          </div>
          {/* RF-GH-026: branches with GitHub activity for this feature. */}
          <div className="flex flex-col gap-1.5">
            <p className="text-sm font-medium text-f1-foreground">Branches</p>
            {feature.activity_branches && feature.activity_branches.length > 0 ? (
              <div className="flex flex-wrap gap-1.5">
                {feature.activity_branches.map((branch) => (
                  <BranchTag key={branch} name={branch} href={`/t/${teamId}/activity?branch=${encodeURIComponent(branch)}`} />
                ))}
              </div>
            ) : (
              <p className="text-sm text-f1-foreground-secondary">No commits for this feature on any branch yet.</p>
            )}
          </div>
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
          title="Cons"
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
  const Icon = kind === "pro" ? ThumbsUpIcon : ThumbsDownIcon;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">{title}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {args.map((argument) => (
          <div key={argument.id} className="flex items-center gap-2 rounded-md border border-f1-border p-2 text-base">
            <button
              onClick={() => onVote(argument.id, Boolean(argument.voted_by_me))}
              className={`focus-ring flex items-center gap-1 rounded ${argument.voted_by_me ? "text-f1-foreground" : "text-f1-foreground-secondary hover:text-f1-foreground"}`}
              aria-label={argument.voted_by_me ? "Remove your vote" : "Vote for this argument"}
              aria-pressed={Boolean(argument.voted_by_me)}
              title={argument.voted_by_me ? "You voted for this. Click to remove your vote." : "Vote if you agree. One vote per person."}
            >
              <Icon className={argument.voted_by_me ? "size-4 fill-current" : "size-4"} />
              {argument.votes}
            </button>
            <span className="flex-1">{argument.text}</span>
            {argument.author_id === myUserId && (
              <button
                onClick={() => onDelete(argument.id)}
                aria-label="Delete argument"
                className="focus-ring rounded text-f1-foreground-secondary hover:text-f1-foreground-critical"
              >
                <Trash2Icon className="size-3.5" />
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
          <Input
            placeholder={kind === "pro" ? "Add a pro…" : "Add a con…"}
            value={text}
            onChange={(e) => onTextChange(e.target.value)}
            maxLength={280}
          />
          <Button type="submit" size="sm">
            Add
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
