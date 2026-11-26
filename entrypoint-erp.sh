#!/bin/bash
# Entrypoint del ERP en Cloud Run.
#  - Inyecta la contraseña maestra (Secret Manager) en una copia de odoo.conf.
#  - Si la base está vacía, inicializa el esquema (-i base) en el primer arranque.
#  - Delega en el entrypoint oficial de la imagen, que arma los argumentos de BD
#    a partir de HOST / PORT / USER / PASSWORD.
set -euo pipefail

DB_NAME="${DB_NAME:-odoo}"

# 1) Copia escribible de la configuración con el admin_passwd
cp /etc/odoo/odoo.conf /tmp/odoo.conf
if [[ -n "${ADMIN_PASSWD:-}" ]]; then
  echo "admin_passwd = ${ADMIN_PASSWD}" >> /tmp/odoo.conf
fi
export ODOO_RC=/tmp/odoo.conf

# 2) ¿Esquema inicializado?  rc: 0 = sí, 1 = BD vacía o inexistente, 2 = BD inaccesible
INIT_ARGS=()
set +e
python3 - <<'PY'
import os, sys
import psycopg2
try:
    conn = psycopg2.connect(
        host=os.environ["HOST"], port=os.environ.get("PORT", "5432"),
        user=os.environ["USER"], password=os.environ["PASSWORD"],
        dbname=os.environ.get("DB_NAME", "odoo"), connect_timeout=10,
    )
    cur = conn.cursor()
    cur.execute("SELECT to_regclass('public.ir_module_module')")
    sys.exit(0 if cur.fetchone()[0] else 1)
except psycopg2.OperationalError as exc:
    if "does not exist" in str(exc):
        sys.exit(1)  # la base aún no existe: Odoo la crea y la inicializa
    print(f"[entrypoint-erp] no se pudo consultar la BD: {exc}", file=sys.stderr)
    sys.exit(2)
except Exception as exc:
    print(f"[entrypoint-erp] no se pudo consultar la BD: {exc}", file=sys.stderr)
    sys.exit(2)
PY
rc=$?
set -e

if [[ $rc -eq 1 ]]; then
  echo "[entrypoint-erp] BD vacía: se inicializa el módulo base"
  INIT_ARGS=(-i base --without-demo=all)
elif [[ $rc -ne 0 ]]; then
  exit 1
fi

# 3) Arranque (el entrypoint oficial ya recibe HOST/PORT/USER/PASSWORD)
exec /entrypoint.sh "$@" -d "${DB_NAME}" --http-port=8069 ${INIT_ARGS[@]+"${INIT_ARGS[@]}"}
