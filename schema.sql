-- =========================================================================
-- Bitácora RRHH — esquema de base de datos para Supabase (PostgreSQL)
-- =========================================================================
-- Cómo usarlo:
--   1. Entra a tu proyecto en https://supabase.com/dashboard
--   2. Ve a "SQL Editor" → "New query"
--   3. Pega TODO este archivo y presiona "Run"
--   4. Revisa la sección de RLS al final antes de usarlo con datos reales
--
-- Este esquema cubre todos los módulos de la app: colaboradores, turnos,
-- asistencia, permisos, documentos, denuncias, activos, nómina, encuestas,
-- reconocimientos, objetivos, beneficios, adelantos de sueldo, reportes,
-- comunicación y la configuración de marca de la empresa.
--
-- Por ahora, la interfaz de administrador (/admin) sólo lee y escribe en
-- vivo las tablas: company_config, empleados y asistencia (son las que
-- pediste conectar). El resto de las tablas ya están listas para recibir
-- datos, pero las pantallas de nómina, documentos, denuncias, etc. de la
-- demo siguen usando datos de ejemplo en memoria — puedes conectarlas
-- después siguiendo el mismo patrón (ver comentarios en el código).
-- =========================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Configuración de la empresa (fila única)
-- ---------------------------------------------------------------------
create table if not exists company_config (
  id integer primary key default 1,
  nombre text not null default 'Mi Empresa',
  nit text,
  logo text,                          -- imagen en base64 (data URL) o URL externa
  smmlv numeric default 1423500,
  aux_transporte numeric default 200000,
  salud_pct numeric default 4,
  pension_pct numeric default 4,
  horas_mes numeric default 230,
  r_hed numeric default 25,
  r_hen numeric default 75,
  r_hefd numeric default 100,
  r_hefn numeric default 150,
  updated_at timestamptz default now(),
  constraint company_config_singleton check (id = 1)
);
insert into company_config (id, nombre, nit) values (1, 'Mi Empresa', null)
  on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Colaboradores
-- ---------------------------------------------------------------------
create table if not exists empleados (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  cedula text unique,
  cargo text,
  area text,
  ingreso date,
  contrato text default 'Término indefinido',
  salario numeric default 0,
  estado text default 'Activo',                 -- 'Activo' | 'Inactivo'
  email text,
  telefono text,
  supervisor text,
  huella boolean default false,                  -- huella registrada (insignia informativa)
  puntos integer default 0,                       -- puntos para el catálogo de beneficios
  pin text,                                       -- PIN opcional de 4 dígitos (autoservicio, NO es seguridad real)
  nfc_id text unique,                             -- serial de la tarjeta/llavero NFC asignada
  webauthn_credential_id text,                    -- credencial biométrica (huella/rostro) registrada en un dispositivo
  webauthn_public_key text,
  created_at timestamptz default now()
);
create index if not exists idx_empleados_estado on empleados(estado);

-- ---------------------------------------------------------------------
-- Turnos
-- ---------------------------------------------------------------------
create table if not exists turnos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  hora_inicio time,
  hora_fin time,
  dias text
);

-- ---------------------------------------------------------------------
-- Asistencia (una fila por colaborador y día; entrada/salida se actualizan)
-- ---------------------------------------------------------------------
create table if not exists asistencia (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid references empleados(id) on delete cascade,
  fecha date not null default current_date,
  entrada time,
  salida time,
  estado text,                                    -- 'A tiempo' | 'Tarde' | 'Ausente'
  metodo text default 'Manual',                   -- 'Manual' | 'NFC' | 'Huella'
  created_at timestamptz default now(),
  unique (empleado_id, fecha)
);
create index if not exists idx_asistencia_fecha on asistencia(fecha);

-- ---------------------------------------------------------------------
-- Permisos y vacaciones
-- ---------------------------------------------------------------------
create table if not exists permisos (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid references empleados(id) on delete cascade,
  tipo text,
  fecha_inicio date,
  fecha_fin date,
  dias integer,
  motivo text,
  estado text default 'Pendiente',                -- 'Pendiente' | 'Aprobado' | 'Rechazado'
  created_at timestamptz default now()
);
create index if not exists idx_permisos_estado on permisos(estado);

