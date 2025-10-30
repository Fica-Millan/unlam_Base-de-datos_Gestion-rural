/* 
Trabajo Practico Integrador - Parte III - 2025
Integrantes: Fica Millan, Yesica 
             Petraroia, Franco 
             Miranda Charca, Florencia 
Grupo: VI
Fecha de entrega: 04/09/2025 
*/

USE GRUPOVI;
GO



/***************************************************************************
1.1 Insertar datos en produccion.Animal
***************************************************************************/

-- Verificar los primeros 10 registros de Animal
SELECT TOP 10 *
FROM produccion.Animal
ORDER BY id_animal;

/***************************************************************************
1.2 Insertar datos en produccion.Nacimientos
***************************************************************************/

-- Verificar los Nacimiento creados
SELECT TOP 10 *
FROM produccion.Nacimiento
ORDER BY madre_id, nro_nacimiento;

-- Verificar que cada parto posterior sea mayor al anterior
SELECT madre_id, nro_nacimiento, fecha,
       LAG(fecha) OVER (PARTITION BY madre_id ORDER BY nro_nacimiento) AS parto_anterior
FROM produccion.Nacimiento;

/***************************************************************************
1.3 Insertar datos en produccion.Peso
***************************************************************************/

-- Verificar los primeros 10 registros de Peso
SELECT TOP 10 *
FROM produccion.Peso;

/***************************************************************************
1.4 Insertar datos en produccion.Potrero
***************************************************************************/

-- Verificar los registros de Potrero
SELECT *
FROM produccion.Potrero;

/***************************************************************************
1.5 Insertar datos en produccion.Animal_Potrero
***************************************************************************/

-- Verificar los registros de Animal_Potrero
SELECT *
FROM produccion.Animal_Potrero;

/***************************************************************************
1.6 Insertar datos en produccion.Evento
***************************************************************************/

-- Verificar los registros de Evento
SELECT *
FROM produccion.Evento
ORDER BY fecha;

-- Contar eventos por tipo
SELECT tipo_evento, COUNT(*) AS cantidad
FROM produccion.Evento
GROUP BY tipo_evento;

/***************************************************************************
1.7 Insertar datos en rrhh.Personal
***************************************************************************/

-- Ver todos los registros cargados
SELECT * 
FROM rrhh.Personal;

/***************************************************************************
1.8 Insertar datos en rrhh.Peon
***************************************************************************/

-- Ver todos los registros de Peon
SELECT * 
FROM rrhh.Peon;

/***************************************************************************
1.9 Insertar datos en rrhh.Capataz
***************************************************************************/

-- Ver todos los registros de Capataz
SELECT * 
FROM rrhh.Capataz;

/***************************************************************************
1.10 Insertar datos en rrhh.Tractorista
***************************************************************************/

-- Ver todos los tractoristas cargados
SELECT * 
FROM rrhh.Tractorista;

/***************************************************************************
1.11 Insertar datos en rrhh.Encargado
***************************************************************************/

-- Ver todos los encargados cargados
SELECT * 
FROM rrhh.Encargado;

/***************************************************************************
1.12 Insertar datos en rrhh.Veterinario
***************************************************************************/

-- Ver todos los veterinarios cargados
SELECT * 
FROM rrhh.Veterinario;

/***************************************************************************
1.13 Insertar datos en gestion.Animal_Personal_Evento
***************************************************************************/

-- Ver registro cargado
SELECT *
FROM gestion.Animal_Personal_Evento
WHERE id_evento = 1;

/***************************************************************************
1.14 Insertar datos en gestion.Potrero_Evento
***************************************************************************/

-- Se verifica el numero del ID del evento creado para este fin
SELECT TOP 1 *
FROM produccion.Evento
ORDER BY id_evento DESC;

-- Ver registro cargado
SELECT *
FROM gestion.Potrero_Evento
WHERE id_evento = 6;



/***************************************************************************
2.	Consultas con JOIN y Subconsultas 
***************************************************************************/
 
-- 2.1 INNER JOIN
-- Enunciado: Mostrar los animales que participaron en algun evento junto con el nombre del personal y el tipo de evento.
-- INNER JOIN entre Animal_Personal_Evento, Animal, Personal y Evento
-- Muestra solo combinaciones existentes (participaciones confirmadas)
SELECT 
    ape.id_animal,
    a.id_animal AS animal_id,
    per.nombre + ' ' + per.apellido AS personal,
    e.tipo_evento,
    ape.rol_evento
