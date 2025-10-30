/*
Trabajo Practico Integrador - Parte IV - 2025
Integrantes: Fica Millan, Yesica 
             Petraroia, Franco 
             Miranda Charca, Florencia 
Grupo: VI
Fecha de entrega: 08/09/2025
*/

USE GRUPOVI;
GO


/**********************************************************************************
1. Procedimientos almacenados (Stored Procedures -SP-)
**********************************************************************************/
-----------------------------------------------------------------------------------
-- a) SP de consulta parametrizada 
-----------------------------------------------------------------------------------
-- El objetivo del procedimiento es consultar la evolución de los pesos de los animales activos
-- de una categoría y edad determinada 


-- Si ya existe un procedimiento llamado AnalisisPesoAnimal en el esquema produccion, lo elimina antes de crearlo de nuevo.
IF OBJECT_ID('produccion.sp_AnalisisPesoAnimal', 'P') IS NOT NULL
    DROP PROCEDURE produccion.sp_AnalisisPesoAnimal;
GO


-- Se crea el procedimiento 
CREATE PROCEDURE produccion.sp_AnalisisPesoAnimal
    @edad INT,                             -- Parámetro de entrada: edad para filtrar entre todos los animales
    @categoria NVARCHAR(50),               -- Parámetro de entrada: categoría del animal a filtrar (Vaquillona, Vaca o Toro)
    @Mensaje NVARCHAR(500) OUTPUT          -- Parámetro de salida: devuelve un mensaje que indica la menor variación en el peso de los animales
AS
BEGIN
    SET NOCOUNT ON;

-- Se crea una tabla temporal #Pesos: contiene todos los registros de peso de los animales, y asigna un número de fila ascendente (primer peso) y descendente (último peso)

    SELECT 
        p.id_animal,                                          
        p.fecha_medicion,                                     
        p.valor,                                              
        ROW_NUMBER() OVER (PARTITION BY p.id_animal 
                           ORDER BY p.fecha_medicion ASC) AS rn_asc,     -- Número de fila ascendente: primer registro de peso  
        ROW_NUMBER() OVER (PARTITION BY p.id_animal 
                           ORDER BY p.fecha_medicion DESC) AS rn_desc    -- Número de fila descendente: último registro de peso
    INTO #Pesos
    FROM produccion.Peso p;

-- Se crea la tabla temporal #DatosPeso con información filtrada, contiene la información de los animales filtrados por:
-- Estado = Activo
-- Edad exacta en años completos
-- Categoría
-- Calculo de la variación porcentual entre primer y último peso.
    SELECT 
        a.id_animal,                                         
        a.raza,                                              
        a.categoria,
        pri.fecha_medicion AS fecha_primer_peso,             
        pri.valor AS primer_peso,                            
        ult.fecha_medicion AS fecha_ultimo_peso,            
        ult.valor AS ultimo_peso,                            
        CAST(
            CASE WHEN pri.valor > 0 
                 THEN ((ult.valor - pri.valor) * 100.0 / pri.valor)       -- Calculamos la variación porcentual entre primer y último peso
                 ELSE NULL END
        AS DECIMAL(10,2)) AS variacion_peso
    INTO #DatosPeso
    FROM produccion.Animal a
    INNER JOIN #Pesos pri 
        ON a.id_animal = pri.id_animal AND pri.rn_asc = 1              
    INNER JOIN #Pesos ult 
        ON a.id_animal = ult.id_animal AND ult.rn_desc = 1             
    WHERE a.estado = 'Activo'                                             -- Filtramos solo animales activos 
      AND (
          CASE 
              WHEN MONTH(GETDATE()) > MONTH(a.fecha_nacimiento)
                   OR (MONTH(GETDATE()) = MONTH(a.fecha_nacimiento) 
                       AND DAY(GETDATE()) >= DAY(a.fecha_nacimiento))
              THEN DATEDIFF(YEAR, a.fecha_nacimiento, GETDATE())
              ELSE DATEDIFF(YEAR, a.fecha_nacimiento, GETDATE()) - 1
          END
      ) = @edad
      AND a.categoria = @categoria;