-- ---------------------------------------------------------------------
-- Documentos y firma electrónica
-- ---------------------------------------------------------------------
create table if not exists documentos (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid references empleados(id) on delete cascade,
  nombre text,
  tipo text,
  fecha date default current_date,
  estado text default 'Pendiente',                -- 'Pendiente' | 'Firmado'
  firmante text,
  firma_fecha date,
  firma_imagen text,                              -- firma dibujada, en base64 (opcional)
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------------
-- Canal de denuncias
-- ---------------------------------------------------------------------
create table if not exists denuncias (
  id uuid primary key default gen_random_uuid(),
  folio text unique,
  fecha date default current_date,
  categoria text,
  relacion text,
  anonimo boolean default true,
  nombre text,
  email text,
  descripcion text,
  estado text default 'Nuevo',                    -- 'Nuevo' | 'En investigación' | 'Cerrado'
  prioridad text default 'Media',                 -- 'Alta' | 'Media' | 'Baja'
  created_at timestamptz default now()
);
create table if not exists denuncia_comentarios (
  id uuid primary key default gen_random_uuid(),
  denuncia_id uuid references denuncias(id) on delete cascade,
  autor text,
  texto text,
  fecha date default current_date
);

-- ---------------------------------------------------------------------
-- Activos de la empresa
-- ---------------------------------------------------------------------
create table if not exists activos (
  id uuid primary key default gen_random_uuid(),
  nombre text,
  categoria text,                                 -- 'Tangible' | 'Intangible'
  tipo text,
  identificador text,
  estado text default 'Disponible',               -- 'Disponible' | 'Asignado' | 'Mantenimiento' | 'Baja'
  asignado_a uuid references empleados(id),
  fecha date,
  valor numeric default 0
);

-- ---------------------------------------------------------------------
-- Nómina
-- ---------------------------------------------------------------------
create table if not exists nomina_corridas (
  id uuid primary key default gen_random_uuid(),
  periodo text,
  fecha_pago date,
  estado text default 'Borrador'                  -- 'Borrador' | 'Cerrada'
);
create table if not exists nomina_detalle (
  id uuid primary key default gen_random_uuid(),
  corrida_id uuid references nomina_corridas(id) on delete cascade,
  empleado_id uuid references empleados(id) on delete cascade,
  dias numeric default 30,
  hed numeric default 0,
  hen numeric default 0,
  hefd numeric default 0,
  hefn numeric default 0,
  bonif numeric default 0,
  otros numeric default 0,
  otras_ded numeric default 0,
  devengado numeric default 0,
  deducciones numeric default 0,
  neto numeric default 0,
  unique (corrida_id, empleado_id)
);

-- ---------------------------------------------------------------------
-- Encuestas
-- ---------------------------------------------------------------------
create table if not exists encuestas (
  id uuid primary key default gen_random_uuid(),
  titulo text,
  descripcion text,
  estado text default 'Activa',                   -- 'Activa' | 'Cerrada'
  creada date default current_date
);
create table if not exists encuesta_preguntas (
  id uuid primary key default gen_random_uuid(),
  encuesta_id uuid references encuestas(id) on delete cascade,
  texto text,
  tipo text,                                       -- 'clima' | 'opcion' | 'abierta'
  opciones text[]
);
create table if not exists encuesta_respuestas (
  id uuid primary key default gen_random_uuid(),
  encuesta_id uuid references encuestas(id) on delete cascade,
  empleado_id uuid references empleados(id) on delete cascade,
  fecha date default current_date,
  valores jsonb
);

-- ---------------------------------------------------------------------
-- Reconocimientos
-- ---------------------------------------------------------------------
create table if not exists reconocimientos (
  id uuid primary key default gen_random_uuid(),
  categoria text,
  color text,
  de_empleado uuid references empleados(id),
  para_empleado uuid references empleados(id),
  mensaje text,
  fecha date default current_date,
  likes integer default 0
);
create table if not exists reconocimiento_comentarios (
  id uuid primary key default gen_random_uuid(),
  reconocimiento_id uuid references reconocimientos(id) on delete cascade,
  empleado_id uuid references empleados(id),
  texto text,
  fecha date default current_date
);

-- ---------------------------------------------------------------------
-- Objetivos
-- ---------------------------------------------------------------------
create table if not exists objetivos (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid references empleados(id) on delete cascade,
  tipo text,                                       -- 'Organizacional' | 'Personal'
  descripcion text,
  meta text,
  peso numeric default 0,
  avance numeric default 0,
  fecha_termino date,
  activo boolean default true,
  aprobado boolean default false,
  fecha_aprobacion date,
  creado_por text
);

-- ---------------------------------------------------------------------
-- Beneficios
-- ---------------------------------------------------------------------
create table if not exists beneficios (
  id uuid primary key default gen_random_uuid(),
  categoria text,
  nombre text,
  descripcion text,
  puntos integer default 0,
  emoji text
);
create table if not exists beneficio_solicitudes (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid references empleados(id) on delete cascade,
  beneficio_id uuid references beneficios(id) on delete cascade,
  fecha date default current_date,
  estado text default 'Pendiente'                 -- 'Pendiente' | 'Aprobado' | 'Rechazado'
);

-- ---------------------------------------------------------------------
-- Adelantos de sueldo
-- ---------------------------------------------------------------------
create table if not exists adelantos (
  id uuid primary key default gen_random_uuid(),
  empleado_id uuid references empleados(id) on delete cascade,
  fecha date default current_date,
  monto numeric default 0,
  estado text default 'Pagado'
);

-- ---------------------------------------------------------------------
-- Reportes generados (bitácora de exportaciones)
-- ---------------------------------------------------------------------
create table if not exists reportes (
  id uuid primary key default gen_random_uuid(),
  nombre text,
  tipo text,
  usuario text,
  fecha timestamptz default now()
);

-- ---------------------------------------------------------------------
-- Comunicación multicanal (simulada — no hay integración real con
-- Gmail/Outlook/WhatsApp, pero la estructura queda lista si algún día
-- se conecta a un proveedor real por API)
-- ---------------------------------------------------------------------
create table if not exists comunicacion_hilos (
  id uuid primary key default gen_random_uuid(),
  canal text,                                      -- 'gmail' | 'outlook' | 'whatsapp'
  contacto text,
  asunto text,
  leido boolean default false,
  fecha timestamptz default now()
);
create table if not exists comunicacion_mensajes (
  id uuid primary key default gen_random_uuid(),
  hilo_id uuid references comunicacion_hilos(id) on delete cascade,
  de text,                                         -- 'ellos' | 'nosotros'
  texto text,
  hora text,
  fecha timestamptz default now()
);

-- =========================================================================
-- Datos de partida (para que /admin no arranque completamente vacío)
-- =========================================================================
insert into turnos (nombre, hora_inicio, hora_fin, dias) values
  ('Administrativo', '08:00', '17:00', 'Lun–Vie'),
  ('Operaciones / Bodega', '06:30', '15:30', 'Lun–Sáb'),
  ('Comercial', '09:00', '18:00', 'Lun–Vie')
on conflict do nothing;

insert into beneficios (categoria, nombre, descripcion, puntos, emoji) values
  ('Fitness', 'Reembolso semestral de gimnasio', 'Reembolsa hasta $150.000 de tu membresía cada semestre.', 150, '🏃'),
  ('Salud', 'Chequeo médico preferencial', 'Acceso prioritario a exámenes médicos anuales.', 200, '❤️'),
  ('Conocimiento', 'Auxilio de estudio', 'Apoyo económico para cursos y certificaciones.', 300, '🎓'),
  ('Seguros', 'Póliza de vida grupal', 'Cobertura adicional para ti y tu familia.', 250, '🛡️'),
  ('Restaurantes', 'Descuentos en restaurantes aliados', '15% de descuento en más de 40 restaurantes.', 80, '🍔'),
  ('Otros', 'Día de cumpleaños libre', 'Un día libre remunerado en tu cumpleaños.', 50, '🎂')
on conflict do nothing;

-- Deja "empleados" vacía a propósito: créalos desde /admin → Colaboradores,
-- así cada fila queda con tu información real desde el primer momento.

-- =========================================================================
-- Row Level Security (RLS)
-- =========================================================================
-- ⚠️  IMPORTANTE — léelo antes de usar esto con datos reales de personas:
--
-- Las políticas de abajo son PERMISIVAS a propósito: cualquiera que tenga
-- el "anon key" (que queda visible en el código fuente de tu sitio en
-- GitHub Pages, porque así funcionan las apps 100% del lado del cliente)
-- puede leer, crear, editar y borrar CUALQUIER fila de CUALQUIER tabla.
-- Esto es lo que hace que la app funcione ahora mismo sin necesitar login,
-- tal como la pediste. No es un descuido: es la única forma de que un
-- sitio estático sin backend propio pueda escribir en la base de datos.
--
-- El botón de "borrar todos los empleados" pide la clave 0000 solo como
-- una confirmación en pantalla (para evitar un clic accidental) — esa
-- clave vive en el código y CUALQUIERA que revise el código fuente puede
-- verla o saltársela y llamar a la base de datos directamente. No es
-- protección real.
--
-- Antes de cargar datos reales de tus colaboradores (cédulas, salarios,
-- denuncias, etc.), lo recomendable es:
--   1. Activar Supabase Auth (login con correo/contraseña o magic link).
--   2. Cambiar las políticas de abajo para exigir auth.uid() y roles
--      (por ejemplo: solo un usuario marcado como "admin" en una tabla
--      de roles puede hacer DELETE en "empleados").
--   3. Restringir escritura pública solo a lo estrictamente necesario
--      (por ejemplo: "asistencia" puede aceptar inserts anónimos desde
--      el checador, pero "nomina_detalle" no debería).
-- Puedo ayudarte a armar esas políticas más restrictivas cuando quieras
-- dar ese paso — por ahora quedan abiertas para que puedas probar todo.

do $$
declare t text;
begin
  for t in
    select tablename from pg_tables
    where schemaname = 'public'
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists "acceso_total_demo" on public.%I;', t);
    execute format(
      'create policy "acceso_total_demo" on public.%I for all using (true) with check (true);',
      t
    );
  end loop;
end $$;
