# FullCommerce · Smoke Test Cockpit

Herramienta interna para documentar y ejecutar los smoke tests de FullCommerce
(MF + API + Worker), con estado de desarrollo, avance del set de pruebas y
evidencia compartida en vivo entre el equipo.

- **Host:** GitHub Pages (gratis).
- **Estado compartido:** Supabase (free tier) — todos ven y editan el mismo set en tiempo real.
- **Fallback:** sin configurar Supabase, funciona en modo local (localStorage) para uso individual.

---

## Puesta en marcha (una sola vez)

### 1. Crear el proyecto Supabase
1. Entrá a https://supabase.com → **New project** (free tier).
2. Cuando esté listo, abrí **SQL Editor** y ejecutá, en orden:
   - [`schema.sql`](./schema.sql) — crea las tablas `runs`, `case_runs`, `cases`, activa RLS + realtime y el bucket de capturas.
   - [`seed.sql`](./seed.sql) — carga los 38 casos de prueba en la tabla `cases`.
3. En **Project Settings → API** copiá:
   - **Project URL** → `https://xxxx.supabase.co`
   - **anon / public key**

### 2. Conectar el cockpit
Elegí una opción:

- **A (recomendada, compartida):** editá el bloque `window.SMOKE_CONFIG` al inicio de
  [`index.html`](./index.html) con la URL y la anon key, y commiteá. Todo el equipo
  que abra la página queda conectado automáticamente.
- **B (por persona):** dejá el config vacío y cada uno hace click en **Conexión**
  dentro de la app y pega URL + key (queda guardado en su navegador).

### 3. Publicar en GitHub Pages
```bash
cd fullcommerce-smoke-cockpit
git init
git add .
git commit -m "feat: smoke test cockpit"
git remote add origin git@github.com:customer-experience/fullcommerce-smoke-cockpit.git
git push -u origin main
```
En el repo → **Settings → Pages** → *Source: Deploy from a branch* → `main` / `/root`.
La URL queda en `https://customer-experience.github.io/fullcommerce-smoke-cockpit/`.

> Si querés que la página no sea pública, usá un repo **privado** con Pages (requiere plan de la organización).

### 4. Configurar el login (Email → link mágico)
El acceso es por **email**, restringido a un dominio corporativo. El mail trae un
enlace **Sign in** que devuelve a la página ya logueado (no hace falta código).

En Supabase:
1. **Authentication → Providers → Email**: habilitado (viene por defecto).
2. **Authentication → URL Configuration** (clave): poné la URL de Pages como
   *Site URL* y agregala a *Redirect URLs*. Sin esto el link del mail no vuelve.
   `https://seketman.github.io/fullcommerce-smoke-cockpit/`
3. **SQL Editor**: corré [`migrations/002-auth-email-otp.sql`](./migrations/002-auth-email-otp.sql)
   → cambia RLS de `anon` a `authenticated` + restringe por dominio. Y
   [`migrations/003-activity-log.sql`](./migrations/003-activity-log.sql) → crea el
   log de auditoría (botón **Historial**).
4. **Ajustá el dominio** en DOS lugares (mismo valor):
   - `index.html` → `window.SMOKE_ALLOWED_DOMAINS = ["andreani.com"]`
   - el SQL (schema/migration) → `in ('andreani.com')`

> **Código de 6 dígitos (OTP) en vez de link:** requiere **SMTP propio** — el
> template del mail solo se puede editar (agregar `{{ .Token }}`) con SMTP custom.
> La app ya soporta pegar el código; sin SMTP, usá el link.
>
> **Límite:** el SMTP integrado de Supabase manda pocos mails/hora. Para el equipo
> alcanza; si molesta, configurá SMTP propio (y ahí sí podés habilitar el código).

### 5. Usar
- Cada persona entra con su **email corporativo** → recibe un código → verifica.
  La identidad queda firmada automáticamente (`updated_by` = email).
- Marca resultado por caso (OK / Falla / Bloqueado / No testeable) y agrega
  **notas con hora** y **capturas** (subir o pegar con `Ctrl+V`).
- **Nuevo set** archiva el actual (ofrece exportar JSON) y resetea a Pendiente.
- **Salir** cierra la sesión.

---

## Seguridad

- Acceso por **Supabase Auth (Email OTP)** restringido por dominio. Solo usuarios
  logueados con email del dominio permitido leen/escriben (RLS `to authenticated` +
  chequeo de dominio sobre `auth.jwt()->>'email'`). El repo puede ser público sin
  exponer la DB.
- La **publishable key** en `index.html` es browser-safe (no da acceso sin sesión).
- **Nunca** pongas la **service_role / secret key** en `index.html` — esa sí es secreta.
- **Capturas:** el bucket `evidence` es público (las URLs son difíciles de adivinar
  pero no están protegidas por RLS en lectura directa). Si necesitás cerrarlo,
  pasá el bucket a privado + URLs firmadas.
- **Migrar a Microsoft/Azure AD** (SSO solo Andreani): registrar app en el tenant de
  Andreani y usar `signInWithOAuth({ provider: 'azure' })`. El resto del código y las
  RLS por dominio quedan igual.

---

## Archivos
| Archivo | Qué es |
|---|---|
| `index.html` | La app completa (self-contained salvo el SDK de Supabase por CDN). |
| `schema.sql` | Esquema Supabase: tablas, RLS, realtime, bucket de capturas. |
| `README.md` | Este documento. |

## Modelo de datos
- `cases` — catálogo de casos de prueba (`id`, `groups[]`, `module`, `impl`, `title`, `feature`, `precond`, `data`, `steps` jsonb, `expected` jsonb, `warn`, `flag`, `sort`). Editable desde la app.
- `runs` — cada set de pruebas (`id`, `name`, `started_at`, `is_active`). Un solo set activo a la vez.
- `case_runs` — estado + evidencia por caso dentro de un set (`run_id`, `case_id`, `status`, `evidence` jsonb, `updated_by`).
- Bucket `evidence` — capturas de pantalla (URL pública guardada en `evidence[].img`).

## Editar el catálogo de casos
- Click en **Editar casos** (header) → aparece **+ Caso** y, en cada caso, ✎ (editar) y 🗑 (borrar).
- El formulario cubre todos los atributos (id, grupos, módulo, estado de implementación, pasos, esperado, etc.).
- Los cambios se guardan en la tabla `cases` y se propagan al equipo en vivo (realtime).
- El catálogo se carga desde `seed.sql` (38 casos, ya separados por shell `-CORP` / `-PYME`). La app **no** siembra: si la tabla `cases` está vacía, avisa que corras `seed.sql`.
- Sobre un proyecto sembrado con una versión vieja (casos compartidos sin separar), corré `migrations/001-split-shared-cases.sql` una vez.

## Notas técnicas
- La **tabla `cases` es la fuente de verdad** del catálogo (análisis de código 07-2026). El seed inicial está en `seed.sql`; para regenerarlo desde otra fuente, editá ese archivo.
- El SDK de Supabase se carga por CDN (`@supabase/supabase-js@2`). Para reproducibilidad,
  pineá una versión exacta (ej. `@2.58.0`).
- Este cockpit **no puede correr como Artifact de claude.ai** en modo nube: el CSP de
  los Artifacts bloquea el fetch a Supabase. Por eso vive en GitHub Pages.