-- Devolución de la tabla final: muestra cada animal con su primer y último peso, variación porcentual.
    SELECT 
        d.id_animal,
        d.raza,
        d.fecha_primer_peso,
        d.primer_peso,
        d.fecha_ultimo_peso,
        d.ultimo_peso,
        d.variacion_peso
    FROM #DatosPeso d
    ORDER BY d.ultimo_peso DESC;

--  Se calcula la menor variación porcentual de peso
    DECLARE @menor_var DECIMAL(10,2);

    SELECT TOP 1 @menor_var = variacion_peso
    FROM #DatosPeso
    ORDER BY variacion_peso ASC;                             -- Para tomar la menor variación

-- Se asigna un mensaje de salida
    IF @menor_var IS NOT NULL
        SET @Mensaje = 'La menor variación en el peso es de: ' + CAST(@menor_var AS NVARCHAR(20)) + '%';
    ELSE
        SET @Mensaje = 'No se encontraron animales con los parámetros ingresados.';
END;
GO

-- Ejemplo de ejecución
DECLARE @Salida NVARCHAR(500);

EXEC produccion.sp_AnalisisPesoAnimal
     @edad = 5,                             -- Edad exacta en años completos a filtrar
     @categoria = 'Toro',                   -- Categoría a filtrar (Toro, Vaca o Vaquillona)
     @Mensaje = @Salida OUTPUT;

PRINT @Salida;


-------------------------------------------------------------------------------
-- b) SP de insercion de datos: Procedimiento produccion.InsertarAnimal
-------------------------------------------------------------------------------
-- El objetivo del procedimiento es insertar un nuevo animal en la tabla produccion.Animal, 
-- asegurando que los datos cumplan con ciertas validaciones.


-- Si ya existe un procedimiento llamado InsertarAnimal en el esquema produccion, lo elimina antes de crearlo de nuevo.
IF OBJECT_ID('produccion.InsertarAnimal', 'P') IS NOT NULL
    DROP PROCEDURE produccion.InsertarAnimal;
GO


-- Se crea el procedimiento y se definen sus parametros de entrada y salida
CREATE PROCEDURE produccion.InsertarAnimal
    @id_animal INT,                             -- identificador unico del animal
    @raza VARCHAR(45),                          -- raza del animal (obligatoria)
    @sexo CHAR(1),                              -- debe ser "M" (macho) o "H" (hembra)
    @fecha_nacimiento DATE,                     -- fecha de nacimiento (ni nula ni futura)
    @peso_nacimiento DECIMAL(5,2) = NULL,       -- opcional, debe ser mayor que 0 si se informa
    @id_madre INT = NULL,                       -- opcional, referencia a la madre del animal
    @categoria VARCHAR(45),                     -- categoria del animal (vaca, vaquillona, toro, T.Macho o T.Hembra)
    @estado VARCHAR(45) = 'Activo',             -- por defecto se guarda como Activo        
    @id_insertado INT OUTPUT                    -- parametro de salida que devolvera el id insertado