FROM gestion.Animal_Personal_Evento ape
INNER JOIN produccion.Animal a ON ape.id_animal = a.id_animal
INNER JOIN rrhh.Personal per ON ape.id_personal = per.id_personal
INNER JOIN produccion.Evento e ON ape.id_evento = e.id_evento
ORDER BY ape.id_animal, ape.id_evento;


-- 2.2 LEFT JOIN
-- Enunciado: Listar todos los eventos y, si corresponde, los potreros donde se realizaron. Mostrar NULL si no hay potrero asignado.
-- LEFT JOIN entre Evento y Potrero_Evento
-- Incluye todos los eventos, aunque no tengan potrero asignado
SELECT 
    e.id_evento,
    e.tipo_evento,
    e.fecha,
    pe.id_potrero
FROM produccion.Evento e
LEFT JOIN gestion.Potrero_Evento pe ON e.id_evento = pe.id_evento
ORDER BY e.fecha;


-- 2.3 FULL OUTER JOIN
-- Enunciado: Mostrar todos los animales y todos los eventos, indicando si cada animal participo o no de cada evento.
-- FULL OUTER JOIN entre Animal y Animal_Personal_Evento
-- Permite ver animales sin eventos y eventos sin animales asignados
SELECT 
    a.id_animal,
    ape.id_evento,
    ape.id_personal,
    ape.rol_evento
FROM produccion.Animal a
FULL OUTER JOIN gestion.Animal_Personal_Evento ape ON a.id_animal = ape.id_animal
ORDER BY a.id_animal, ape.id_evento;


-- 2.4 Subconsulta con IN
-- Enunciado: Mostrar el personal que participo en eventos de tipo 'Vacunacion'.
-- Subconsulta con IN
SELECT nombre, apellido
FROM rrhh.Personal
WHERE id_personal IN (
    SELECT id_personal
    FROM gestion.Animal_Personal_Evento ape
    INNER JOIN produccion.Evento e ON ape.id_evento = e.id_evento
    WHERE e.tipo_evento = 'Vacunacion'
);


-- 2.5 Subconsulta con EXISTS
-- Enunciado: Mostrar los animales que tuvieron al menos un veterinario a cargo en algun evento.
-- Subconsulta con EXISTS
SELECT a.id_animal
FROM produccion.Animal a
WHERE EXISTS (
    SELECT 1
    FROM gestion.Animal_Personal_Evento ape
    INNER JOIN rrhh.Veterinario v ON ape.id_personal = v.id_personal
    WHERE ape.id_animal = a.id_animal
);


-- 2.6 Subconsulta con ANY
-- Enunciado: Listar los animales cuyo ultimo peso supera al menos uno de los pesos registrados en vaquillonas.
-- Subconsulta con ANY
-- Selecciona los animales cuyo ultimo peso es mayor que alguno de los pesos de vaquillonas
SELECT a.id_animal
FROM produccion.Animal a
-- Subconsulta: obtener la ultima fecha de medicion de peso de cada animal
JOIN (
    SELECT id_animal, MAX(fecha_medicion) AS ultima_fecha
    FROM produccion.Peso
    GROUP BY id_animal
) ult ON a.id_animal = ult.id_animal
-- Obtener el peso correspondiente a la ultima fecha
JOIN produccion.Peso p 
    ON p.id_animal = a.id_animal AND p.fecha_medicion = ult.ultima_fecha
-- Comparar con todos los pesos historicos de vaquillonas, usando ANY
WHERE p.valor > ANY (
    SELECT valor
    FROM produccion.Peso p2
    JOIN produccion.Animal a2 ON p2.id_animal = a2.id_animal
    WHERE a2.categoria = 'Vaquillona'
);


-- 2.7 Subconsulta con ALL
-- Enunciado: Mostrar personal que participo en todos los eventos del tipo 'Vacunacion'.
SELECT p.id_personal, p.nombre, p.apellido
FROM rrhh.Personal p
WHERE p.id_personal IN (
    SELECT ape.id_personal
    FROM gestion.Animal_Personal_Evento ape
    INNER JOIN produccion.Evento e ON ape.id_evento = e.id_evento
    WHERE e.tipo_evento = 'Vacunacion'
    GROUP BY ape.id_personal
    HAVING COUNT(DISTINCT ape.id_evento) >= ALL (
        SELECT COUNT(*) 
        FROM produccion.Evento
        WHERE tipo_evento = 'Vacunacion'
    )
);




