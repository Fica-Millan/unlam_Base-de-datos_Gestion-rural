/*
Trabajo Practico Integrador - Parte II - 2025
Integrantes: Fica Millan, Yesica 
             Petraroia, Franco 
             Miranda Charca, Florencia 
Grupo: VI
Fecha de entrega: 28/08/2025
*/

-------------------------------------------------------------------------------
--- C R E A C I O N   B A S E   D E   D A T O S    
-------------------------------------------------------------------------------
CREATE DATABASE GRUPOVI;
GO

USE GRUPOVI;
GO


-------------------------------------------------------------------------------
-- C R E A C I O N   E S Q U E M A S 
-------------------------------------------------------------------------------
CREATE SCHEMA produccion;
GO

CREATE SCHEMA rrhh;
GO

CREATE SCHEMA gestion;
GO

-------------------------------------------------------------------------------
-- C R E A C I O N   T A B L A S   E S Q U E M A   P R O D U C C I O N   
-------------------------------------------------------------------------------

/***************************
 T A B L A   A N I M A L  
 **************************/

CREATE TABLE produccion.Animal (
    id_animal INT PRIMARY KEY,                                              -- Identificador unico del animal (caravana fisica)
    raza VARCHAR(45) NOT NULL,
    sexo CHAR(1) NOT NULL CHECK (sexo IN ('M','H')),                        -- restriccion que sea M, de macho o H, de hembra
    fecha_nacimiento DATE NOT NULL,
    peso_nacimiento DECIMAL(5,2) NULL CHECK (peso_nacimiento > 0),          -- restriccion el peso no puede ser menor a cero
    id_madre INT NULL,                                                      -- Referencia a la madre, puede ser NULL si no se conoce
    categoria VARCHAR(45) NOT NULL,
    estado VARCHAR(45) NULL DEFAULT 'Activo',                               -- valor por defecto, ya que de momento que se carga en la BD ya se encuentra activo
    CONSTRAINT FK_Animal_Madre FOREIGN KEY (id_madre) REFERENCES produccion.Animal(id_animal) -- FK autorreferencial para madre
);
GO

-- Nota: el atributo "edad" no se almacena en la tabla, se calcula en consultas a partir de fecha_nacimiento.

-- indices para acelerar consultas por categoria
CREATE NONCLUSTERED INDEX IX_Animal_categoria 
ON produccion.Animal(categoria); 

-- indice combinado para acelerar consultas por sexo y estado
CREATE NONCLUSTERED INDEX IX_Animal_sexo_estado
ON produccion.Animal(sexo, estado);


/*******************************
 T A B L A   N A C I M I E N T O  
 ******************************/

CREATE TABLE produccion.Nacimiento (
    nro_nacimiento INT NOT NULL CHECK (nro_nacimiento BETWEEN 1 AND 15),    -- Numero de parto de la madre, maximo 15 pariciones
    madre_id INT NOT NULL,                                                  -- FK al animal madre
    fecha DATE DEFAULT GETDATE(),                                           -- Fecha del nacimiento, por defecto la fecha actual
    tipo_parto VARCHAR(20) NOT NULL 
        CHECK (tipo_parto IN ('Normal', 'Cesarea', 'Asistido', 'Aborto', 'No presenta ternero')), -- Tipo de parto, solo permite estos valores
    CONSTRAINT PK_Nacimiento PRIMARY KEY (madre_id, nro_nacimiento),        -- Clave primaria compuesta por madre y nro de nacimiento
    CONSTRAINT FK_Nacimiento_Madre FOREIGN KEY (madre_id) REFERENCES produccion.Animal(id_animal) -- FK hacia tabla Animal
);
GO

-- indices para consultas rapidas por madre
CREATE NONCLUSTERED INDEX IX_Nacimiento_madre 
ON produccion.Nacimiento(madre_id);

-- indice combinado para filtrado por fecha y tipo de parto
CREATE NONCLUSTERED INDEX IX_Nacimiento_fecha_tipo 
ON produccion.Nacimiento(fecha, tipo_parto);


/***************************
 T A B L A   P E S O   
 **************************/

CREATE TABLE produccion.Peso (
    fecha_medicion DATE DEFAULT GETDATE(),                                  -- Fecha de la medicion, por defecto hoy
    id_animal INT NOT NULL,                                                 -- FK al animal correspondiente
    valor DECIMAL(5,2) NOT NULL CHECK (valor > 0),                          -- Valor del peso, debe ser positivo
    CONSTRAINT PK_Peso PRIMARY KEY (fecha_medicion, id_animal),             -- Clave primaria compuesta por fecha y animal
    CONSTRAINT FK_Peso_Animal FOREIGN KEY (id_animal) REFERENCES produccion.Animal(id_animal) -- FK hacia tabla Animal
);
GO