AS
BEGIN
    SET NOCOUNT ON;                             -- Evita que SQL Server devuelva el mensaje: (1 row(s) affected)

    -- Bloque de manejo de errores
    BEGIN TRY
        -- Validaciones obligatorias
        IF (@raza IS NULL OR LTRIM(RTRIM(@raza)) = '')
        BEGIN
            RAISERROR('La raza es obligatoria.', 16, 1);    -- Verifica que la raza no sea nula o vacia. Si lo es, lanza un error con RAISERROR
            RETURN;
        END

        IF (@sexo NOT IN ('M','H'))                         -- Solo permite 'M' o 'H' como sexo
        BEGIN
            RAISERROR('El sexo debe ser "M" (Macho) o "H" (Hembra).', 16, 1);
            RETURN;
        END

        IF (@fecha_nacimiento IS NULL OR @fecha_nacimiento > GETDATE())     -- Fecha obligatoria y no puede ser mayor a la actual (GETDATE())
        BEGIN
            RAISERROR('La fecha de nacimiento no puede ser nula ni futura.', 16, 1);
            RETURN;
        END

        IF (@categoria IS NULL OR LTRIM(RTRIM(@categoria)) = '')            -- Categoria obligatoria, no se permite nula ni vacia
        BEGIN
            RAISERROR('La categoria es obligatoria.', 16, 1);
            RETURN;
        END

        IF (@peso_nacimiento IS NOT NULL AND @peso_nacimiento <= 0)         -- Si se informa un peso, debe ser mayor que cero
        BEGIN
            RAISERROR('El peso de nacimiento debe ser mayor a 0.', 16, 1);
            RETURN;
        END

        -- Insercion de la tabla
        INSERT INTO produccion.Animal
        (id_animal, raza, sexo, fecha_nacimiento, peso_nacimiento, id_madre, categoria, estado)
        VALUES          
        (@id_animal, @raza, @sexo, @fecha_nacimiento, @peso_nacimiento, @id_madre, @categoria, @estado);

        -- Devolver el id insertado
        SET @id_insertado = @id_animal;                         -- Asigna al parametro de salida el id_animal insertado

        PRINT 'Animal insertado correctamente.';                -- Mensaje informativo en la consola

    END TRY
    BEGIN CATCH                                                 -- Manejo de errores: imprime el mensaje del error que ocurrio
        PRINT 'Ocurrio un error: ' + ERROR_MESSAGE();
    END CATCH
END
GO


-- PRUEBAS DE FUNCIONAMIENTO

-- Ejecutar el procedimiento con parametros validos
DECLARE @id_insertado INT;

EXEC produccion.InsertarAnimal
    @id_animal = 205,
    @raza = 'Aberdeen Angus',
    @sexo = 'H',
    @fecha_nacimiento = '2022-05-10',
    @peso_nacimiento = 30.5,
    @id_madre = NULL,
    @categoria = 'T.Hembra',
    @estado = 'Activo',
    @id_insertado = @id_insertado OUTPUT;

PRINT 'El ID insertado fue: ' + CAST(@id_insertado AS VARCHAR);

-- Verificar que el registro realmente este en la tabla
SELECT *
FROM produccion.Animal
WHERE id_animal = 205;

-- SE PRUEBA VALIDACIONES:
-- Validacion: Raza vacia
EXEC produccion.InsertarAnimal
    @id_animal = 102,
    @raza = '',
    @sexo = 'M',
    @fecha_nacimiento = '2023-01-01',
    @categoria = 'Toro',
    @id_insertado = NULL;

-- Validacion: Sexo invalido
EXEC produccion.InsertarAnimal
    @id_animal = 103,
    @raza = 'Angus',
    @sexo = 'X',
    @fecha_nacimiento = '2023-01-01',
    @categoria = 'Toro',
    @id_insertado = NULL;

-- Validacion: Fecha de nacimiento futura
EXEC produccion.InsertarAnimal
    @id_animal = 104,
    @raza = 'Hereford',
    @sexo = 'M',
    @fecha_nacimiento = '2050-01-01',
    @categoria = 'Toro',
    @id_insertado = NULL;

-- Validacion: Peso de nacimiento
EXEC produccion.InsertarAnimal
    @id_animal = 105,
    @raza = 'Hereford',
    @sexo = 'H',
    @fecha_nacimiento = '2023-01-01',
    @peso_nacimiento = -5,
    @categoria = 'Vaquillona',
    @id_insertado = NULL;




-------------------------------------------------------------------------------
-- c) SP de eliminacion controlada: Procedimiento EliminarAnimal
-------------------------------------------------------------------------------
-- Este procedimiento elimina un animal solo si existe y si no tiene crias registradas.
-- Si no cumple esas condiciones, devuelve un mensaje de error y no elimina nada.


