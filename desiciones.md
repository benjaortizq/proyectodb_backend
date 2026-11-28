1. solo los Administradores definiens eventos 
2. Un usuario si puede registrar varias metas al mismo evento . 

Base: /api
 
Quién puede llamar cada endpoint:
  [público]   sin login
  [logueado]  cualquier usuario con sesión iniciada
  [dueño]     el usuario logueado, sobre sus propias cosas
              (el ID_usuario sale del login, no del body)
  [admin]     el usuario está en la tabla administrador
 
Si la BD frena un DELETE por restrict, a Spring le llega una
DataIntegrityViolationException: devolverla como 409.
 
 
USUARIOS
--------
POST    /api/usuarios       [público]
        Registrarse. fecha_registro la pone la BD.
GET     /api/usuarios       [admin]
GET     /api/usuarios/{id}  [dueño o admin]
        Incluir si es admin (le sirve al frontend).
PUT     /api/usuarios/{id}  [dueño]
DELETE  /api/usuarios/{id}  [dueño o admin]
        Borra en cascada todo lo suyo. 409 si es admin con eventos.
 
 
ADMINISTRADORES (tabla nueva)
-----------------------------
GET     /api/administradores              [admin]
POST    /api/administradores              [admin]
        Body: ID_usuario. Vuelve admin a un usuario que ya existe.
        El primer admin se mete a mano en el script de carga.
DELETE  /api/administradores/{idUsuario}  [admin]
        409 si todavía tiene eventos a su nombre.
 
 
TIPOS DE ACTIVIDAD
------------------
GET     /api/tipos-actividad       [público]
GET     /api/tipos-actividad/{id}  [público]
POST    /api/tipos-actividad       [admin]
        El body trae ID_tipo (no es SERIAL).
PUT     /api/tipos-actividad/{id}  [admin]
DELETE  /api/tipos-actividad/{id}  [admin]
        409 si hay eventos o sesiones de ese tipo.
 
 
RUTAS
-----
GET     /api/rutas       [público]
        Filtros: ?superficie=&ubicacion=
GET     /api/rutas/{id}  [público]
        Puede traer el promedio de calificación.
POST    /api/rutas       [logueado]
PUT     /api/rutas/{id}  [admin]
        Solo admin porque la ruta no guarda quién la creó.
DELETE  /api/rutas/{id}  [admin]
        409 si alguna sesión la usa. Sus valoraciones se borran solas.
 
 
VALORACIONES DE RUTA (Valora)
-----------------------------
GET     /api/rutas/{idRuta}/valoraciones              [público]
GET     /api/usuarios/{id}/valoraciones               [público]
PUT     /api/rutas/{idRuta}/valoraciones/{idUsuario}  [dueño]
        Crea o actualiza (insert ... on conflict do update),
        porque la PK es usuario + ruta.
DELETE  /api/rutas/{idRuta}/valoraciones/{idUsuario}  [dueño]
 
 
EVENTOS
-------
GET     /api/eventos       [público]
        Filtros: ?tipo=&desde=&hasta=
GET     /api/eventos/{id}  [público]
POST    /api/eventos       [admin]
        ID_admin = el admin logueado. Si no es admin, la BD también lo rechaza.
PUT     /api/eventos/{id}  [admin]
        También sirve para pasarle el evento a otro admin.
DELETE  /api/eventos/{id}  [admin]
        Borra las inscripciones; las metas y sesiones quedan sin evento.
 
 
INSCRIPCIONES (Inscribe)
------------------------
GET     /api/eventos/{idEvento}/inscripciones              [público]
        Inscritos y resultados (?orden=posicion).
GET     /api/usuarios/{id}/inscripciones                   [dueño]
        Los eventos en los que está inscrito.
POST    /api/eventos/{idEvento}/inscripciones              [logueado]
        Body: dorsal. 409 si ya está inscrito o el dorsal ya está tomado.
PATCH   /api/eventos/{idEvento}/inscripciones/{idUsuario}  [admin]
        Cargar tiempo y posicion.
DELETE  /api/eventos/{idEvento}/inscripciones/{idUsuario}  [dueño o admin]
        Desinscribirse.
 
 
SESIONES (ya traen las métricas)
--------------------------------
GET     /api/usuarios/{id}/sesiones  [dueño]
        Sale de vw_metricas_entreno (trae duración, ritmo y velocidad).
        Filtros: ?desde=&hasta=&tipo=&evento=
GET     /api/sesiones/{id}           [dueño]
        También sale de la vista.
POST    /api/sesiones                [logueado]
        Body con distancia_km, bpm_promedio y calorias.
        ID_ruta obligatorio si es exterior.
        Si trae ID_evento, la API revisa que esté inscrito (la BD no).
PUT     /api/sesiones/{id}           [dueño]
DELETE  /api/sesiones/{id}           [dueño]
        Se borran también sus registros de dispositivos.
 
 
DISPOSITIVOS
------------
GET     /api/usuarios/{id}/dispositivos  [dueño]
GET     /api/dispositivos/{id}           [dueño]
POST    /api/dispositivos                [logueado]
PUT     /api/dispositivos/{id}           [dueño]
DELETE  /api/dispositivos/{id}           [dueño]
        Se quita de las sesiones donde se usó; las sesiones quedan.
 
 
DISPOSITIVOS DE UNA SESIÓN (Usa)
--------------------------------
GET     /api/sesiones/{idSesion}/dispositivos                  [dueño]
POST    /api/sesiones/{idSesion}/dispositivos                  [dueño]
        Body: ID_dispositivo. La API revisa que el dispositivo sea del
        mismo usuario de la sesión (la BD no).
DELETE  /api/sesiones/{idSesion}/dispositivos/{idDispositivo}  [dueño]
 
 
METAS
-----
GET     /api/usuarios/{id}/metas  [dueño]
        Filtros: ?estado=&evento=
GET     /api/metas/{id}           [dueño]
GET     /api/metas/{id}/progreso  [dueño]
        Suma las sesiones del usuario entre fecha_inicio y fecha_finalizacion
        según la unidad (km, sesiones, minutos u horas).
POST    /api/metas                [logueado]
        ID_evento opcional. Se pueden poner varias metas para el mismo evento.
PUT     /api/metas/{id}           [dueño]
        Incluye cambiar el estado.
DELETE  /api/metas/{id}           [dueño]
 
 
NOTAS
-----
- La tabla usuario no tiene contraseña. Para que lo de [admin] funcione, la
  API tiene que saber quién llama: si van a hacer login, falta una columna
  contrasena_hash en usuario y un POST /api/auth/login.
- Cosas que valida la API porque la BD no las revisa:
  * que el dispositivo que se agrega a una sesión sea del mismo usuario
  * que si una sesión trae ID_evento, el usuario esté inscrito en ese evento