-- indice combinado para consultar el peso historico de un animal especifico
CREATE NONCLUSTERED INDEX IX_Peso_animal_fecha
ON produccion.Peso(id_animal, fecha_medicion);

-- indice de cobertura para consultas frecuentes de Peso
CREATE NONCLUSTERED INDEX IX_Peso_Consulta_Cover
ON produccion.Peso(id_animal)
INCLUDE (fecha_medicion, valor);


/***************************
 T A B L A   P O T R E R O  
 **************************/

CREATE TABLE produccion.Potrero (
    id_potrero INT IDENTITY(1,1) PRIMARY KEY,                               -- Identificador unico, auto-incremental
    superficie DECIMAL(6,2) NOT NULL CHECK (superficie > 0),                -- Superficie del potrero, debe ser positiva
    tipo VARCHAR(100) NOT NULL,                                             -- Tipo de potrero (ej: pastura, engorde, reserva, corrales, etc.)
);
GO

-- indice para consultas rapidas por tipo de potrero
CREATE NONCLUSTERED INDEX IX_Potrero_tipo 
ON produccion.Potrero(tipo);

-- indice de cobertura para filtrado por superficie 
CREATE NONCLUSTERED INDEX IX_Potrero_superficie 
ON produccion.Potrero(superficie); 


/***************************************
 T A B L A   A N I M A L _ P O T R E R O  
 **************************************/

CREATE TABLE produccion.Animal_Potrero (
    fecha_asignacion DATE DEFAULT GETDATE(),                                -- Fecha de asignacion del animal al potrero, por defecto hoy
    id_animal INT NOT NULL,                                                 -- FK al animal
    id_potrero INT NOT NULL,                                                -- FK al potrero
    CONSTRAINT PK_Animal_Potrero PRIMARY KEY (fecha_asignacion, id_animal, id_potrero),                     -- Clave primaria compuesta para asegurar unicidad
    CONSTRAINT FK_AnimalPotrero_Animal FOREIGN KEY (id_animal) REFERENCES produccion.Animal(id_animal),     -- FK hacia Animal
    CONSTRAINT FK_AnimalPotrero_Potrero FOREIGN KEY (id_potrero) REFERENCES produccion.Potrero(id_potrero), -- FK hacia Potrero
    CONSTRAINT CHK_Fecha_Asignacion CHECK (fecha_asignacion <= GETDATE())                                   -- la fecha no puede ser futura
);
GO

-- indice para acelerar consultas por animal
CREATE NONCLUSTERED INDEX IX_AnimalPotrero_id_animal 
ON produccion.Animal_Potrero(id_animal);

-- indice para acelerar consultas por potrero
CREATE NONCLUSTERED INDEX IX_AnimalPotrero_id_potrero 
ON produccion.Animal_Potrero(id_potrero);


/***************************
 T A B L A   E V E N T O  
 **************************/

CREATE TABLE produccion.Evento (
    id_evento INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,                      -- Identificador uico auto-incremental, PK clustered
    tipo_evento VARCHAR(100) NOT NULL DEFAULT 'General',                    -- Tipo de evento, valor por defecto 'General'
    fecha DATE DEFAULT GETDATE(),                                           -- Fecha del evento, por defecto hoy
    observaciones VARCHAR(300) NOT NULL                                     -- Observaciones o detalles del evento
);
GO

-- indice combinado para filtrar por tipo de evento y fecha
CREATE NONCLUSTERED INDEX IX_Evento_tipo_fecha 
ON produccion.Evento(tipo_evento, fecha);

-------------------------------------------------------------------------------
-- C R E A C I O N   T A B L A S   E S Q U E M A   R R H H     
-------------------------------------------------------------------------------

/***************************
 T A B L A   P E R S O N A L  
 **************************/

CREATE TABLE rrhh.Personal (
    id_personal INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,                    -- Identificador unico auto-incremental, PK clustered
    nombre VARCHAR(50) NOT NULL,                                            -- Nombre del empleado, obligatorio
    apellido VARCHAR(50) NOT NULL,                                          -- Apellido del empleado, obligatorio
    contacto_emerg VARCHAR(80) NOT NULL,                                    -- Contacto de emergencia, obligatorio
    celular VARCHAR(18) NOT NULL,                                           -- Numero de celular, obligatorio
    CONSTRAINT CHK_Celular CHECK (LEN(celular) >= 8)                        -- Validacion: manimo 8 caracteres para celular
);
GO