-- Si ya existe el procedimiento, lo elimina para poder crearlo de nuevo
IF OBJECT_ID('produccion.EliminarAnimal', 'P') IS NOT NULL
    DROP PROCEDURE produccion.EliminarAnimal;
GO


-- Se crea el procedimiento EliminarAnimal
CREATE PROCEDURE produccion.EliminarAnimal
    @id_animal INT
AS
BEGIN
    SET NOCOUNT ON;                         -- Evita que SQL Server devuelva el mensaje: (1 row(s) affected)

    BEGIN TRY
        -- Verificar si existe el animal
        IF NOT EXISTS (SELECT 1 FROM produccion.Animal WHERE id_animal = @id_animal)
        BEGIN
            RAISERROR('El animal no existe en la base de datos.', 16, 1);
            RETURN;
        END

        -- Verificar si el animal tiene crias asociadas (integridad referencial)
        IF EXISTS (SELECT 1 FROM produccion.Animal WHERE id_madre = @id_animal)
        BEGIN
            RAISERROR('No se puede eliminar: el animal tiene crias registradas.', 16, 1);
            RETURN;
        END

        -- Eliminar el registro (si pasa las validaciones anteriores)
        DELETE FROM produccion.Animal WHERE id_animal = @id_animal;

        PRINT 'Animal eliminado correctamente.';

    END TRY
    BEGIN CATCH                                     -- Manejo de errores: imprime el mensaje del error que ocurrio
        PRINT 'Ocurrio un error al intentar eliminar: ' + ERROR_MESSAGE();
    END CATCH
END
GO



-- PRUEBAS DE FUNCIONAMIENTO
-- Caso exitoso
EXEC produccion.EliminarAnimal @id_animal = 205;    -- Es el animal cargado en el punto anterior    

-- Caso de error: el animal no existe
EXEC produccion.EliminarAnimal @id_animal = 999;

-- Caso de error: el animal tiene crias asociadas
EXEC produccion.EliminarAnimal @id_animal = 4112;




/**********************************************************************************
2. Triggers
**********************************************************************************/
-----------------------------------------------------------------------------------
-- a) Trigger AFTER INSERT: se ejecutara automaticamente despues de que se inserte 
--    un registro en produccion.Animal y copiara los datos a la tabla de auditoria 
-----------------------------------------------------------------------------------


-- Eliminar la tabla Animal_Auditoria si ya existe
IF OBJECT_ID('produccion.Animal_Auditoria', 'U') IS NOT NULL
    DROP TABLE produccion.Animal_Auditoria;
GO


-- Crear la tabla de auditoria
CREATE TABLE produccion.Animal_Auditoria (
    id_auditoria INT IDENTITY(1,1) PRIMARY KEY,  -- ID unico para la auditoria
    id_animal INT,
    raza VARCHAR(45),
    sexo CHAR(1),
    fecha_nacimiento DATE,
    peso_nacimiento DECIMAL(5,2),
    id_madre INT,
    categoria VARCHAR(45),
    estado VARCHAR(45),
    fecha_insercion DATETIME DEFAULT GETDATE()  -- fecha y hora de la insercion
);
GO



-- Eliminar el trigger AFTER INSERT si ya existe
IF OBJECT_ID('produccion.trg_AfterInsert_Animal', 'TR') IS NOT NULL
    DROP TRIGGER produccion.trg_AfterInsert_Animal;
GO



-- Crear el trigger AFTER INSERT
CREATE TRIGGER produccion.trg_AfterInsert_Animal
ON produccion.Animal
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Insertar en la tabla de auditoria los datos del registro recien insertado
    INSERT INTO produccion.Animal_Auditoria
        (id_animal, raza, sexo, fecha_nacimiento, peso_nacimiento, id_madre, categoria, estado, fecha_insercion)
    SELECT 
        id_animal, raza, sexo, fecha_nacimiento, peso_nacimiento, id_madre, categoria, estado, GETDATE()
    FROM inserted;
END;
GO

