// RF-FEAT-018: nombre de rama sugerido f-12-titulo-en-kebab.
export function suggestedBranchName(key: string, title: string): string {
  const kebabTitle = title
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);

  return `${key.toLowerCase()}-${kebabTitle}`;
}
