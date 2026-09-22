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

// RNF-UI-011: lo destructivo pide confirmación explícita en un AlertDialog,
// nunca un window.confirm/prompt/alert del navegador.
function ConfirmableDelete({ onDelete }: { onDelete: () => void }) {
  const [open, setOpen] = useState(false);

  return (
    <AlertDialog open={open} onOpenChange={setOpen}>
      <AlertDialogTrigger render={<Button variant="destructive" />}>Eliminar objetivo</AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Eliminar «Ganar el hackathon»</AlertDialogTitle>
          <AlertDialogDescription>Esta acción no se puede deshacer.</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>Cancelar</AlertDialogCancel>
          <AlertDialogAction variant="destructive" onClick={onDelete}>
            Eliminar objetivo
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}

describe("AlertDialog de confirmación", () => {
  it("no borra hasta que se confirma en el diálogo", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    render(<ConfirmableDelete onDelete={onDelete} />);

    await user.click(screen.getByRole("button", { name: "Eliminar objetivo" }));
    expect(onDelete).not.toHaveBeenCalled();

    const dialog = await screen.findByRole("alertdialog");
    expect(dialog).toHaveTextContent("Eliminar «Ganar el hackathon»");

    await user.click(screen.getByRole("button", { name: "Cancelar" }));
    expect(onDelete).not.toHaveBeenCalled();
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });

  it("confirmar en el diálogo dispara la acción", async () => {
    const user = userEvent.setup();
    const onDelete = vi.fn();
    render(<ConfirmableDelete onDelete={onDelete} />);

    await user.click(screen.getByRole("button", { name: "Eliminar objetivo" }));
    await screen.findByRole("alertdialog");

    const actions = screen.getAllByRole("button", { name: "Eliminar objetivo" });
    await user.click(actions[actions.length - 1]);

    expect(onDelete).toHaveBeenCalledOnce();
  });
});