-- Validacion
-- Eliminar el registro existente (de pruebas anteriores)
DELETE FROM produccion.Animal
WHERE id_animal = 210;

DECLARE @id_insertado INT;

EXEC produccion.InsertarAnimal
    @id_animal = 210,
    @raza = 'Aberdeen Angus',
    @sexo = 'H',
    @fecha_nacimiento = '2023-05-01',
    @peso_nacimiento = 195.50,
    @categoria = 'Vaquillona',
    @id_insertado = @id_insertado OUTPUT;

-- Ver tabla de auditoria:
SELECT * FROM produccion.Animal_Auditoria
WHERE id_animal = 210;
GO


------------------------------------------------------------------------------------------
-- b) Trigger INSTEAD OF UPDATE: que valide la categoria en funcion de la edad del animal
------------------------------------------------------------------------------------------

-- Eliminar el trigger Instead Of Update Categoria si ya existe
IF OBJECT_ID('produccion.trg_InsteadOfUpdate_Categoria', 'TR') IS NOT NULL
    DROP TRIGGER produccion.trg_InsteadOfUpdate_Categoria;
GO



-- Crear el trigger Instead Of Update Categoria
CREATE TRIGGER produccion.trg_InsteadOfUpdate_Categoria
ON produccion.Animal
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo actualizar si no se viola la regla de "Vaca"
    UPDATE a
    SET
        raza = i.raza,
        sexo = i.sexo,
        fecha_nacimiento = i.fecha_nacimiento,
        peso_nacimiento = i.peso_nacimiento,
        id_madre = i.id_madre,
        categoria = i.categoria,
        estado = i.estado
    FROM produccion.Animal a
    INNER JOIN inserted i ON a.id_animal = i.id_animal
    WHERE NOT (
        i.categoria = 'Vaca' AND 
        (DATEDIFF(YEAR, a.fecha_nacimiento, GETDATE()) < 3 OR a.sexo <> 'H')
    );

    -- Mensaje para los registros que no pudieron actualizarse
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN produccion.Animal a ON a.id_animal = i.id_animal
        WHERE i.categoria = 'Vaca' AND 
              (DATEDIFF(YEAR, a.fecha_nacimiento, GETDATE()) < 3 OR a.sexo <> 'H')
    )
    BEGIN
        PRINT 'Algunos animales no pudieron actualizar su categoria a "Vaca" porque no cumplen con las condiciones: al menos 3 años y sexo Hembra.';
    END
END;
GO


-- Validacion: 
-- Consultar que animales NO pueden ser Vaca y elegir uno
SELECT 
    id_animal,
    raza,
    sexo,
    fecha_nacimiento,
    DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) AS edad,
    categoria,
    estado
FROM produccion.Animal
WHERE NOT (sexo = 'H' AND DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) >= 3)
ORDER BY edad ASC;

-- Actualizar el animal 1523 (Vaquillona de 2 años) a categoria a "Vaca":
UPDATE produccion.Animal
SET categoria = 'Vaca'
WHERE id_animal = 1523;

-- Doble verificacion: ver los datos del animal 1523 y verificar que sigue siendo Vaquillona
SELECT 
    id_animal,
    raza,
    sexo,
    fecha_nacimiento,
    peso_nacimiento,
    id_madre,
    categoria,
    estado
FROM produccion.Animal
WHERE id_animal = 1523;



/**********************************************************************************
3. Cursor dentro de un Stored Procedure
**********************************************************************************/
-- El objetivo del procedimiento con el uso de cursor es calcular y mostrar la variación del peso de un animal específico
-- a lo largo de su vida, recorriendo todos los registros de peso dentro de la tabla produccion.Peso en orden cronológico
-- comparando cada peso con el anterior.
-- Se muestra un mensaje por cada registo indicando cuanto vario, en esa fecha, respecto a la última