/***************************************************************************
3.	Consultas con Funciones Comunes y de Agregados 
***************************************************************************/

-- 3.1 Funciones de Texto
-- Ver iniciales de la raza en mayusculas
SELECT id_animal, UPPER(LEFT(raza,3)) AS inicial_raza, sexo
FROM produccion.Animal
WHERE id_animal BETWEEN 1000 AND 1800;

-- Concatenar caravana + sexo
SELECT id_animal, CONCAT('Caravana: ', id_animal, ' - Sexo: ', sexo) AS detalle
FROM produccion.Animal
WHERE id_animal BETWEEN 1000 AND 1800;

-- Longitud de la categoria (cuantos caracteres tiene la palabra)
SELECT id_animal, categoria, LEN(categoria) AS largo_categoria
FROM produccion.Animal
WHERE id_animal BETWEEN 1000 AND 1800;


-- 3.2.Funciones Matematicas
-- Promedio del peso de los animales insertados
SELECT CAST(AVG(peso_nacimiento) AS DECIMAL(10,2)) AS promedio_peso
FROM produccion.Animal
WHERE id_animal BETWEEN 1000 AND 1800;

-- Peso total de los animales insertados
SELECT SUM(peso_nacimiento) AS peso_total
FROM produccion.Animal
WHERE id_animal BETWEEN 1000 AND 1800;

-- Distribucion por sexo
SELECT sexo, COUNT(*) AS cantidad
FROM produccion.Animal
WHERE id_animal BETWEEN 1000 AND 1800
GROUP BY sexo;


-- 3.3 Funciones de Fecha
-- Ver año, mes y dia de nacimiento de cada animal
SELECT id_animal,
       YEAR(fecha_nacimiento) AS anio,
       MONTH(fecha_nacimiento) AS mes,
       DAY(fecha_nacimiento) AS dia
FROM produccion.Animal
WHERE id_animal BETWEEN 1000 AND 1800;

-- Calcular edad en dias de cada animal respecto de hoy
SELECT id_animal,
       DATEDIFF(DAY, fecha_nacimiento, GETDATE()) AS edad_dias
FROM produccion.Animal
WHERE id_animal BETWEEN 1000 AND 1800;

-- Agregar 2 años a la fecha de nacimiento (fecha estimada de entore)
SELECT id_animal,
       fecha_nacimiento,
       DATEADD(YEAR, 2, fecha_nacimiento) AS fecha_entore
FROM produccion.Animal
WHERE id_animal BETWEEN 1000 AND 1800;




/***************************************************************************
4. Funciones Definidas por el Usuario (UDF)
***************************************************************************/

-- 4.1 Funcion escalar: calcular edad del animal en años
CREATE FUNCTION produccion.fn_EdadAnimal(@id_animal INT)
RETURNS INT
AS
BEGIN
    DECLARE @edad INT;
    DECLARE @fechaNacimiento DATE;
    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

    SELECT @fechaNacimiento = fecha_nacimiento
    FROM produccion.Animal
    WHERE id_animal = @id_animal;

    IF @fechaNacimiento IS NULL
        RETURN NULL;

    SET @edad = DATEDIFF(YEAR, @fechaNacimiento, @hoy) 
                - CASE 
                    WHEN (MONTH(@hoy) < MONTH(@fechaNacimiento))
                         OR (MONTH(@hoy) = MONTH(@fechaNacimiento) 
                             AND DAY(@hoy) < DAY(@fechaNacimiento))
                    THEN 1 ELSE 0 
                  END;

    RETURN @edad;
END;
GO

-- Usar
SELECT produccion.fn_EdadAnimal(1530) AS Edad;


-- 4.2 Funcion de tabla en linea:
CREATE FUNCTION produccion.fn_HistoricoPesoAnimal (@id_animal INT)

