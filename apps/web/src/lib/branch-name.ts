// RF-FEAT-018: suggested branch name f-12-title-in-kebab-case.
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