-- Si ya existe un procedimiento llamado Var_PesoAnimal en el esquema produccion, lo elimina antes de crearlo de nuevo.
IF OBJECT_ID('produccion.sp_Var_PesoAnimal', 'P') IS NOT NULL
    DROP PROCEDURE produccion.sp_Var_PesoAnimal;
GO


-- Se crea el procedimiento Var Peso Animal
CREATE PROCEDURE produccion.sp_Var_PesoAnimal
   @id_animal INT                                  -- Parámetro de entrada: id del animal que se va a analizar
AS
BEGIN
   SET NOCOUNT ON;

   -- Variables para el cursor
   DECLARE @PesoCursor CURSOR;                     -- Cursor para recorrer los registros de peso del animal
   DECLARE @fecha_medicion DATE;                   -- Fecha de cada medición de peso (la fila actual en el cursor)
   DECLARE @peso_ultimo DECIMAL(10,2);             -- Peso del animal en la medición actual (la fila que se está leyendo)
   DECLARE @peso_anterior DECIMAL(10,2) = NULL;    -- Peso del animal en la medición anterior (arranca en NULL porque no hay un valor previo en la primera fila)
   DECLARE @variacion DECIMAL(10,2);               -- Variación porcentual entre el peso actual y el anterior


   -- Cursor para recorrer los registros de peso del animal ordenados por fecha
   SET @PesoCursor = CURSOR FOR
      SELECT fecha_medicion, valor
      FROM produccion.Peso
      WHERE id_animal = @id_animal
      ORDER BY fecha_medicion ASC;

   OPEN @PesoCursor;

   -- Inicializa la lectura del cursor
   FETCH NEXT FROM @PesoCursor INTO @fecha_medicion, @peso_ultimo;

   -- Bucle para recorrer todas las filas del cursor
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Si existe un peso anterior, calculamos la variación
      IF @peso_anterior IS NOT NULL
      BEGIN
          -- Se calcula la variación respecto al peso anterior
          SET @variacion = ((@peso_ultimo - @peso_anterior) * 100.0 / @peso_anterior);

          -- Muestra el mensaje con formato: Fecha: varió su peso en XX.XX%
          PRINT CAST(@fecha_medicion AS NVARCHAR(12)) + ':' +
              ' varió su peso en ' + CAST(@variacion AS NVARCHAR(10)) + '%';
      END

      -- Actualiza el peso anterior para la siguiente iteración
      SET @peso_anterior = @peso_ultimo;

      -- Avanza a la siguiente fila del cursor
      FETCH NEXT FROM @PesoCursor INTO @fecha_medicion, @peso_ultimo;
   END

   -- Se cierra el cursor
   CLOSE @PesoCursor;
   DEALLOCATE @PesoCursor;

END; 
GO

-- Verificacion del procedimiento ingresando en el parametro @id_animal algún id vigente
EXEC produccion.sp_Var_PesoAnimal @id_animal = 5062;



/**********************************************************************************
4. Importacion de Datos desde JSON
**********************************************************************************/
-- Eliminacion de registros cargados desde JSON (ejemplo de prueba)
DELETE FROM rrhh.Personal
WHERE nombre IN ('Franco', 'Florencia', 'Yesica');

-- Verificar si Ad Hoc Distributed Queries esta habilitado: tiene que devolver 1 en run_value
EXEC sp_configure 'Ad Hoc Distributed Queries';

-- Si no esta habilitado, hacer:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;


-- El archivo JSON fue creado en Visual Studio Code para este ejercicio
-- Contiene la informacion de 3 empleados de ejemplo que se insertaron en la tabla rrhh.Personal

-- Cargar JSON desde archivo
DECLARE @json NVARCHAR(MAX);

SELECT @json = BulkColumn
FROM OPENROWSET(BULK 'data\personal.json', SINGLE_CLOB) AS j;             -- Se usa la ruta relativa dentro del repositorio: 'data\personal.json'. Ajustar a ruta absoluta si el servidor SQL lo requiere