RETURNS TABLE
AS
RETURN
(
    SELECT 
        a.id_animal,
        a.categoria,
        DATEDIFF(YEAR, a.fecha_nacimiento, GETDATE()) AS edad,
        MIN(p.fecha_medicion) AS primera_fecha,
        (
            SELECT TOP 1 p2.valor
            FROM produccion.Peso p2
            WHERE p2.id_animal = @id_animal
            ORDER BY p2.fecha_medicion ASC
        ) AS primer_peso,
        MAX(p.fecha_medicion) AS ultima_fecha,
        (
            SELECT TOP 1 p3.valor
            FROM produccion.Peso p3
            WHERE p3.id_animal = @id_animal
            ORDER BY p3.fecha_medicion DESC
        ) AS ultimo_peso
    FROM produccion.Peso p
    INNER JOIN produccion.Animal a 
        ON p.id_animal = a.id_animal
    WHERE p.id_animal = @id_animal
    GROUP BY a.id_animal, a.categoria, a.fecha_nacimiento
);
GO

-- Usar
SELECT *
FROM produccion.fn_HistoricoPesoAnimal(8642);
GO


-- 4.3 Funcion de tabla multisentencia:
CREATE FUNCTION produccion.fn_AnimalesActivosPorCategoria (@categoria NVARCHAR(50))

RETURNS @Resultado TABLE
(
    id_animal INT,
    raza NVARCHAR(50),
    categoria NVARCHAR(50),
    edad INT,
    ultimo_peso DECIMAL(10,2)
)
AS
BEGIN
   
    DECLARE @UltimoPeso TABLE
    (
        id_animal INT,
        ultima_fecha DATE
    );

    INSERT INTO @UltimoPeso (id_animal, ultima_fecha)
    SELECT 
        p.id_animal,
        MAX(p.fecha_medicion) AS ultima_fecha
    FROM produccion.Peso p
    GROUP BY p.id_animal;

    INSERT INTO @Resultado (id_animal, raza, categoria, edad, ultimo_peso)
    SELECT 
        a.id_animal,
        a.raza,
        a.categoria,
        produccion.fn_EdadAnimal(a.id_animal) AS edad,
        p.valor AS ultimo_peso
    FROM produccion.Animal a
    INNER JOIN @UltimoPeso u 
        ON a.id_animal = u.id_animal
    INNER JOIN produccion.Peso p 
        ON p.id_animal = u.id_animal 
       AND p.fecha_medicion = u.ultima_fecha
    WHERE a.categoria = @categoria
      AND a.estado = 'Activo';

    RETURN;
END;

-- Usar
SELECT *
FROM produccion.fn_AnimalesActivosPorCategoria('Vaquillona')
ORDER BY edad;




/***************************************************************************
5. Operaciones de Actualizacion y Eliminacion
***************************************************************************/

-- 5.1 UPDATE: Actualizar el estado de animales que tengan mas de 4 años a 'Inactivo'
UPDATE produccion.Animal
SET estado = 'Inactivo'
WHERE DATEDIFF(YEAR, fecha_nacimiento, GETDATE()) > 4
    AND categoria = 'Vaquillona';

-- Verificar
SELECT id_animal, fecha_nacimiento, estado, categoria
FROM produccion.Animal
WHERE estado = 'Inactivo';


-- 5.2 DELETE: Eliminar mediciones de peso duplicadas para un mismo animal y fecha
;WITH CTE_Duplicados AS (
    SELECT 
        *,
        ROW_NUMBER() OVER(PARTITION BY id_animal, fecha_medicion 
                          ORDER BY fecha_medicion, id_animal) AS repetido
    FROM produccion.Peso
)
DELETE FROM CTE_Duplicados 
WHERE repetido > 1;

-- Para verificar
SELECT id_animal, fecha_medicion, COUNT(*) AS cantidad
FROM produccion.Peso
GROUP BY id_animal, fecha_medicion
HAVING COUNT(*) > 1;




/***************************************************************************
6. Consultas con Funciones de Ventana
***************************************************************************/

-- 6.1 Calcular cantidad de partos por madre (COUNT OVER)
SELECT 
    madre_id, COUNT(*) OVER(PARTITION BY madre_id) AS total_partos 
FROM produccion.Nacimiento
ORDER BY madre_id, nro_nacimiento;


-- 6.2 Calcular el peso promedio por animal con funcion de ventana
SELECT 
    id_animal, 
    fecha_medicion, 
    valor,
    CAST(ROUND(AVG(valor) OVER(PARTITION BY id_animal), 2) AS DECIMAL(10,2)) AS peso_promedio
FROM produccion.Peso
ORDER BY id_animal, fecha_medicion;


