

-- creamos la base de datos
-- drop database if exists mibdr; 
create database mibdr; 
select current_database();


-- tabla usuario. id, nombrecompleto, correo, fecharegistro y fecha nacimiento
-- constraints:
-- la fecha de nacimiento debe ser menor a la fecha de registro por obvias razones
-- el correo electronico debe ser unico para cada persona 
-- * serial hace que sea not null y va enumerando solo los ids mientras de van creando
create table usuario (
    ID_usuario          SERIAL,
    nombre_completo 	VARCHAR(100) not null,	
    correo 				VARCHAR(100)  not null,	
    fecha_registro      DATE not null  default CURRENT_DATE, --ojo 
    fecha_nacimiento    DATE not null,	 
    
    primary key (ID_usuario),
    
    constraint chk_usuario_fechas check (fecha_nacimiento < fecha_registro),
    constraint unq_correo unique (correo)
);



-- tabla tipoactividad. id, nombre, descripcion
-- constraints:
-- el nombre del tipo de actividad debe ser unico, para que no hayan un monton de tipo "carreras" o "calentamiento"
create table tipo_actividad (
	ID_tipo					INT, 
	nombre_tipo_actividad	VARCHAR(100) not null,	
	descripcion				VARCHAR(100) not null,
	
	primary key (ID_tipo),
	constraint unq_nombre_tipoactividad unique (nombre_tipo_actividad)
);
	
	
	
	
-- tabla ruta. id, nombre, ubicacion, desnivel, tiposuperficie
-- constraints:
-- nombre de ruta debe ser unico para que no hayan varios nombres para la misma ruta
-- la distancia de la ruta no puede ser negativa o 0
-- el desnivel de la ruta no puede ser negativa pero si puede ser 0 (plano) 
-- el tipo de superficie solo pueden ser esas 5 ('asfalto', 'tierra', 'pista', 'arena', 'caminadora')
create table ruta (
	ID_ruta 		SERIAL, 
	nombre_ruta 	VARCHAR(100) not null,
	ubicacion 		VARCHAR(100) not null,
	desnivel  		INT not null default 0,
	tipo_superficie VARCHAR(100) not null,
	distancia_km 	INT not null,
	
	primary key (ID_ruta),
	
	constraint unq_nombre_ruta unique (nombre_ruta),
	constraint chk_ruta_distancia check (distancia_km > 0),
	constraint chk_ruta_desnivel check (desnivel >= 0),
	constraint chk_ruta_superficie check (tipo_superficie in ('asfalto', 'tierra', 'pista', 'arena', 'caminadora'))
);


-- tabla evento. Id, nombre, fecha, hora inicio, hora cierre, ubicacion
-- constraints:
-- la hora de inicio debe ser menor que la hora de cierre (debe ser antes la hora de inicio)
-- si se borra un tipo de actividad cuyo evento esta asociada a esa actividad se detiene el borrado
-- *ejemplo si hay un evento (marathon costa rica) y es de tipo carrera y se intenta borrar carrera (cuando el evento ya esta asociada al tipo) se detiene el borrado
create table evento (
	ID_evento 		SERIAL,
	ID_tipo			INT not null,
	nombre_evento   VARCHAR(100) not null,
	fecha 			DATE not null,
	hora_inicio 	TIME not null,
	hora_cierre 	TIME not null,
	ubicacion		VARCHAR(100) not null,
	
	primary key (ID_evento),
	
	constraint chk_evento_horas check (hora_cierre > hora_inicio),
	
	constraint fk_evento_tipo foreign key (ID_tipo) references tipo_actividad (ID_tipo) on delete restrict 
);


-- tabla sesion id, IDusuario, IDtipo, IDruta, fecha, hora inicio y final, y si es interior o exterior
-- constraints:
-- la hora de inicio debe ser menor que la hora de finalizacion 
-- si la sesion es adentro (caminadora) no hay ruta, pero si es exterior (not es_interior) debe haber una ruta
-- si se elimina el dato de un usuario, se elimina todas las sesiones que vienen con el, de nada sirve guardar sesiones de usuarios que ya no existen 
-- pero no se puede eliminar un tipo de actividad, porque las sesiones dependen de ello, no podemos borrar tipo carrera porque se irian varias sesiones de ese mismo tipo
-- lo mismo pasa con las rutas
create table sesion (
	ID_sesion 			SERIAL,
	ID_usuario 			INT not null,
	ID_tipo 			INT not null,
	ID_ruta 			INT, 
	fecha 				DATE not null,
	hora_inicio 		TIME not null,
	hora_finalizacion 	TIME not null,
	es_interior 		BOOL not null default false,
	
	primary key (ID_sesion),
	
	constraint chk_sesion_horas check (hora_finalizacion > hora_inicio ),
	constraint chk_sesion_interior_sin_ruta check (not es_interior or ID_ruta is null),
	
	constraint fk_sesion_usuario foreign key (ID_usuario) references usuario (ID_usuario) on delete cascade,
	constraint fk_sesion_tipo foreign key (ID_tipo) references tipo_actividad (ID_tipo) on delete restrict,
	constraint fk_sesion_ruta foreign key (ID_ruta) references ruta (ID_ruta) on delete restrict
);



