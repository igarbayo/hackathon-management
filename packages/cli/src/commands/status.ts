import { readCredentials } from "../credentials";
import { readConfigCache } from "../config-cache";
import { readQueueEvents } from "../queue";

export function runStatus(): void {
  const creds = readCredentials();
  if (!creds) {
    console.log("No conectado. Ejecuta `hackboard init` para empezar.");
    return;
  }

  const state = creds.connected === false ? "desconectado (token revocado, ejecuta hackboard init de nuevo)" : creds.paused ? "pausado" : "conectado";
  const cache = readConfigCache();

  console.log(`Equipo: ${creds.team_name}`);
  console.log(`Estado: ${state}`);
  console.log(`Nivel de privacidad: ${creds.privacy_level}`);
  console.log(`Eventos en cola: ${readQueueEvents().length}`);
  console.log(`Repos vinculados: ${cache?.repos.join(", ") || "(sin descargar todavía, ejecuta hackboard flush)"}`);
}