-- 6.3 Numerar animales por fecha de nacimiento (ROW_NUMBER)
SELECT 
    id_animal,
    fecha_nacimiento,
    categoria,
    ROW_NUMBER() OVER(PARTITION BY categoria ORDER BY fecha_nacimiento) AS nro_fila
FROM produccion.Animal;


-- 6.4 Ranking de animales por ultimo peso (RANK)
;WITH UltimoPeso AS (
    SELECT 
        id_animal,
        MAX(fecha_medicion) AS ultima_fecha
    FROM produccion.Peso
    GROUP BY id_animal
)
SELECT 
    a.categoria,
    a.id_animal,
    p.valor AS peso,
    RANK() OVER(PARTITION BY a.categoria ORDER BY p.valor DESC) AS ranking,
    DENSE_RANK() OVER(PARTITION BY a.categoria ORDER BY p.valor DESC) AS ranking_denso
FROM UltimoPeso u
JOIN produccion.Peso p 
     ON u.id_animal = p.id_animal 
    AND u.ultima_fecha = p.fecha_medicion
JOIN produccion.Animal a 
     ON u.id_animal = a.id_animal;




/***************************************************************************
7.	Expresiones Comunes de Tabla (CTE) 
***************************************************************************/
-- Para poder llevar a cabo este punto se deben cargar los animales nacidos a la tabla produccion.Animales
-- Consulta de nacimientos
SELECT *
FROM produccion.Nacimiento
WHERE tipo_parto <> 'No presenta ternero'
ORDER BY madre_id, nro_nacimiento;

-- Insercion de animales nacidos, excluyendo tipo_parto = 'No presenta ternero'
INSERT INTO produccion.Animal (
    id_animal, raza, sexo, fecha_nacimiento, peso_nacimiento, id_madre, categoria, estado
)
VALUES
(9001, 'Aberdeen Angus', 'H', '2025-08-07', 30.5, 2914, 'T.Hembra', 'Activo'),
(9002, 'Aberdeen Angus', 'M', '2023-08-23', 30.0, 3306, 'T.Macho', 'Activo'),
(9003, 'Aberdeen Angus', 'H', '2024-09-14', 29.3, 3306, 'T.Hembra', 'Activo'),
(9004, 'Aberdeen Angus', 'M', '2021-09-18', 35.7, 3511, 'T.Macho', 'Activo'),
(9005, 'Aberdeen Angus', 'M', '2021-08-05', 29.2, 4044, 'T.Macho', 'Activo'),
(9006, 'Aberdeen Angus', 'H', '2022-07-29', 31.5, 4044, 'T.Hembra', 'Activo'),
(9007, 'Aberdeen Angus', 'M', '2025-09-22', 29.7, 4112, 'T.Macho', 'Activo'),
(9008, 'Aberdeen Angus', 'H', '2025-07-05', 30.5, 4112, 'T.Hembra', 'Activo'),
(9009, 'Aberdeen Angus', 'M', '2025-08-13', 30.2, 4112, 'T.Macho', 'Activo'),
(9010, 'Aberdeen Angus', 'H', '2022-09-16', 31.8, 4369, 'T.Hembra', 'Activo'),
(9011, 'Aberdeen Angus', 'H', '2025-09-27', 30.5, 4580, 'T.Hembra', 'Activo'),
(9012, 'Aberdeen Angus', 'M', '2024-09-03', 30.0, 5907, 'T.Macho', 'Activo'),
(9013, 'Aberdeen Angus', 'H', '2023-07-29', 29.3, 6439, 'T.Hembra', 'Activo'),
(9014, 'Aberdeen Angus', 'H', '2024-09-12', 29.3, 6439, 'T.Hembra', 'Activo'),
(9015, 'Aberdeen Angus', 'M', '2022-09-18', 35.7, 7221, 'T.Macho', 'Activo'),
(9016, 'Aberdeen Angus', 'M', '2021-09-07', 29.2, 7359, 'T.Macho', 'Activo'),
(9017, 'Aberdeen Angus', 'H', '2023-08-22', 31.5, 7359, 'T.Hembra', 'Activo'),
(9018, 'Aberdeen Angus', 'M', '2024-07-31', 29.7, 9179, 'T.Macho', 'Activo'),
(9019, 'Aberdeen Angus', 'H', '2025-08-28', 30.5, 9179, 'T.Hembra', 'Activo'),
(9020, 'Aberdeen Angus', 'M', '2021-08-03', 30.2, 9447, 'T.Macho', 'Activo');


