# Script simple para ejecutar el backend
import os
import sys

try:
    import cx_Oracle
    print("cx_Oracle iniciado")
except ImportError:
    print("cx_Oracle no está instalado")
    sys.exit(1)

# Verificar Flask
try:
    import flask
    print("Flask instalado correctamente")
except ImportError:
    print("Flask no está instalado")
    sys.exit(1)

print("\nIniciando servidor...")

# Ejecutar la aplicación
if __name__ == "__main__":
    from app import app
    app.run(host='0.0.0.0', port=5001, debug=True)
