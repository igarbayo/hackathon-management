# hackboard

CLI de [Hackboard](https://github.com/igarbayo/hackathon-management): conecta Claude Code con el tablero de tu equipo de hackathon. Instala unos hooks que envían a Hackboard la actividad de tus sesiones (metadatos o resúmenes, según el nivel de privacidad que elijas) y, si quieres, registra el servidor MCP de Hackboard en Claude Code.

## Instalación

```sh
npm i -g hackboard
hackboard init --team XXXX-XXXX
```

El código de equipo aparece en **Equipo y ajustes → Claude Code** en la web de Hackboard. Hace falta Node 20 o superior.

Instálalo en global: cada hook ejecuta el binario, y `npx` añadiría latencia a cada llamada.

## Comandos

| Comando | Qué hace |
|---------|----------|
| `hackboard init [--team CODE] [--scope local\|user] [--mcp\|--no-mcp]` | Conecta con tu cuenta desde el navegador, instala los hooks y prueba la conexión. `--scope local` (por defecto) escribe en `<repo>/.claude/settings.local.json`; `user`, en `~/.claude/settings.json`. |
| `hackboard status` | Equipo, nivel de privacidad, si está en pausa y eventos en cola. |
| `hackboard pause` / `resume` | Deja de enviar actividad o la reanuda. |
| `hackboard privacy <metadata\|summaries\|off>` | Cambia el nivel de privacidad. |
| `hackboard test` | Envía un evento de prueba. |
| `hackboard uninstall [--purge]` | Quita los hooks, borra la credencial y revoca el token. `--purge` borra también tus eventos del servidor. |

## Qué se envía y qué no

Nunca se envían diffs, contenido de ficheros, comandos ejecutados, respuestas de Claude ni el texto de tus prompts. Con `metadata` (por defecto) solo viajan el tipo de evento, las horas, la rama, el sha de HEAD, las rutas relativas de los ficheros editados, el número de herramientas usadas y la longitud del prompt; con `summaries`, además, un resumen del turno. Con `off` no se envía nada. Los hooks nunca bloquean a Claude Code: si algo falla, salen sin error y reintentan más tarde.

## Configuración

- `HACKBOARD_API_URL`: URL de la API si usas un despliegue propio de Hackboard.