-- tabla metrica (entidad debil, lleva el id de sesion) IDsesion, distancia_km, bpm_promedio, calorias, (el ritmo se calcula a partir del tiempo y la distancia)
-- constraints:
-- la distancia debe ser positiva
-- los bpm deben estar en los rangos normales
-- calorias positivas
-- si se elimina sesion, se elimina la metrica, primero porque es una entidad debil metrica, segundo porque nada se hace con la informacion de metrica si no hay una sesion relacionada
create table metrica(
	ID_sesion INT not null,
	distancia_km INT not null, 
	bpm_promedio INT,
	calorias INT, 
	
	primary key (ID_sesion),
	
	constraint chk_metrica_distancia check (distancia_km > 0),
	constraint chk_metrica_bpm check (bpm_promedio > 25 and bpm_promedio < 240),
	constraint chk_metrica_calorias check (calorias >= 0),
	
	constraint fk_metrica_sesion foreign key (ID_sesion) references sesion (ID_sesion) on delete cascade
);
	


-- tabla dispositivo. 
-- constraints:
create table dispositivo ( 
	ID_dispositivo SERIAL,
	ID_usuario INT not null,
	tipo VARCHAR(100) not null,
	marca VARCHAR(100) not null,
	modelo VARCHAR(100) not null,
	anio INT not null, 
	
	primary key (ID_dispositivo),
	
	constraint chk_dispositivo_tipo check (tipo in ('reloj', 'banda cardiaca', 'celular', 'caminadora','ciclocomputador', 'rodillo')),
	constraint chk_dispositivo_anio check (anio > 1950 and anio < 2030),
	
	constraint fk_dispositivo_usuario foreign key (ID_usuario) references usuario (ID_usuario) on delete cascade

);



-- tabla sesionXdispositivo. -- N a M 
-- IDsesion, IDdispositivo (tabla intermedia de la relacion "usa" del diagrama)
-- constraints:
-- la llave primaria es la combinacion de los dos ids, asi no se puede meter el mismo dispositivo dos veces en la misma sesion
-- si se elimina una sesion, se eliminan los registros de que dispositivos se usaron en ella, no sirven de nada sin la sesion
-- si se elimina un dispositivo, se borra de las sesiones donde se uso (la sesion se queda, solo se pierde el dato de que se uso ese dispositivo)
-- * ojo: la base no revisa que el dispositivo sea del mismo usuario de la sesion, eso hay que cuidarlo al meter los datos
create table sesionXdispositivo ( 
	ID_sesion 		INT not null,
	ID_dispositivo 	INT not null,
	
	primary key (ID_sesion, ID_dispositivo),
	
	constraint fk_sesionxdispositivo_sesion foreign key (ID_sesion) references sesion (ID_sesion) on delete cascade,
	constraint fk_sesionxdispositivo_dispositivo foreign key (ID_dispositivo) references dispositivo (ID_dispositivo) on delete cascade
);



-- tabla inscripcion. -- N a M
-- IDusuario, IDevento, dorsal, tiempo, posicion (tabla intermedia de la relacion "inscribe", el dorsal es el "identificador" del diagrama)
-- constraints:
-- la llave primaria es usuario + evento, una persona no se puede inscribir dos veces en el mismo evento
-- el dorsal (el numero que lleva el corredor) no se puede repetir dentro del mismo evento, pero si en eventos distintos
-- el dorsal y la posicion tienen que ser positivos, no existe el dorsal 0 ni el lugar 0
-- el tiempo y la posicion pueden quedar vacios, por si la persona se inscribio pero el evento no ha pasado o no termino la carrera
-- si tiene tiempo, debe ser mayor a 0
-- si se elimina un usuario o un evento, se borran sus inscripciones, no sirven de nada sin alguno de los dos
-- * tiempo es INTERVAL porque es una duracion (ej. 01:45:30), no una hora del dia como TIME
create table inscripcion (
	ID_usuario 	INT not null,
	ID_evento 	INT not null,
	dorsal 		INT not null,
	tiempo 		INTERVAL,
	posicion 	INT,
	
	primary key (ID_usuario, ID_evento),
	
	constraint unq_inscripcion_dorsal unique (ID_evento, dorsal),
	constraint chk_inscripcion_dorsal check (dorsal > 0),
	constraint chk_inscripcion_tiempo check (tiempo > interval '0'),
	constraint chk_inscripcion_posicion check (posicion > 0),
	
	constraint fk_inscripcion_usuario foreign key (ID_usuario) references usuario (ID_usuario) on delete cascade,
	constraint fk_inscripcion_evento foreign key (ID_evento) references evento (ID_evento) on delete cascade
);



