// Exclusiones por defecto (08-integracion-claude-code.md#qué-recoge-cada-hook):
// no se envía ni la ruta. Sin dependencias externas: los patrones que usa el
// producto son simples (basename o **/algo/**), así que basta un glob mínimo.
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

// Un patrón sin "/" compara solo el nombre de fichero, en cualquier carpeta
// (como .gitignore); uno con "/" compara la ruta relativa completa.
export function isExcluded(relativePath: string, globs: string[]): boolean {
  const posixPath = relativePath.split("\\").join("/");
  const base = posixPath.split("/").pop() ?? posixPath;

  return globs.some((glob) => {
    const regexp = globToRegExp(glob);
    return glob.includes("/") ? regexp.test(posixPath) : regexp.test(base);
  });
}
