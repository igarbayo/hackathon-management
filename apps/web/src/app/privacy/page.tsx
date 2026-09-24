import type { Metadata } from "next";
import Link from "next/link";
import { LogoHorizontal } from "@/components/brand/logo";
import { publicPageMetadata } from "@/lib/site";

// RF-SEC-007: política de privacidad pública (arts. 13 y 14 del RGPD). El
// contenido refleja el inventario de specs/09-privacidad-seguridad.md: si
// cambia un dato, un tercero o un plazo allí, se cambia también aquí.
export const metadata: Metadata = publicPageMetadata({
  title: "Política de privacidad",
  description: "Qué datos trata Hackboard, para qué, con qué base legal, con quién se comparten, cuánto tiempo se guardan y cómo ejercer tus derechos.",
  path: "/privacy",
});

const UPDATED_AT = "24 de septiembre de 2026";
const CONTACT_EMAIL = "iggarbayo@gmail.com";

type Treatment = {
  title: string;
  data: string;
  purpose: string;
  basis: string;
  retention: string;
};

const TREATMENTS: Treatment[] = [
  {
    title: "Tu cuenta",
    data: "Email, nombre, avatar, contraseña (solo su hash bcrypt, nunca en claro), login e identificador de GitHub e identificador de Google (sub), si entras con ellos.",
    purpose: "Crear tu cuenta, identificarte al entrar y mostrarte a tu equipo.",
    basis: "Ejecución del contrato: prestarte el servicio que pides al registrarte (art. 6.1.b RGPD).",
    retention: "Mientras exista la cuenta.",
  },
  {
    title: "Sesiones",
    data: "Un identificador de sesión (solo su hash), la dirección IP y el navegador (user agent) desde los que entraste.",
    purpose: "Mantener la sesión abierta y detectar accesos indebidos a tu cuenta.",
    basis: "Interés legítimo en la seguridad del servicio y de tu cuenta (art. 6.1.f RGPD).",
    retention: "30 días desde el último uso de la sesión, o hasta que cierres sesión.",
  },
  {
    title: "Contenido del equipo",
    data: "Lo que el equipo escribe en Hackboard: objetivos, features, argumentos y votos, milestones, deadlines, el nombre que usas en el equipo y tus identidades de git.",
    purpose: "Que el equipo organice su hackathon.",
    basis: "Ejecución del contrato (art. 6.1.b RGPD).",
    retention: "Mientras exista el equipo. Si se elimina, se borra definitivamente a los 30 días.",
  },
  {
    title: "Actividad de GitHub",
    data: "De los repositorios que el equipo vincula: sha, mensaje (recortado), autor, email del autor, rutas de ficheros y líneas añadidas y quitadas de cada commit.",
    purpose: "Mostrar el feed de actividad y relacionar el trabajo con las features.",
    basis: "Ejecución del contrato para los miembros del equipo; interés legítimo del equipo en seguir su propio trabajo para el resto de autores de commits (art. 6.1.f RGPD).",
    retention: "90 días después del final del hackathon, salvo que el owner marque el equipo como «conservar».",
  },
  {
    title: "Actividad de Claude Code (opcional)",
    data: "Solo si tú conectas el CLI: tipo de evento, horas, rama, sha, rutas relativas de ficheros editados, número de herramientas y longitud del prompt. Con el nivel «resúmenes», además un resumen de hasta 500 caracteres que escribe Claude y ves antes de enviarlo.",
    purpose: "Mostrar al equipo en qué estás trabajando.",
    basis: "Ejecución del contrato, en una función que solo tú activas y que puedes pausar o desconectar cuando quieras (art. 6.1.b RGPD).",
    retention: "Como la actividad de GitHub. Puedes borrarla en cualquier momento con «Desconectar y borrar mis eventos».",
  },
  {
    title: "Análisis con IA (opcional)",
    data: "Títulos, descripciones, mensajes de commit, rutas y recuentos del equipo, y el resultado del análisis. Tu clave de la API de Gemini, cifrada.",
    purpose: "Calcular la cobertura de objetivos y relacionar commits con features.",
    basis: "Ejecución del contrato, solo cuando configuras tu clave y lanzas un análisis (art. 6.1.b RGPD).",
    retention: "Los análisis, como la actividad. La clave, hasta que la quites o borres la cuenta.",
  },
  {
    title: "Tokens, apps conectadas y webhooks",
    data: "Nombre, prefijo, permisos y último uso de tus tokens (solo su hash); nombre y permisos de las apps que autorizas; de los webhooks salientes, su URL, el secreto cifrado y el estado, código y duración de cada entrega (nunca el contenido).",
    purpose: "Dar acceso programático a Hackboard y avisar a otras herramientas del equipo.",
    basis: "Ejecución del contrato (art. 6.1.b RGPD).",
    retention: "Tokens y conexiones, hasta 30 días después de revocarse o caducar. Entregas de webhooks, 14 días.",
  },
  {
    title: "Registros técnicos",
    data: "Dirección IP, fecha, ruta pedida y resultado de cada petición; contadores temporales por IP para limitar abusos.",
    purpose: "Mantener el servicio funcionando y protegerlo frente a abusos y ataques.",
    basis: "Interés legítimo en la seguridad del servicio (art. 6.1.f RGPD).",
    retention: "Los registros rotan y se sobrescriben automáticamente; los contadores duran como máximo 1 hora.",
  },
  {
    title: "Cuando me escribes",
    data: "Tu email y lo que me cuentes.",
    purpose: "Responderte y atender el ejercicio de tus derechos.",
    basis: "Cumplimiento de una obligación legal cuando ejerces tus derechos (art. 6.1.c RGPD); interés legítimo en el resto de casos.",
    retention: "El tiempo necesario para resolver la petición y, después, el plazo en que puedan exigirse responsabilidades.",
  },
];