-- tabla meta. IDmeta, IDusuario, IDevento, descripcion, valor objetivo, unidad, fecha inicio, fecha finalizacion y estado
-- constraints:
-- la fecha de finalizacion no puede ser antes que la de inicio (si puede ser el mismo dia)
-- el valor objetivo debe ser positivo, no tiene sentido una meta de 0 km
-- la unidad solo puede ser esas 4 ('km', 'sesiones', 'minutos', 'horas'), asi la meta se puede medir (ej. 100 km en un mes, 12 sesiones)
-- el estado solo puede ser esos 4 ('pendiente', 'en_progreso', 'cumplida', 'abandonada'), si no se pone nada arranca en pendiente
-- el evento es opcional (puede ser null), no todas las metas son para una carrera, puede ser solo "correr 50 km este mes"
-- si se elimina un usuario se eliminan sus metas, de nada sirven metas de usuarios que ya no existen
-- si se elimina el evento la meta no se borra, solo se queda sin evento (set null), la meta sigue siendo del usuario
create table meta (
	ID_meta 			SERIAL,
	ID_usuario 			INT not null,
	ID_evento 			INT,
	descripcion 		VARCHAR(200) not null,
	valor_objetivo 		NUMERIC(8,2) not null,
	unidad 				VARCHAR(100) not null,
	fecha_inicio 		DATE not null,
	fecha_finalizacion 	DATE not null,
	estado 				VARCHAR(100) not null default 'pendiente',
	
	primary key (ID_meta),
	
	constraint chk_meta_fechas check (fecha_finalizacion >= fecha_inicio),
	constraint chk_meta_valor check (valor_objetivo > 0),
	constraint chk_meta_unidad check (unidad in ('km', 'sesiones', 'minutos', 'horas')),
	constraint chk_meta_estado check (estado in ('pendiente', 'en_progreso', 'cumplida', 'abandonada')),
	
	constraint fk_meta_usuario foreign key (ID_usuario) references usuario (ID_usuario) on delete cascade,
	constraint fk_meta_evento foreign key (ID_evento) references evento (ID_evento) on delete set null
);



-- tabla valoracion ruta. -- N a M
-- IDusuario, IDruta, calificacion, comentario, fecha (tabla intermedia de la relacion "valora" entre usuario y ruta)
-- * si hay que meterla, la especificacion general pide "clasificaciones o valoraciones personales" y es la unica tabla que lo cubre
-- constraints:
-- la llave primaria es usuario + ruta, cada persona califica una ruta una sola vez (si cambia de opinion se actualiza, no se mete otra)
-- la calificacion va de 1 a 5 (como las estrellitas)
-- el comentario es opcional
-- si se elimina un usuario se borran sus valoraciones
-- si se elimina una ruta se borran sus valoraciones, no sirve de nada calificar una ruta que ya no existe
create table valoracion_ruta (
	ID_usuario 		INT not null,
	ID_ruta 		INT not null,
	calificacion 	INT not null,
	comentario 		VARCHAR(200),
	fecha 			DATE not null default CURRENT_DATE,
	
	primary key (ID_usuario, ID_ruta),
	
	constraint chk_valoracion_calificacion check (calificacion between 1 and 5),
	
	constraint fk_valoracion_usuario foreign key (ID_usuario) references usuario (ID_usuario) on delete cascade,
	constraint fk_valoracion_ruta foreign key (ID_ruta) references ruta (ID_ruta) on delete cascade
);






-- vistas 
create or replace view vw_metricas_entreno as --vistas de entreno para pdoer ver entrenos de un usuario, con sus metricas y calculos de ritmo y velocidad
select 
	u.ID_usuario,
	u.nombre_completo 			as usuario,
	s.ID_sesion,
	s.fecha,
	s.hora_inicio,
	s.hora_finalizacion,
	t.nombre_tipo_actividad 	as tipo_actividad,
	case when s.es_interior then 'interior' else 'exterior' end as entorno,
	r.nombre_ruta 				as ruta,
	m.distancia_km,
	m.bpm_promedio,
	m.calorias,
	s.hora_finalizacion - s.hora_inicio as duracion,
	date_trunc('second', (s.hora_finalizacion - s.hora_inicio) / m.distancia_km) as ritmo_por_km,
	round(m.distancia_km / (extract(epoch from (s.hora_finalizacion - s.hora_inicio)) / 3600), 2) as velocidad_kmh -- ojo aca se calcula el ritmo, no se guarda en la tabla metrica
	
	from sesion s
		join usuario u 			on u.ID_usuario = s.ID_usuario
		join tipo_actividad t 	on t.ID_tipo = s.ID_tipo
		left join ruta r 		on r.ID_ruta = s.ID_ruta
		left join metrica m 	on m.ID_sesion = s.ID_sesion;


-- select * from vw_metricas_entreno;