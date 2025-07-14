-- 1. CREAR TABLAS
CREATE TABLE Usuario_Sistema (
    ID_Usuario NUMBER PRIMARY KEY,
    Nombre_usuario VARCHAR2(50) UNIQUE NOT NULL,
    Contraseña VARCHAR2(100) NOT NULL,
    Rol VARCHAR2(20) CHECK (Rol IN ('PACIENTE', 'MEDICO', 'ADMIN')) NOT NULL,
    Fecha_creacion DATE DEFAULT SYSDATE
);

CREATE TABLE Paciente (
    ID_Paciente NUMBER PRIMARY KEY,
    ID_Usuario NUMBER REFERENCES Usuario_Sistema(ID_Usuario),
    DNI VARCHAR2(20) UNIQUE NOT NULL,
    Nombres VARCHAR2(100) NOT NULL,
    Apellidos VARCHAR2(100) NOT NULL,
    Fecha_nacimiento DATE NOT NULL,
    Sexo CHAR(1) CHECK (Sexo IN ('M', 'F')) NOT NULL,
    Telefono VARCHAR2(20),
    Correo_electronico VARCHAR2(100),
    Direccion VARCHAR2(200)
);

CREATE TABLE Medico (
    ID_Medico NUMBER PRIMARY KEY,
    ID_Usuario NUMBER REFERENCES Usuario_Sistema(ID_Usuario),
    DNI VARCHAR2(20) UNIQUE NOT NULL,
    Nombres VARCHAR2(100) NOT NULL,
    Apellidos VARCHAR2(100) NOT NULL,
    Especialidad VARCHAR2(100) NOT NULL,
    Telefono VARCHAR2(20),
    Correo_electronico VARCHAR2(100)
);

CREATE TABLE Signos_vitales (
    ID_Registro NUMBER PRIMARY KEY,
    ID_Paciente NUMBER REFERENCES Paciente(ID_Paciente) NOT NULL,
    Fecha DATE DEFAULT SYSDATE,
    Presion_arterial VARCHAR2(20),
    Nivel_glucosa NUMBER(5,2),
    Frecuencia_cardiaca NUMBER(3),
    Temperatura NUMBER(4,2)
);

CREATE TABLE Alerta (
    ID_Alerta NUMBER PRIMARY KEY,
    ID_Paciente NUMBER REFERENCES Paciente(ID_Paciente) NOT NULL,
    Fecha_emision DATE DEFAULT SYSDATE,
    Tipo VARCHAR2(20) CHECK (Tipo IN ('CRITICA', 'ADVERTENCIA', 'RECORDATORIO')) NOT NULL,
    Mensaje VARCHAR2(500) NOT NULL,
    Estado VARCHAR2(10) DEFAULT 'ACTIVA' CHECK (Estado IN ('ACTIVA', 'RESUELTA'))
);

CREATE TABLE Cita (
    ID_Cita NUMBER PRIMARY KEY,
    ID_Paciente NUMBER REFERENCES Paciente(ID_Paciente) NOT NULL,
    ID_Medico NUMBER REFERENCES Medico(ID_Medico) NOT NULL,
    Fecha DATE NOT NULL,
    Hora VARCHAR2(10) NOT NULL,
    Estado VARCHAR2(20) DEFAULT 'PROGRAMADA' CHECK (Estado IN ('PROGRAMADA', 'COMPLETADA', 'CANCELADA'))
);

CREATE TABLE Examen_laboratorio (
    ID_Examen NUMBER PRIMARY KEY,
    ID_Paciente NUMBER REFERENCES Paciente(ID_Paciente) NOT NULL,
    Tipo_examen VARCHAR2(100) NOT NULL,
    Fecha_examen DATE DEFAULT SYSDATE,
    Resultados CLOB,
    Estado VARCHAR2(20) DEFAULT 'PENDIENTE'
);

-- 2. FUNCIONES SIMPLES
CREATE OR REPLACE FUNCTION FN_Calcular_Edad(p_fecha_nacimiento DATE)
RETURN NUMBER
IS
BEGIN
    RETURN TRUNC(MONTHS_BETWEEN(SYSDATE, p_fecha_nacimiento) / 12);
END;
/

CREATE OR REPLACE FUNCTION FN_Contar_Alertas(p_id_paciente NUMBER)
RETURN NUMBER
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM Alerta
    WHERE ID_Paciente = p_id_paciente AND Estado = 'ACTIVA';
    RETURN v_count;
END;
/