const PROVIDERS: { name: string; what: string; where: string }[] = [
  {
    name: "Cloudflare (Cloudflare, Inc.)",
    what: "Todo el tráfico entre tu navegador (o el CLI) y el servidor pasa por su red mediante un túnel cifrado: ve tu dirección IP y las peticiones que haces. Actúa como encargado del tratamiento.",
    where: "Red global, con sede en Estados Unidos.",
  },
  {
    name: "MongoDB Atlas (MongoDB, Inc.)",
    what: "Base de datos donde se guarda todo lo anterior. Actúa como encargado del tratamiento.",
    where: "Servidores en la Unión Europea.",
  },
  {
    name: "Upstash (Upstash, Inc.)",
    what: "Colas y datos temporales (trabajos en segundo plano, contadores, respuestas idempotentes de 24 horas). Actúa como encargado del tratamiento.",
    where: "Servidores en la Unión Europea.",
  },
  {
    name: "GitHub (GitHub, Inc.)",
    what: "Si entras con GitHub o el equipo vincula repositorios: Hackboard recibe tu perfil público y lee la actividad de esos repositorios.",
    where: "Estados Unidos.",
  },
  {
    name: "Google (Google LLC)",
    what: "Si entras con Google: te identifica y nos da tu email, nombre y foto. Si usas el análisis con IA: recibe, con tu clave de Gemini, el contexto del equipo descrito arriba.",
    where: "Estados Unidos.",
  },
  {
    name: "Anthropic (Anthropic, PBC)",
    what: "Solo si conectas Hackboard a claude.ai: recibe lo que Claude consulte del tablero, según los permisos que apruebes.",
    where: "Estados Unidos.",
  },
];