INSERT INTO rrhh.Personal (nombre, apellido, contacto_emerg, celular)           --Insertar en la tabla usando OPENJSON
SELECT nombre, apellido, contacto_emerg, celular
FROM OPENJSON(@json)
WITH (
    nombre         VARCHAR(50)  '$.nombre',
    apellido       VARCHAR(50)  '$.apellido',
    contacto_emerg VARCHAR(80)  '$.contacto_emerg',
    celular        VARCHAR(18)  '$.celular'
);

-- Verificar que se insertaron los datos
SELECT * FROM rrhh.Personal;




/**********************************************************************************
5. Actualizacion de Datos desde CSV
**********************************************************************************/

-- Se carga un animal para este fin
DECLARE @id_insertado INT;

EXEC produccion.InsertarAnimal
    @id_animal = 505,
    @raza = 'Aberdeen Angus',
    @sexo = 'M',
    @fecha_nacimiento = '2022-09-01',
    @peso_nacimiento = 39.8,
    @id_madre = NULL,
    @categoria = 'T.Macho',
    @estado = 'Activo',
    @id_insertado = @id_insertado OUTPUT;

PRINT 'El ID insertado fue: ' + CAST(@id_insertado AS VARCHAR);


-- Eliminar todos los registros de peso del animal 505 (Para reproducir prueba)
DELETE FROM produccion.Peso
WHERE id_animal = 505;


-- Paso 1: Crear tabla temporal para CSV
IF OBJECT_ID('tempdb..#Peso_Temp') IS NOT NULL
    DROP TABLE #Peso_Temp;

CREATE TABLE #Peso_Temp (
    fecha_medicion DATE NOT NULL,
    id_animal INT NOT NULL,
    valor DECIMAL(5,2) NOT NULL
);


-- Paso 2: Cargar primer CSV al temp
BULK INSERT #Peso_Temp
FROM 'data\pesos1.csv'
WITH (
    FIRSTROW = 2,           -- saltar encabezado
    FIELDTERMINATOR = ',',  -- separador de columnas
    ROWTERMINATOR = '\n',   -- fin de fila
    TABLOCK
);

-- Paso 3: Verificar 10 datos cargados en temp
SELECT TOP 20 * FROM #Peso_Temp;

-- Paso 4: MERGE con tabla principal
MERGE INTO produccion.Peso AS target
USING #Peso_Temp AS src
ON target.id_animal = src.id_animal
   AND target.fecha_medicion = src.fecha_medicion
WHEN MATCHED AND target.valor <> src.valor THEN
    UPDATE SET target.valor = src.valor
WHEN NOT MATCHED BY TARGET THEN
    INSERT (fecha_medicion, id_animal, valor)
    VALUES (src.fecha_medicion, src.id_animal, src.valor);
GO

-- Paso 5: Verificar tabla principal
SELECT TOP 20 * FROM produccion.Peso
WHERE id_animal = 505
ORDER BY fecha_medicion;

-- Paso 6: Limpiar tabla temporal antes de 2do CSV
TRUNCATE TABLE #Peso_Temp;

-- Paso 7: Cargar segundo CSV (duplicados/modificados)
BULK INSERT #Peso_Temp
FROM 'data\pesos2.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

-- Paso 8: Repetir MERGE para actualizar tabla principal
MERGE INTO produccion.Peso AS target
USING #Peso_Temp AS src
ON target.id_animal = src.id_animal
   AND target.fecha_medicion = src.fecha_medicion
WHEN MATCHED AND target.valor <> src.valor THEN
    UPDATE SET target.valor = src.valor
WHEN NOT MATCHED BY TARGET THEN
    INSERT (fecha_medicion, id_animal, valor)
    VALUES (src.fecha_medicion, src.id_animal, src.valor);
GO

-- Luego de correr el codigo la consola devuelve (5 filas afectadas)
-- El archivo contiene 10 registros, pero 5 de ellos son duplicados

-- Paso 9: Verificar tabla principal final
SELECT TOP 20 * FROM produccion.Peso
WHERE id_animal = 505
ORDER BY fecha_medicion;
