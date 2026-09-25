// Default exclusions (08-integracion-claude-code.md#qué-recoge-cada-hook): not
// even the path is sent. No external dependencies: the patterns the product
// uses are simple (basename or **/something/**), so a minimal glob is enough.
export const DEFAULT_EXCLUDE_GLOBS = [".env*", "**/secrets/**", "**/*.pem", "**/*.key", "**/credentials*"];

function globToRegExp(glob: string): RegExp {
  let pattern = "";
  for (let i = 0; i < glob.length; i++) {
    const char = glob[i];
    if (char === "*") {
      if (glob[i + 1] === "*") {
        pattern += ".*";
        i++;
        if (glob[i + 1] === "/") i++;
      } else {
        pattern += "[^/]*";
      }
    } else if ("+.()^${}|\\".includes(char)) {
      pattern += `\\${char}`;
    } else {
      pattern += char;
    }
  }
  return new RegExp(`^${pattern}$`);
}

// A pattern without "/" only compares the file name, in any folder (like
// .gitignore); one with "/" compares the full relative path.
export function isExcluded(relativePath: string, globs: string[]): boolean {
  const posixPath = relativePath.split("\\").join("/");
  const base = posixPath.split("/").pop() ?? posixPath;

  return globs.some((glob) => {
    const regexp = globToRegExp(glob);
    return glob.includes("/") ? regexp.test(posixPath) : regexp.test(base);
  });
}