-- indice combinado para busquedas rapidas por nombre y apellido
CREATE NONCLUSTERED INDEX IX_Personal_NombreApellido 
ON rrhh.Personal(nombre, apellido);

/***************************
 T A B L A   P E O N  
 **************************/

CREATE TABLE rrhh.Peon (
    id_personal INT PRIMARY KEY CLUSTERED,                                  -- ID del personal, PK clustered, vinculado a Personal
    sector_asignado VARCHAR(50) NULL,                                       -- Sector donde trabaja el peon, opcional
    turno VARCHAR(20) NULL,                                                 -- Turno asignado, puede ser NULL    
    CONSTRAINT FK_Peon_Personal FOREIGN KEY (id_personal)   
        REFERENCES rrhh.Personal(id_personal)
        ON DELETE CASCADE,                                                  -- Si se elimina un registro de Personal, automáticamente se eliminan aqui
    CONSTRAINT CHK_Turno CHECK (turno IN ('Mañana','Tarde','Noche') OR turno IS NULL) -- Valida que el turno sea uno de los permitidos o NULL
);
GO

-- indice para consultas por sector asignado
CREATE NONCLUSTERED INDEX IX_Peon_Sector
ON rrhh.Peon(sector_asignado);


/***************************
 T A B L A   C A P A T A Z  
 **************************/

CREATE TABLE rrhh.Capataz (
    id_personal INT PRIMARY KEY CLUSTERED,                                  -- ID del personal, PK clustered, vinculado a Personal
    anios_experiencia INT NULL,                                             -- Años de experiencia del capataz, opcional

    -- Restricciones
    CONSTRAINT FK_capataz_personal
        FOREIGN KEY (id_personal)
        REFERENCES rrhh.Personal (id_personal)
        ON DELETE CASCADE                                                   -- Si se elimina un registro de Personal, automáticamente se eliminan aqui
);

-- indice para consultas rapidas por años de experiencia
CREATE NONCLUSTERED INDEX IX_Capataz_Experiencia
ON rrhh.Capataz (anios_experiencia);


/*********************************
 T A B L A   T R A C T O R I S T A  
 ********************************/

CREATE TABLE rrhh.Tractorista (
    id_personal INT NOT NULL PRIMARY KEY CLUSTERED,                         -- ID del personal, PK clustered, vinculado a Personal
    licencia_nro VARCHAR(45) NOT NULL,                                      -- Numero de licencia del tractorista, obligatorio
    tipo_maquinaria VARCHAR(100) NOT NULL,                                  -- Descripcion del tipo de maquinaria que opera
    CONSTRAINT FK_Tractorista_Personal FOREIGN KEY (id_personal)
        REFERENCES rrhh.personal (id_personal)
        ON DELETE CASCADE,                                                  -- Si se elimina un registro de Personal, automáticamente se eliminan aqui
    CONSTRAINT UQ_Tractorista_Licencia UNIQUE (licencia_nro),               -- Restriccion de unicidad: cada licencia debe ser unica  
    CONSTRAINT CK_Tractorista_Licencia CHECK (LEN(licencia_nro) >= 8)       -- Restriccion de validacion: licencia con manimo 8 caracteres
);
GO

-- indice para busquedas por tipo de maquinaria
CREATE NONCLUSTERED INDEX IX_Tractorista_Tipo_Maquinaria
ON rrhh.Tractorista (tipo_maquinaria);
GO


/*******************************
 T A B L A   E N C A R G A D O  
 ******************************/

CREATE TABLE rrhh.Encargado (
    id_personal INT NOT NULL PRIMARY KEY CLUSTERED,                         -- ID del personal, PK clustered, vinculado a Personal
    ppto_asignado DECIMAL(10,2) NULL,                                       -- Presupuesto asignado, puede ser NULL
    cant_personal INT NOT NULL,                                             -- Cantidad de personal a cargo, obligatorio
    CONSTRAINT FK_Encargado_Personal FOREIGN KEY (id_personal)
        REFERENCES rrhh.personal (id_personal)
        ON DELETE CASCADE,                                                  -- Si se elimina un registro de Personal, automáticamente se eliminan aqui
    CONSTRAINT CK_Encargado_Cant_Personal 
    CHECK (cant_personal >= 0),                                             -- Cantidad de personal no puede ser negativa
    CONSTRAINT CK_Encargado_Ppto_Asignado 
    CHECK (ppto_asignado IS NULL OR ppto_asignado >= 0)                     -- Presupuesto debe ser positivo o NULL
);
GO

