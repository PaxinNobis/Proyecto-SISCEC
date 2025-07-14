from flask import Flask, request, jsonify
from flask_cors import CORS
import oracledb
from datetime import datetime
import traceback

app = Flask(__name__)
CORS(app)

# Configuración de Oracle (Docker)
ORACLE_CONFIG = {
    'user': 'system',
    'password': 'datosSISCEC',
    'dsn': 'localhost:1521/XE'
}

def get_oracle_connection():
    """Conectar a Oracle XE sin Instant Client"""
    try:
        print("Conectando a Oracle XE en Docker...")
        

        connection = oracledb.connect(
            user=ORACLE_CONFIG['user'],
            password=ORACLE_CONFIG['password'],
            dsn=ORACLE_CONFIG['dsn']
        )
        
        print("Conectado a Oracle XE exitosamente")
        return connection
    except Exception as e:
        print(f"Error conectando a Oracle: {e}")
        return None


@app.route('/health')
def health():
    try:
        conn = get_oracle_connection()
        if conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 'Oracle OK' FROM DUAL")
            result = cursor.fetchone()
            cursor.close()
            conn.close()
            
            return jsonify({
                "status": "OK",
                "oracle_xe": "Conectado",
                "database": "Oracle XE 21c",
                "docker": "Funcionando"
            })
        else:
            return jsonify({
                "status": "ERROR",
                "oracle_xe": "No disponible",
                "docker": "Verificar contenedor"
            }), 500
    except Exception as e:
        return jsonify({
            "status": "ERROR",
            "error": str(e)
        }), 500

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        print(f"Intento de login...")
        print(f"Usuario: {username}")
        
        conn = get_oracle_connection()
        if not conn:
            return jsonify({
                "exito": False,
                "mensaje": "Error de conexión a base de datos"
            }), 500
        
        cursor = conn.cursor()
        
        # Buscar usuario en Oracle
        cursor.execute("""
            SELECT u.ID_Usuario, u.Nombre_usuario, u.Rol, p.ID_Paciente, p.Nombres, p.Apellidos
            FROM Usuario_Sistema u
            LEFT JOIN Paciente p ON u.ID_Usuario = p.ID_Usuario
            WHERE u.Nombre_usuario = :username AND u.Contraseña = :password
        """, username=username, password=password)
        
        user = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if user:
            print("Login exitoso")
            return jsonify({
                "exito": True,
                "mensaje": "Login exitoso",
                "usuario": {
                    "id_usuario": user[0],
                    "username": user[1],
                    "rol": user[2],
                    "id_paciente": user[3],
                    "nombres": user[4],
                    "apellidos": user[5]
                }
            })
        else:
            print("Credenciales incorrectas")
            return jsonify({
                "exito": False,
                "mensaje": "Usuario o contraseña incorrectos"
            }), 401
            
    except Exception as e:
        print(f"Error en login: {str(e)}")
        traceback.print_exc()
        return jsonify({
            "exito": False,
            "mensaje": f"Error interno: {str(e)}"
        }), 500

@app.route('/signos/<int:patient_id>', methods=['POST'])
def registrar_signos(patient_id):
    try:
        data = request.get_json()
        presion = data.get('presion')
        glucosa = float(data.get('glucosa'))
        frecuencia = int(data.get('frecuencia'))
        temperatura = float(data.get('temperatura'))
        
        print(f"Registrando signos vitales para paciente {patient_id}")
        
        conn = get_oracle_connection()
        if not conn:
            return jsonify({
                "exito": False,
                "mensaje": "Error de conexión a base de datos"
            }), 500
        
        cursor = conn.cursor()
        
        # Llamar al procedimiento almacenado
        cursor.callproc('SP_Registrar_Signos', [patient_id, presion, glucosa, frecuencia, temperatura])
        
        cursor.close()
        conn.close()
        
        print("Signos vitales registrados exitosamente")
        
        return jsonify({
            "exito": True,
            "mensaje": "Signos vitales registrados correctamente",
            "alertas_generadas": True,
            "procedimiento": "SP_Registrar_Signos ejecutado"
        })
        
    except Exception as e:
        print(f"Error registrando signos: {str(e)}")
        traceback.print_exc()
        return jsonify({
            "exito": False,
            "mensaje": f"Error: {str(e)}"
        }), 500

@app.route('/alertas/<int:patient_id>')
def get_alertas(patient_id):
    try:
        conn = get_oracle_connection()
        if not conn:
            return jsonify({"alertas": []})
        
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT ID_Alerta, Tipo, Mensaje, Fecha_emision, Estado
            FROM Alerta
            WHERE ID_Paciente = :patient_id
            ORDER BY Fecha_emision DESC
        """, patient_id=patient_id)
        
        alertas = []
        for row in cursor.fetchall():
            alertas.append({
                "id_alerta": row[0],
                "tipo": row[1],
                "mensaje": row[2],
                "fecha_emision": row[3].isoformat() if row[3] else None,
                "estado": row[4]
            })
        
        cursor.close()
        conn.close()
        
        print(f"{len(alertas)} alertas obtenidas para paciente {patient_id}")
        return jsonify({"alertas": alertas})
        
    except Exception as e:
        print(f" Error obteniendo alertas: {str(e)}")
        return jsonify({"alertas": []})

@app.route('/dashboard/<int:patient_id>')
def get_dashboard(patient_id):
    try:
        conn = get_oracle_connection()
        if not conn:
            return jsonify({"dashboard": None})
        
        cursor = conn.cursor()
        
        # Contar alertas activas usando función
        cursor.execute("SELECT FN_Contar_Alertas(:patient_id) FROM DUAL", patient_id=patient_id)
        alertas_activas = cursor.fetchone()[0]
        
        # Último registro de signos vitales
        cursor.execute("""
            SELECT Fecha FROM Signos_vitales 
            WHERE ID_Paciente = :patient_id 
            ORDER BY Fecha DESC 
            FETCH FIRST 1 ROWS ONLY
        """, patient_id=patient_id)
        
        ultimo_signos = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        dashboard = {
            "alertas_activas": alertas_activas or 0,
            "ultimo_signos": {
                "fecha": ultimo_signos[0].isoformat() if ultimo_signos and ultimo_signos[0] else None
            },
            "proxima_cita": None  # Por implementar
        }
        
        return jsonify({"dashboard": dashboard})
        
    except Exception as e:
        print(f"Error obteniendo dashboard: {str(e)}")
        return jsonify({"dashboard": None})
    

    

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)