CREATE OR REPLACE FUNCTION FN_Ultimo_Examen(p_id_paciente NUMBER)
RETURN VARCHAR2
IS
    v_ultimo VARCHAR2(200);
BEGIN
    SELECT Tipo_examen INTO v_ultimo
    FROM (
        SELECT Tipo_examen
        FROM Examen_laboratorio
        WHERE ID_Paciente = p_id_paciente
        ORDER BY Fecha_examen DESC
    )
    WHERE ROWNUM = 1;
    RETURN v_ultimo;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'Sin exámenes';
END;
/

-- 3. PROCEDIMIENTO PRINCIPAL
CREATE OR REPLACE PROCEDURE SP_Registrar_Signos(
    p_id_paciente IN NUMBER,
    p_presion IN VARCHAR2,
    p_glucosa IN NUMBER,
    p_frecuencia IN NUMBER,
    p_temperatura IN NUMBER
)
IS
BEGIN
    -- Insertar signos vitales
    INSERT INTO Signos_vitales (
        ID_Registro, ID_Paciente, Presion_arterial, 
        Nivel_glucosa, Frecuencia_cardiaca, Temperatura
    ) VALUES (
        (SELECT NVL(MAX(ID_Registro), 0) + 1 FROM Signos_vitales),
        p_id_paciente, p_presion, p_glucosa, p_frecuencia, p_temperatura
    );
    
    -- Alertas automáticas
    IF p_glucosa > 140 THEN
        INSERT INTO Alerta (ID_Alerta, ID_Paciente, Tipo, Mensaje)
        VALUES (
            (SELECT NVL(MAX(ID_Alerta), 0) + 1 FROM Alerta),
            p_id_paciente, 
            'ADVERTENCIA', 
            'Nivel de glucosa elevado: ' || p_glucosa || ' mg/dL'
        );
    END IF;
    
    IF p_glucosa < 70 THEN
        INSERT INTO Alerta (ID_Alerta, ID_Paciente, Tipo, Mensaje)
        VALUES (
            (SELECT NVL(MAX(ID_Alerta), 0) + 1 FROM Alerta),
            p_id_paciente, 
            'CRITICA', 
            'Nivel de glucosa bajo: ' || p_glucosa || ' mg/dL'
        );
    END IF;
    
    IF p_frecuencia > 100 THEN
        INSERT INTO Alerta (ID_Alerta, ID_Paciente, Tipo, Mensaje)
        VALUES (
            (SELECT NVL(MAX(ID_Alerta), 0) + 1 FROM Alerta),
            p_id_paciente, 
            'ADVERTENCIA', 
            'Frecuencia cardíaca elevada: ' || p_frecuencia || ' bpm'
        );
    END IF;
    
    IF p_temperatura > 37.5 THEN
        INSERT INTO Alerta (ID_Alerta, ID_Paciente, Tipo, Mensaje)
        VALUES (
            (SELECT NVL(MAX(ID_Alerta), 0) + 1 FROM Alerta),
            p_id_paciente, 
            'ADVERTENCIA', 
            'Temperatura elevada: ' || p_temperatura || '°C'
        );
    END IF;
    
    COMMIT;
END;
/

-- 4. PROCEDIMIENTO PARA CREAR CITAS
CREATE OR REPLACE PROCEDURE SP_Crear_Cita(
    p_id_paciente IN NUMBER,
    p_id_medico IN NUMBER,
    p_fecha IN DATE,
    p_hora IN VARCHAR2
)
IS
BEGIN
    INSERT INTO Cita (ID_Cita, ID_Paciente, ID_Medico, Fecha, Hora)
    VALUES (
        (SELECT NVL(MAX(ID_Cita), 0) + 1 FROM Cita),
        p_id_paciente, p_id_medico, p_fecha, p_hora
    );
    COMMIT;
END;
/

-- T. Trigger
CREATE OR REPLACE TRIGGER TRG_Paciente_Capitalizar
BEFORE INSERT ON Paciente
FOR EACH ROW
BEGIN
    :new.Nombres := INITCAP(:new.Nombres);
    :new.Apellidos := INITCAP(:new.Apellidos);
END;
/


