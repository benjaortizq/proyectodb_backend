

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



-- tabla administrador. IDusuario  (NUEVA, sale de la regla "solo los administradores definen eventos")
-- un administrador es un usuario con permisos extra (especializacion de usuario), por eso su llave es el mismo ID del usuario
-- constraints:
-- la llave primaria es el ID del usuario, asi nadie puede ser admin dos veces
-- si se elimina el usuario se le quita lo de admin (cascade), pero si tiene eventos a su nombre la base no deja (ver tabla evento)
-- * el primer admin se mete a mano, ej. insert into administrador values (1);
create table administrador (
	ID_usuario 	INT not null,

	primary key (ID_usuario),

	constraint fk_administrador_usuario foreign key (ID_usuario) references usuario (ID_usuario) on delete cascade
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




-- tabla ruta. id, nombre, ubicacion, desnivel, tiposuperficie, distancia
-- constraints:
-- nombre de ruta debe ser unico para que no hayan varios nombres para la misma ruta
-- la distancia de la ruta no puede ser negativa o 0
-- el desnivel de la ruta no puede ser negativa pero si puede ser 0 (plano)
-- el tipo de superficie solo pueden ser esas 4 ('asfalto', 'tierra', 'pista', 'arena')
-- * se quito 'caminadora': una sesion en caminadora es interior y las sesiones interiores no llevan ruta, entonces nunca se iba a usar
-- * la distancia es NUMERIC(6,2) y no INT, con INT no se puede guardar una ruta de 5.5 km
create table ruta (
	ID_ruta 		SERIAL,
	nombre_ruta 	VARCHAR(100) not null,
	ubicacion 		VARCHAR(100) not null,
	desnivel  		INT not null default 0,
	tipo_superficie VARCHAR(100) not null,
	distancia_km 	NUMERIC(6,2) not null,

	primary key (ID_ruta),

	constraint unq_nombre_ruta unique (nombre_ruta),
	constraint chk_ruta_distancia check (distancia_km > 0),
	constraint chk_ruta_desnivel check (desnivel >= 0),
	constraint chk_ruta_superficie check (tipo_superficie in ('asfalto', 'tierra', 'pista', 'arena'))
);


-- tabla evento. Id, IDtipo, IDadmin, nombre, fecha, hora inicio, hora cierre, ubicacion
-- constraints:
-- la hora de inicio debe ser menor que la hora de cierre (debe ser antes la hora de inicio)
-- si se borra un tipo de actividad cuyo evento esta asociada a esa actividad se detiene el borrado
-- *ejemplo si hay un evento (marathon costa rica) y es de tipo carrera y se intenta borrar carrera (cuando el evento ya esta asociada al tipo) se detiene el borrado
-- solo los administradores definen eventos: ID_admin apunta a la tabla administrador (no a usuario), entonces si se mete el id de un usuario normal la base lo rechaza
-- si se intenta quitar un admin (o borrar su usuario) que tiene eventos a su nombre se detiene el borrado, primero hay que pasarle los eventos a otro admin
create table evento (
	ID_evento 		SERIAL,
	ID_tipo			INT not null,
	ID_admin		INT not null,
	nombre_evento   VARCHAR(100) not null,
	fecha 			DATE not null,
	hora_inicio 	TIME not null,
	hora_cierre 	TIME not null,
	ubicacion		VARCHAR(100) not null,

	primary key (ID_evento),

	constraint chk_evento_horas check (hora_cierre > hora_inicio),

	constraint fk_evento_tipo foreign key (ID_tipo) references tipo_actividad (ID_tipo) on delete restrict,
	constraint fk_evento_admin foreign key (ID_admin) references administrador (ID_usuario) on delete restrict
);


-- tabla sesion id, IDusuario, IDtipo, IDruta, IDevento, fecha, hora inicio y final, si es interior o exterior, distancia, bpm y calorias
-- * en el diagrama nuevo ya no hay tabla metrica: la distancia, los bpm y las calorias son atributos de la sesion
-- * el ritmo no se guarda, se calcula en la vista con el tiempo y la distancia
-- constraints:
-- la hora de inicio debe ser menor que la hora de finalizacion
-- si la sesion es adentro (caminadora) no hay ruta, pero si es exterior (not es_interior) debe haber una ruta (el check revisa las dos cosas)
-- la distancia debe ser positiva
-- los bpm deben estar en los rangos normales
-- las calorias no pueden ser negativas
-- bpm y calorias pueden quedar vacios, no todos los dispositivos los miden
-- la sesion puede ser de un evento (relacion "es de"), pero es opcional, no todos los entrenos son de un evento
-- si se elimina el dato de un usuario, se elimina todas las sesiones que vienen con el, de nada sirve guardar sesiones de usuarios que ya no existen
-- pero no se puede eliminar un tipo de actividad, porque las sesiones dependen de ello, no podemos borrar tipo carrera porque se irian varias sesiones de ese mismo tipo
-- lo mismo pasa con las rutas
-- si se elimina el evento la sesion no se borra, solo se queda sin evento (set null), el entreno sigue siendo del usuario
-- * ojo: la base no revisa que el usuario este inscrito en el evento de la sesion, eso lo valida la API
create table sesion (
	ID_sesion 			SERIAL,
	ID_usuario 			INT not null,
	ID_tipo 			INT not null,
	ID_ruta 			INT,
	ID_evento 			INT,
	fecha 				DATE not null,
	hora_inicio 		TIME not null,
	hora_finalizacion 	TIME not null,
	es_interior 		BOOL not null default false,
	distancia_km 		NUMERIC(6,2) not null,
	bpm_promedio 		INT,
	calorias 			INT,

	primary key (ID_sesion),

	constraint chk_sesion_horas check (hora_finalizacion > hora_inicio ),
	constraint chk_sesion_interior_ruta check ((es_interior and ID_ruta is null) or (not es_interior and ID_ruta is not null)),
	constraint chk_sesion_distancia check (distancia_km > 0),
	constraint chk_sesion_bpm check (bpm_promedio > 25 and bpm_promedio < 240),
	constraint chk_sesion_calorias check (calorias >= 0),

	constraint fk_sesion_usuario foreign key (ID_usuario) references usuario (ID_usuario) on delete cascade,
	constraint fk_sesion_tipo foreign key (ID_tipo) references tipo_actividad (ID_tipo) on delete restrict,
	constraint fk_sesion_ruta foreign key (ID_ruta) references ruta (ID_ruta) on delete restrict,
	constraint fk_sesion_evento foreign key (ID_evento) references evento (ID_evento) on delete set null
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
-- un usuario si puede tener varias metas para el mismo evento (ej. "300 km antes de la maraton" y "40 sesiones antes de la maraton"), por eso a proposito NO hay unique (ID_usuario, ID_evento)
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
create or replace view vw_metricas_entreno as -- entrenos de cada usuario con sus metricas y el ritmo y la velocidad calculados
select
	u.ID_usuario,
	u.nombre_completo 			as usuario,
	s.ID_sesion,
	s.fecha,
	s.hora_inicio,
	s.hora_finalizacion,
	s.ID_tipo,
	t.nombre_tipo_actividad 	as tipo_actividad,
	case when s.es_interior then 'interior' else 'exterior' end as entorno,
	r.nombre_ruta 				as ruta,
	s.ID_evento,
	e.nombre_evento 			as evento,
	s.distancia_km,
	s.bpm_promedio,
	s.calorias,
	s.hora_finalizacion - s.hora_inicio as duracion,
	date_trunc('second', (s.hora_finalizacion - s.hora_inicio) / s.distancia_km) as ritmo_por_km, -- ojo aca se calcula el ritmo, no se guarda en la tabla sesion
	round((s.distancia_km / (extract(epoch from (s.hora_finalizacion - s.hora_inicio)) / 3600))::numeric, 2) as velocidad_kmh

	from sesion s
		join usuario u 			on u.ID_usuario = s.ID_usuario
		join tipo_actividad t 	on t.ID_tipo = s.ID_tipo
		left join ruta r 		on r.ID_ruta = s.ID_ruta
		left join evento e 		on e.ID_evento = s.ID_evento;


-- select * from vw_metricas_entreno;