-- indice para consultar por cantidad de presupuesto
CREATE NONCLUSTERED INDEX IX_Encargado_Ppto_Asignado 
ON rrhh.Encargado (ppto_asignado);
GO


/**********************************
 T A B L A   V E T E R I N A R I O  
 *********************************/

 CREATE TABLE rrhh.Veterinario (
    id_personal INT PRIMARY KEY CLUSTERED,                                  -- ID del personal, PK clustered, vinculado a Personal
    mat_profesional VARCHAR(60) NOT NULL,                                   -- Matricula profesional del veterinario
    especialidad VARCHAR(60) NOT NULL,                                      -- Especialidad veterinaria
    CONSTRAINT FK_Veterinario_Personal                                      -- FK hacia Personal
        FOREIGN KEY (id_personal)
        REFERENCES rrhh.Personal(id_personal)
        ON DELETE CASCADE,                                                  -- Si se elimina un registro de Personal, automáticamente se eliminan aqui
    CONSTRAINT UQ_Veterinario_Matricula UNIQUE(mat_profesional)             -- Matricula unica por veterinario
);
GO

-- indice nonclustered para buscar por especialidad
CREATE NONCLUSTERED INDEX IX_Veterinario_Especialidad
ON rrhh.Veterinario (especialidad);

-------------------------------------------------------------------------------
-- C R E A C I O N   T A B L A S   E S Q U E M A   G E S T I O N   
-------------------------------------------------------------------------------

/*******************************************************
 T A B L A   A N I M A L _ P E R S O N A L _ E V E N T O  
 ******************************************************/

CREATE TABLE gestion.Animal_Personal_Evento (
    id_animal INT NOT NULL,                                                 -- FK al animal involucrado
    id_personal INT NOT NULL,                                               -- FK al personal involucrado
    id_evento INT NOT NULL,                                                 -- FK al evento
    rol_evento VARCHAR(50) NOT NULL,                                        -- Rol del personal en el evento
    CONSTRAINT PK_Animal_Personal_Evento PRIMARY KEY CLUSTERED (id_animal, id_personal, id_evento),  -- PK compuesta para asegurar unicidad
    
    CONSTRAINT FK_APE_Animal FOREIGN KEY (id_animal)
        REFERENCES produccion.Animal(id_animal)
        ON DELETE NO ACTION,                                                -- Mantener integridad referencial con Animal
        
    CONSTRAINT FK_APE_Personal FOREIGN KEY (id_personal)
        REFERENCES rrhh.Personal(id_personal)
        ON DELETE NO ACTION,                                                -- Mantener integridad referencial con Personal
        
    CONSTRAINT FK_APE_Evento FOREIGN KEY (id_evento)
        REFERENCES produccion.Evento(id_evento)
        ON DELETE NO ACTION                                                 -- Mantener integridad referencial con Evento
);
GO

-- indice para consultas por evento
CREATE NONCLUSTERED INDEX IX_APE_id_evento
ON gestion.Animal_Personal_Evento(id_evento);

-- indice de cobertura para consultas frecuentes combinando personal y evento
CREATE NONCLUSTERED INDEX IX_APE_Personal_Evento_Cover
ON gestion.Animal_Personal_Evento(id_personal, id_evento)
INCLUDE (id_animal, rol_evento);
GO

/*******************************************************
 T A B L A   P O T R E R O _ E V E N T O  
 ******************************************************/

 CREATE TABLE gestion.Potrero_Evento (
    id_potrero INT NOT NULL,                                                -- FK al potrero involucrado
    id_evento INT NOT NULL,                                                 -- FK al evento
    CONSTRAINT PK_Potrero_Evento PRIMARY KEY CLUSTERED (id_potrero, id_evento), -- PK compuesta asegura unicidad potrero-evento
    
    CONSTRAINT FK_PE_Potrero FOREIGN KEY (id_potrero)
        REFERENCES produccion.Potrero(id_potrero)
        ON DELETE NO ACTION,                                                -- Mantiene integridad con Potrero
        
    CONSTRAINT FK_PE_Evento FOREIGN KEY (id_evento)
        REFERENCES produccion.Evento(id_evento)
        ON DELETE NO ACTION                                                 -- Mantiene integridad con Evento
);
GO