INSERT INTO Usuario_Sistema VALUES (1, 'admin', 'admin123', 'ADMIN', SYSDATE);
INSERT INTO Usuario_Sistema VALUES (2, 'dr.martinez', 'medico123', 'MEDICO', SYSDATE);
INSERT INTO Usuario_Sistema VALUES (3, 'maria.p', 'paciente123', 'PACIENTE', SYSDATE);
INSERT INTO Usuario_Sistema VALUES (4, 'juan.g', 'paciente123', 'PACIENTE', SYSDATE);
INSERT INTO Usuario_Sistema VALUES (5, 'dr.lopez', 'medico456', 'MEDICO', SYSDATE);
INSERT INTO Usuario_Sistema VALUES (6, 'lucia.r', 'paciente456', 'PACIENTE', SYSDATE);
INSERT INTO Usuario_Sistema VALUES (7, 'pedro.s', 'paciente789', 'PACIENTE', SYSDATE);
INSERT INTO Usuario_Sistema VALUES (8, 'ana.v', 'paciente101', 'PACIENTE', SYSDATE);

INSERT INTO Medico VALUES (1, 2, '12345678', 'Carlos', 'Martínez', 'Cardiología', '555-0001', 'dr.martinez@hospital.com');
INSERT INTO Medico VALUES (2, 5, '87654321', 'Ana', 'López', 'Dermatología', '555-0004', 'dra.lopez@hospital.com');

INSERT INTO Paciente VALUES (1, 3, '87654321', 'María', 'Pérez', DATE '1985-03-15', 'F', '555-0002', 'maria.perez@email.com', 'Av. Principal 123');
INSERT INTO Paciente VALUES (2, 4, '11223344', 'Juan', 'González', DATE '1978-08-22', 'M', '555-0003', 'juan.gonzalez@email.com', 'Calle Secundaria 456');
INSERT INTO Paciente VALUES (3, 6, '22334455', 'Lucía', 'Ramos', DATE '1992-11-30', 'F', '555-0005', 'lucia.ramos@email.com', 'Av. del Sol 789');
INSERT INTO Paciente VALUES (4, 7, '33445566', 'Pedro', 'Soto', DATE '1965-01-20', 'M', '555-0006', 'pedro.soto@email.com', 'Jr. de la Luna 101');
INSERT INTO Paciente VALUES (5, 8, '44556677', 'Ana', 'Vega', DATE '2001-06-10', 'F', '555-0007', 'ana.vega@email.com', 'Calle Estrellas 202');


INSERT INTO Signos_vitales VALUES (1, 1, SYSDATE, '120/80', 95, 72, 36.5);
INSERT INTO Signos_vitales VALUES (2, 1, SYSDATE-1, '130/85', 110, 78, 36.8);
INSERT INTO Signos_vitales VALUES (3, 1, SYSDATE-2, '140/90', 180, 95, 38.0);
INSERT INTO Signos_vitales VALUES (4, 2, SYSDATE, '110/70', 85, 68, 36.7);
INSERT INTO Signos_vitales VALUES (5, 3, SYSDATE, '125/80', 105, 75, 37.0);

INSERT INTO Alerta VALUES (1, 1, SYSDATE, 'RECORDATORIO', 'Recordatorio: Tomar medicamento', 'ACTIVA');
INSERT INTO Alerta VALUES (2, 2, SYSDATE, 'ADVERTENCIA', 'Revisar niveles de glucosa', 'ACTIVA');

INSERT INTO Cita VALUES (1, 1, 1, DATE '2025-07-20', '10:00', 'PROGRAMADA');
INSERT INTO Cita VALUES (2, 2, 1, DATE '2025-07-25', '14:30', 'PROGRAMADA');
INSERT INTO Cita VALUES (4, 3, 2, SYSDATE + 15, '16:00', 'PROGRAMADA');
INSERT INTO Cita VALUES (5, 1, 1, SYSDATE + 5, '11:30', 'PROGRAMADA');

INSERT INTO Examen_laboratorio VALUES (1, 1, 'Hemograma', SYSDATE-7, 'Valores normales', 'COMPLETADO');
INSERT INTO Examen_laboratorio VALUES (2, 2, 'Perfil lipídico', SYSDATE, NULL, 'PENDIENTE');
INSERT INTO Examen_laboratorio VALUES (3, 1, 'Colesterol Total', SYSDATE-1, '220 mg/dL', 'COMPLETADO');
INSERT INTO Examen_laboratorio VALUES (4, 3, 'Glucosa en Ayunas', SYSDATE, NULL, 'PENDIENTE');




INSERT INTO Paciente (ID_Paciente, ID_Usuario, DNI, Nombres, Apellidos, Fecha_nacimiento, Sexo)
VALUES (901, 3, '11112222', 'pedro', 'castillo', DATE '1988-05-10', 'M');

SELECT Nombres, Apellidos FROM Paciente WHERE ID_Paciente = 901;


COMMIT;





