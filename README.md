# PostgreSQLClient for Godot Engine (GDscript)

<img src="./GodotPostgresql.svg">
Godot PostgreSQL Client is a GDscript script / class that allows you to connect to a Postgres backend and run SQL commands there. It is able to send data and receive it from the backend. Useful for managing player user data on a multiplayer game, by saving a large amount of data on a dedicated Postgres server from GDscript.

The class is written in pure GDScript which allows it not to depend on GDNative. This makes it ultra portable for many platforms. You can see a taste of using the Postgresql connector for Godot in the "Helloworld.gd" file.

Currently, the script is not stable and lacks features. So it is not recommended to use it in production at this time however you can test it.

INSTALLATION PROCEDURE:
=======================
It is assumed that you have installed the latest version of PostgreSQL and that you have created a database. Download the file "PostgreSQLClient.gd" then include it in your Godot project folders ("res: //"). The PostgreSQLClient class should now be accessible from any GDscript script. Otherwise, set the script to "Auto load" in your project settings.

CLASS DOCUMENTATION (NOT FINALIZED):
====================================

**PROPERTIES:**

| Type | Properties | Default value |
| --- | --- | --- |
| `float` | PROTOCOL_VERSION *const* | 3.0 |
| `dictionary` | parameter_status *reader alone* | {} |

**METHODS:**

| Type | Method |
| --- | --- |
| `Error` | connect_to_host(url: String, connect_timeout: int = 30) |
| `Array` | execute(sql: String) |
| `void` | rollback(process_id: int, process_key: int) |
| `void` | close(clean_closure: bool = true) |
| `void` | set_ssl_connection() |

**SIGNALS:**

| Signal |
| --- |
| connection_closed(was_clean_close: bool) |
| connection_error() |
| connection_established() |

---

**ENUMARATIONS:**

`enum` DataTypePostgreSQL

- BOOLEAN = 16 ---postgresql data type of type `boolean`.
- SMALLINT = 21, ---postgresql data type of type `smallint`.
- INTEGER = 23, ---postgresql data type of type `integer`.
- BIGINT = 20, ---postgresql data type of type `bigint`.
- REAL = 700, ---postgresql data type of type `real`.
- DOUBLE_PRECISION = 701, ---postgresql data type of type `double precision`.
- TEXT = 25, ---postgresql data type of type `text`.
- JSON = 114, ---postgresql data type of type `json`.
-	JSONB = 3802, ---postgresql data type of type `jsonb`.
-	BITEA = 17, ---postgresql data type of type `bitea`.
-	POINT = 600, ---postgresql data type of type `point`.
-	BOX = 603, ---postgresql data type of type `box`.
-	LSEG = 601, ---postgresql data type of type `lseg`.
-	LINE = 628, ---postgresql data type of type `line`.
-	CIRCLE = 718 ---postgresql data type of type `circle`.

NOTE: Not all types are supported by PostgreSQLClient but will be in a future release with a PostgreSQL to native GDscript type conversion table in the documentation.
This enumeration will be useful in the next version of the Client with the arrival of the PostgreSQLQueryResult object.

--

**Property Descriptions**
- `float`  PROTOCOL_VERSION *const*

Default value: `3.0`

Version number (minor.major) of the PostgreSQL protocol used when connecting to the backend

---

- `dictionary` parameter_status *reader alone*

Default value: {}

A dictionary that contains various information about the state of the server. For security reasons the dictionary is always empty if the frontend is disconnected from the backend and updates once the connection is established.

Noted that the server is free to return whatever value it wants. Always remember to check the presence of the key before accessing the associated value.

Example of a typical value that a backend might return. Values may differ depending on the backend:
```
{"DateStyle":"ISO, DMY", "IntervalStyle":"postgres", "TimeZone":"Europe/Paris", "application_name":"", "client_encoding":"UTF8", "integer_datetimes":"on", "is_superuser":"off", "server_encoding":"UTF8", "server_version":"12.7 (Ubuntu 12.7-0ubuntu0.20.04.1)", "session_authorization":"samuel", "standard_conforming_strings":"on"}
```

---

**Method Descriptions**
- `Error`  connect_to_host(url: String, connect_timeout: int = 30)

Allows you to connect to a Postgresql backend at the specified `url`.

The url parameter is a PostgreSQL url ideally in the form "postgresql://user:password@host:port/databasename".
All other PostgreSQL url syntaxes specified in this page [https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING] are not yet fully supported.

Noted that the default port for PostgreSQL is `5432`.

---

- `Array`  execute(sql: String)

Allows to send an SQL string to the backend that should run.
The `sql` parameter can contain one or more valid SQL statements. Returns an `Array` containing the result of the query (can be empty). The return value will be subject to change in the next version of the PostgreSQL client which will return an array of PostgreSQLQueryResult that will contain much more information about the result of the query.

---

- `void`  rollback(process_id : int, process_key : int)

Do not use because it is too unstable, will be subject to modification in future versions.

---

- `void`  close(clean_closure: bool = true)

Allows you to close the connection with the backend. If clean_closure is `true`, the frontend will notify the backend that it requests to close the connection. If `false`, the frontend forcibly closes the connection without notifying the backend (not recommended sof in exceptional cases).

Has no effect if the frontend is not already connected to the backend.

---

- `void`  set_ssl_connection()

Not working at the moment, don't use it. will be subject to change in future versions.

---

**Signal Descriptions**
- connection_closed(was_clean_close: bool)

Fires when the connection to the backend closes.
`was_clean_close` is `true` if the connection was closed correctly otherwise `false`.

---

- connection_error()

Do not listen to this signal, does not work. will be subject to change see removed in future versions.

---

- connection_established()

Trigger when the connection between the frontend and the backend is established. This is usually a good time to start making requests to the backend with `execute ()`.


Contacts:
=======================
- Discord: Kuwazy#8194
- email: zenpolcorporation@gmail.com
