import { useState } from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";

// RNF-UI-011: destructive actions ask for explicit confirmation in an
// AlertDialog, never with the browser's window.confirm/prompt/alert.
function ConfirmableDelete({ onDelete }: { onDelete: () => void }) {
  const [open, setOpen] = useState(false);

  return (
    <AlertDialog open={open} onOpenChange={setOpen}>
      <AlertDialogTrigger render={<Button variant="destructive" />}>Delete objective</AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Delete “Win the hackathon”</AlertDialogTitle>
          <AlertDialogDescription>This cannot be undone.</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancel</AlertDialogCancel>
          <AlertDialogAction variant="destructive" onClick={onDelete}>
            Delete objective
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}

describe("Confirmation AlertDialog", () => {
  it("does not delete until it is confirmed in the dialog", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    render(<ConfirmableDelete onDelete={onDelete} />);

    await user.click(screen.getByRole("button", { name: "Delete objective" }));
    expect(onDelete).not.toHaveBeenCalled();

    const dialog = await screen.findByRole("alertdialog");
    expect(dialog).toHaveTextContent("Delete “Win the hackathon”");

    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(onDelete).not.toHaveBeenCalled();
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });

  it("confirming in the dialog runs the action", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    render(<ConfirmableDelete onDelete={onDelete} />);

    await user.click(screen.getByRole("button", { name: "Delete objective" }));
    await screen.findByRole("alertdialog");

    const actions = screen.getAllByRole("button", { name: "Delete objective" });
    await user.click(actions[actions.length - 1]);

    expect(onDelete).toHaveBeenCalledOnce();
  });
});