-- indice para consultas frecuentes por evento
CREATE NONCLUSTERED INDEX IX_PE_id_evento
ON gestion.Potrero_Evento(id_evento);

-- indice combinando de potrero y evento
CREATE NONCLUSTERED INDEX IX_PE_Potrero_Evento
ON gestion.Potrero_Evento(id_evento, id_potrero)
GO

-------------------------------------------------------------------------------
-- M O D I F I C A C I O N E S   A   T A B L A S   E X I S T E N T E S    
-------------------------------------------------------------------------------

-- Validar que el celular tenga solo digitos y 8 a 18 caracteres
ALTER TABLE rrhh.Personal
ADD CONSTRAINT CHK_CelularFormatoCompleto CHECK (celular NOT LIKE '%[^0-9]%' AND LEN(celular) BETWEEN 8 AND 18);

-- Evitar duplicados de numero de celular
ALTER TABLE rrhh.Personal
ADD CONSTRAINT UQ_Personal_Celular UNIQUE (celular); 

-- Evitar valores negativos en años de experiencia
ALTER TABLE rrhh.capataz
ADD CONSTRAINT CHK_Experiencia CHECK (anios_experiencia >= 0);

-- Agregar una nueva columna "correo" a la tabla Personal
ALTER TABLE rrhh.Personal
ADD correo VARCHAR(30) NULL;

-- Eliminar la columna "correo" de la tabla Personal
ALTER TABLE rrhh.Personal
DROP COLUMN correo;


-------------------------------------------------------------------------------
-- ELIMINACIÓN DE OBJETOS
-------------------------------------------------------------------------------
-- Crear índice IX_Peso_fecha_valor sobre fecha_medicion y valor
CREATE NONCLUSTERED INDEX IX_Peso_fecha_valor
ON produccion.Peso(fecha_medicion, valor);
GO

-- Eliminar indice de la tabla Peso
DROP INDEX IX_Peso_fecha_valor ON produccion.Peso;

-- Eliminación de los datos de la tabla Peso
TRUNCATE TABLE produccion.Peso;

-------------------------------------------------------------------------------
-- ESTRUCTURAS TEMPORALES
-------------------------------------------------------------------------------

/*******************************************************
 TABLA TEMPORAL LOCAL
 ******************************************************/

-- Listado de animales pesados en la fecha de hoy 
CREATE TABLE #Pesajes_Hoy (                  
    id_animal INT,
    peso DECIMAL(5,2)
);

-- Insercion de los registros del día
INSERT INTO #Pesajes_Hoy                     
SELECT id_animal, valor
FROM produccion.Peso
WHERE fecha_medicion = CAST(GETDATE() AS DATE);

-- Consulta para control
SELECT * FROM #Pesajes_Hoy;                  


/*******************************************************
 TABLA TEMPORAL GLOBAL
 ******************************************************/

-- Creación de una tabla temporal global con el personal de peones disponibles
CREATE TABLE ##Personal_Disponible_Peon (
    id_personal INT,
    nombre VARCHAR(50),
    apellido VARCHAR(50),
    turno VARCHAR(20)
);

-- Carga del personal disponible en el turno de mañana
INSERT INTO ##Personal_Disponible_Peon       
SELECT p.id_personal, p.nombre, p.apellido, pe.turno
FROM rrhh.Personal p
JOIN rrhh.Peon pe ON p.id_personal = pe.id_personal
WHERE pe.turno = 'Mañana';

-- Consulta de control que se puede ejecutar desde cualquier sesión
SELECT * FROM ##Personal_Disponible_Peon;    


/*******************************************************
 VARIABLE DE TABLA
 ******************************************************/

-- Creación de la variable de tabla que permita guardar transitoriamente los capataces con más de 10 años de experiencia
DECLARE @CapatacesSenior TABLE (
    id_capataz INT,
    nombre VARCHAR(50),
    apellido VARCHAR(50),
    anios_experiencia INT
);

-- Inserción de los registros que cumplen la condición
INSERT INTO @CapatacesSenior                  
SELECT c.id_personal, p.nombre, p.apellido, c.anios_experiencia
FROM rrhh.Capataz c
JOIN rrhh.Personal p ON c.id_personal = p.id_personal
WHERE c.anios_experiencia >= 10;

-- Consulta de los capataces senior
SELECT * FROM @CapatacesSenior;               