-- 7.1 CTE Recursiva (jerarquia madre-hija en animales)
WITH CTE_Familia AS (
    -- Nivel base: madres
    SELECT 
        a.id_animal,
        a.raza,
        a.id_madre,
        0 AS nivel
    FROM produccion.Animal a
    WHERE a.id_madre IS NULL
    
    UNION ALL
    
    -- Recursion: hijos de cada madre
    SELECT 
        h.id_animal,
        h.raza,
        h.id_madre,
        c.nivel + 1
    FROM produccion.Animal h
    INNER JOIN CTE_Familia c ON h.id_madre = c.id_animal
)
SELECT * 
FROM CTE_Familia
ORDER BY nivel, id_animal;


-- 7.2 CTE para simplificar subconsulta (ultimo peso por animal)
WITH UltimoPeso AS (
    SELECT 
        p.id_animal,
        MAX(p.fecha_medicion) AS ultima_fecha
    FROM produccion.Peso p
    GROUP BY p.id_animal
)
SELECT 
    u.id_animal,
    u.ultima_fecha,
    p.valor AS peso_ultimo
FROM UltimoPeso u
JOIN produccion.Peso p
  ON u.id_animal = p.id_animal 
 AND u.ultima_fecha = p.fecha_medicion;




/***************************************************************************
8. Transformaciones con PIVOT y UNPIVOT
***************************************************************************/

-- 8.1 PIVOT (cantidad de partos por tipo)
SELECT madre_id, [Normal], [Cesarea], [Asistido], [Aborto], [No presenta ternero]
FROM (
    SELECT madre_id, tipo_parto
    FROM produccion.Nacimiento
) AS src
PIVOT (
    COUNT(tipo_parto)
    FOR tipo_parto IN ([Normal], [Cesarea], [Asistido], [Aborto], [No presenta ternero])
) AS p;


-- 8.2 UNPIVOT (categorias de animales en filas)
-- Cantidad de animales por sexo y categoria en formato UNPIVOT
SELECT categoria, atributo, cantidad
FROM (
    SELECT categoria,
           COUNT(CASE WHEN sexo = 'M' THEN 1 END) AS Machos,
           COUNT(CASE WHEN sexo = 'H' THEN 1 END) AS Hembras
    FROM produccion.Animal
    GROUP BY categoria
) AS src
UNPIVOT (
    cantidad FOR atributo IN ([Machos], [Hembras])
) AS unp;




/***************************************************************************
9. Vistas
***************************************************************************/

-- 9.1 Vista de animales activos con ultimo peso
CREATE VIEW gestion.vw_Animales_Activos_Peso AS
WITH UltimoPeso AS (
    SELECT id_animal, MAX(fecha_medicion) AS ultima_fecha
    FROM produccion.Peso
    GROUP BY id_animal
)
SELECT 
    a.id_animal,
    a.raza,
    a.categoria,
    a.estado,
    p.valor AS peso_actual,
    u.ultima_fecha
FROM produccion.Animal a
JOIN UltimoPeso u ON a.id_animal = u.id_animal
JOIN produccion.Peso p 
     ON u.id_animal = p.id_animal AND u.ultima_fecha = p.fecha_medicion
WHERE a.estado = 'Activo';
GO

-- Verificacion
SELECT *
FROM gestion.vw_Animales_Activos_Peso;


-- 9.2 Vista de eventos con participantes
CREATE VIEW gestion.vw_Eventos_Con_Participantes AS
SELECT 
    e.id_evento,
    e.tipo_evento,
    e.fecha,
    a.id_animal,
    p.nombre + ' ' + p.apellido AS personal,
    ape.rol_evento
FROM produccion.Evento e
JOIN gestion.Animal_Personal_Evento ape ON e.id_evento = ape.id_evento
JOIN produccion.Animal a ON ape.id_animal = a.id_animal
JOIN rrhh.Personal p ON ape.id_personal = p.id_personal;
GO

-- Verificacion
SELECT *
FROM gestion.vw_Eventos_Con_Participantes;


-- 9.3 Vista de potreros y superficie disponible
CREATE VIEW gestion.vw_Potreros_Disponibles AS
SELECT 
    id_potrero,
    superficie,
    tipo
FROM produccion.Potrero
WHERE superficie > 0;
GO

-- Verificacion
SELECT *
FROM gestion.vw_Potreros_Disponibles;