function Section({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  return (
    <section aria-labelledby={id} className="flex flex-col gap-3">
      <h2 id={id} className="text-f1-foreground text-lg font-semibold">
        {title}
      </h2>
      {children}
    </section>
  );
}

function Mail() {
  return (
    <a
      href={`mailto:${CONTACT_EMAIL}`}
      className="text-f1-foreground focus-visible:ring-f1-special-ring rounded-2xs underline focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
    >
      {CONTACT_EMAIL}
    </a>
  );
}

export default function PrivacyPage() {
  return (
    <main className="flex min-h-screen flex-col items-center gap-8 px-4 py-10">
      <Link
        href="/"
        aria-label="Ir a Hackboard"
        className="focus-visible:ring-f1-special-ring rounded focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
      >
        <LogoHorizontal className="h-10" priority />
      </Link>

      <article className="bg-f1-background border-f1-border text-f1-foreground-secondary flex w-full max-w-[712px] flex-col gap-8 rounded-xl border p-6 text-base sm:p-8">
        <header className="flex flex-col gap-1">
          <h1 className="text-f1-foreground text-2xl font-semibold">Política de privacidad</h1>
          <p className="text-sm">Última actualización: {UPDATED_AT}</p>
        </header>

        <p>
          Hackboard es una herramienta para organizar equipos de hackathon. Guarda lo mínimo para funcionar y nunca guarda
          el texto de tus prompts, las respuestas de Claude, diffs ni el contenido de tus ficheros. Aquí tienes el detalle.
        </p>

        <Section id="responsable" title="Quién es el responsable">
          <p>
            Ignacio Garbayo, que desarrolla y gestiona Hackboard como particular. Para cualquier cuestión sobre tus datos,
            escríbeme a <Mail />.
          </p>
        </Section>

        <Section id="datos" title="Qué datos trato, para qué y por qué">
          <div className="flex flex-col gap-3">
            {TREATMENTS.map((t) => (
              <div key={t.title} className="border-f1-border-secondary flex flex-col gap-2 rounded-md border p-4">
                <h3 className="text-f1-foreground font-semibold">{t.title}</h3>
                <dl className="grid gap-x-4 gap-y-1.5 sm:grid-cols-[8rem_1fr]">
                  <dt className="text-f1-foreground-tertiary text-sm sm:text-base">Datos</dt>
                  <dd>{t.data}</dd>
                  <dt className="text-f1-foreground-tertiary text-sm sm:text-base">Para qué</dt>
                  <dd>{t.purpose}</dd>
                  <dt className="text-f1-foreground-tertiary text-sm sm:text-base">Base legal</dt>
                  <dd>{t.basis}</dd>
                  <dt className="text-f1-foreground-tertiary text-sm sm:text-base">Cuánto tiempo</dt>
                  <dd>{t.retention}</dd>
                </dl>
              </div>
            ))}
          </div>
          <p>
            Los datos de tu cuenta son necesarios para usar Hackboard: sin ellos no puedo crearla. Todo lo marcado como
            opcional depende de que tú lo actives.
          </p>
        </Section>

        <Section id="no-usuarios" title="Si no usas Hackboard pero aparece tu nombre">
          <p>
            Si has hecho commits en un repositorio que un equipo vincula a Hackboard, se guardan tu nombre, tu email de git
            y los metadatos de esos commits, obtenidos de GitHub. Se usan solo para el feed de actividad de ese equipo y se
            borran con los plazos de arriba. Si más adelante te unes a ese equipo, esos commits se asocian a tu cuenta por tu
            login o tu email de git. Puedes oponerte o pedir que se borren escribiendo a <Mail />.
          </p>
        </Section>

        <Section id="no-guardo" title="Lo que no guardo nunca">
          <ul className="flex list-disc flex-col gap-1 pl-5">
            <li>El texto de tus prompts ni las respuestas de Claude.</li>
            <li>Diffs ni contenido de ficheros.</li>
            <li>Tu contraseña en claro ni los tokens de Google o GitHub.</li>
            <li>El contenido de los webhooks que recibo de GitHub, más allá de lo necesario para procesarlos.</li>
          </ul>
          <p>No vendo tus datos, no hago publicidad ni creo perfiles comerciales.</p>
        </Section>

        <Section id="terceros" title="Con quién se comparten">
          <p>
            Hackboard funciona en un servidor propio en España. Estos proveedores reciben datos, solo los necesarios para
            su función:
          </p>
          <ul className="flex flex-col gap-2">
            {PROVIDERS.map((p) => (
              <li key={p.name} className="flex flex-col gap-0.5">
                <span className="text-f1-foreground font-medium">{p.name}</span>
                <span>
                  {p.what} {p.where}
                </span>
              </li>
            ))}
          </ul>
          <p>
            Además, los miembros de tu equipo ven lo que se comparte en él; un owner puede enviar eventos del equipo a
            las herramientas que elija mediante webhooks (nunca la actividad de Claude Code), y las apps a las que
            des un token acceden a lo que permitan sus permisos. Lo que esos terceros hagan con los datos depende de sus
            propias condiciones.
          </p>
          <p>
            La clave de Gemini es tuya, así que lo que Google haga con lo que se le envía depende de tu plan. En el plan
            gratuito de la API de Gemini, Google puede usar ese contenido para mejorar sus productos; si no quieres que
            ocurra, usa una clave de un plan de pago.
          </p>
          <p>Solo cedo datos a autoridades cuando una ley me obliga.</p>
        </Section>

        <Section id="transferencias" title="Transferencias fuera de la Unión Europea">
          <p>
            GitHub, Google, Anthropic y Cloudflare están en Estados Unidos, y MongoDB y Upstash son empresas
            estadounidenses aunque guarden los datos en Europa. Estas transferencias se amparan en el Marco de Privacidad de Datos UE-EE. UU.
            cuando la empresa está adherida a él y, si no, en las cláusulas contractuales tipo aprobadas por la Comisión
            Europea (art. 46 RGPD). Puedes pedirme una copia de estas garantías.
          </p>
        </Section>

        <Section id="google" title="Datos de las cuentas de Google">
          <p>
            Si entras con Google, Hackboard solo pide los permisos <code className="text-sm">openid</code>,{" "}
            <code className="text-sm">email</code> y <code className="text-sm">profile</code>: recibe tu identificador,
            tu email (y si está verificado), tu nombre y tu foto. Los usa exclusivamente para crear tu cuenta, dejarte
            entrar y mostrarte a tu equipo. No accede a Gmail, Drive, Calendar ni a ningún otro dato de Google, no guarda
            tus tokens de Google, no transfiere estos datos a terceros salvo lo descrito en esta política y no los usa
            para publicidad ni para entrenar modelos de IA.
          </p>
          <p>
            El uso que hace Hackboard de la información recibida de las API de Google se ajusta a la{" "}
            <a
              href="https://developers.google.com/terms/api-services-user-data-policy"
              className="text-f1-foreground focus-visible:ring-f1-special-ring rounded-2xs underline focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
            >
              Política de datos de usuario de los servicios de las API de Google
            </a>
            , incluidos los requisitos de uso limitado.
          </p>
        </Section>

        <Section id="cookies" title="Cookies y almacenamiento local">
          <p>Hackboard solo usa cookies técnicas, imprescindibles para funcionar, así que no necesitan tu consentimiento:</p>
          <ul className="flex list-disc flex-col gap-1 pl-5">
            <li>
              <code className="text-sm">hb_session</code>: mantiene tu sesión abierta. Dura 30 días desde el último uso.
            </li>
            <li>
              <code className="text-sm">hb_csrf_seed</code>: protege los formularios frente a peticiones falsificadas.
              Se borra al cerrar el navegador.
            </li>
          </ul>
          <p>
            En el almacenamiento local del navegador se guarda el tema (claro u oscuro) que eliges. No hay analítica,
            publicidad ni cookies de terceros. Las fotos de perfil se cargan directamente desde GitHub o Google, que
            reciben tu dirección IP al mostrarlas.
          </p>
        </Section>

        <Section id="derechos" title="Tus derechos">
          <p>Puedes, en cualquier momento y gratis:</p>
          <ul className="flex list-disc flex-col gap-1 pl-5">
            <li>Acceder a tus datos y saber cómo se tratan.</li>
            <li>Rectificarlos si son inexactos.</li>
            <li>Suprimirlos, borrando tu cuenta o tus eventos de Claude Code.</li>
            <li>Limitar su tratamiento.</li>
            <li>Oponerte a los tratamientos basados en interés legítimo.</li>
            <li>Recibirlos en un formato estructurado y de uso común (portabilidad).</li>
          </ul>
          <p>
            Muchas cosas las puedes hacer tú mismo desde Ajustes: editar tu perfil, revocar tokens y apps, pausar o
            desconectar Claude Code y borrar sus eventos, y borrar tu cuenta. Para lo demás, escríbeme a <Mail /> desde el
            email de tu cuenta. Te responderé en un plazo máximo de un mes.
          </p>
          <p>
            Si crees que no he tratado bien tus datos, puedes reclamar ante la{" "}
            <a
              href="https://www.aepd.es"
              className="text-f1-foreground focus-visible:ring-f1-special-ring rounded-2xs underline focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
            >
              Agencia Española de Protección de Datos
            </a>{" "}
            o ante la autoridad de control de tu país.
          </p>
          <p>
            Cuando borras tu cuenta se eliminan tu perfil, tus sesiones, tu clave de Gemini y tu actividad de Claude Code,
            y se revocan tus tokens y apps conectadas. En la actividad de GitHub, que es historia del repositorio, pasas a
            aparecer como «Usuario eliminado» junto a tu login. Lo que escribiste en un equipo (features, argumentos…)
            sigue siendo del equipo. Si quedan en alguna copia de seguridad, desaparecen de ella cuando caduca.
          </p>
        </Section>

        <Section id="ia" title="Decisiones automatizadas">
          <p>
            El análisis con IA sugiere qué commits corresponden a cada feature y cuánto se ha cubierto de cada objetivo.
            Son indicaciones para el equipo, que puede corregirlas: no se toman decisiones con efectos jurídicos ni
            parecidos sobre nadie (art. 22 RGPD).
          </p>
        </Section>

        <Section id="seguridad" title="Seguridad">
          <p>
            Toda la comunicación va cifrada con HTTPS. Las contraseñas y los tokens se guardan como hash, las claves y los
            secretos, cifrados, y cada equipo solo puede acceder a sus propios datos. Si hubiera una brecha de seguridad
            que afectase a tus datos, te avisaría y lo notificaría a la autoridad de control según exige la ley.
          </p>
        </Section>

        <Section id="menores" title="Menores">
          <p>
            Hackboard no está dirigido a menores de 16 años y no pueden registrarse. Si sabes que un menor de 16 años ha
            creado una cuenta, escríbeme y la borraré.
          </p>
        </Section>

        <Section id="cambios" title="Cambios en esta política">
          <p>
            Si cambio algo importante, lo avisaré en la aplicación antes de que entre en vigor. La fecha de arriba
            indica la última versión.
          </p>
        </Section>
      </article>

      <footer className="text-f1-foreground-secondary text-sm">
        <Link
          href="/login"
          className="focus-visible:ring-f1-special-ring rounded-2xs underline focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
        >
          Volver a Hackboard
        </Link>
      </footer>
    </main>
  );
}
