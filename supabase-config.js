/* =========================================================
   Conexión a Supabase — compartida por /admin, /usuarios y /checador
   =========================================================
   La "anon key" está diseñada por Supabase para ser pública y vivir en
   código de navegador (como esta app). NO es un secreto por sí misma.
   Quien de verdad protege tus datos son las políticas de Row Level
   Security (RLS) definidas en schema.sql. Tal como está ese archivo,
   las políticas son PERMISIVAS (cualquiera con este anon key puede
   leer, crear, editar y borrar todo) para que la app funcione de
   inmediato sin sistema de usuarios. Antes de usar esto en producción
   con datos reales de personas, activa Supabase Auth y restringe las
   políticas — ver la nota al final de schema.sql.
*/
const SUPABASE_URL = 'https://hkszdgfdnffgsvmxqgwd.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhrc3pkZ2ZkbmZmZ3N2bXhxZ3dkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0NjIxNjUsImV4cCI6MjEwNTAzODE2NX0.fNEXV5Y1_FQT-0kpVkjhUtFxoRZQhSMJxZjtSX4MZ1w';

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
