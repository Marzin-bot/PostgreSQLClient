# PostgreSQLClient for Godot Engine (GDscript)
<p align="center">
	<img src="./icon.svg">
</p>
Godot PostgreSQL Client is a GDscript script / class that allows you to connect to a Postgres backend and run SQL commands there. It is able to send data and receive it from the backend. Useful for managing player user data on a multiplayer game, by saving a large amount of data on a dedicated Postgres server from GDscript.

The class is written in pure GDScript which allows it not to depend on GDExtension. This makes it ultra portable for many platforms. You can see a taste of using the Postgresql connector for Godot 4.x in the "Helloworld.gd" file.

/!\ You should not use this version of postgreSQLClient as it is not finalized and may work differently in the future. While waiting for its stable version, please use the module version in the main branch. /!\

INSTALLATION PROCEDURE:
=======================
It is assumed that you have installed the latest version of PostgreSQL and that you have created a database.
Access Godot's AssetLib catalog search for PostgreSQLClient. Include the Postgres.gd file in your project (only this file is really needed).

OR

Download the file "Postgres.gd" then include it in your Godot project folders ("res: //").

The PostgreSQLClient class should now be accessible from any GDscript script. Otherwise, set the script to "Auto load" in your project settings.

HOW TO USE?:
====================================
Find an example of minimalist use in the <a href="./Helloworld.gd">Helloworld.gd</a> file. Other examples will be provided later.

DONATION:
====================================
This project is maintained by an enthusiast who develops it in his spare time. If you feel like it, you can buy me a cup of coffee.

<p align="center">
	<a href="https://paypal.me/MarzinSamuel"><img src="https://raw.githubusercontent.com/Marzin-bot/Ressources/main/paypal_btn_donateCC_LG_1.gif" alt="Donation PayPal"></a>
</p>

FREQUENTLY ASKED QUESTIONS
==========================

I get the error "The connection attempt failed. The backend does not want to establish a secure SSL/TLS connection", what does this mean?

---> please visit this link to understand:
https://github.com/Marzin-bot/PostgreSQLClient/issues/29


PostgreSQLClient DOCUMENTATION (NOT FINALIZED):
====================================

**PROPERTIES:**

| Type | Properties | Default value |
| --- | --- | --- |
| `float` | PROTOCOL_VERSION *const* | 3.0 |
| `Dictionary` | parameter_status *reader alone* | {} |

**METHODS:**

| Type | Method |
| --- | --- |
| `Error` | connect_to_host(url: String, secure_connection_method: PostgreSQLClient.SecureConnectionMethod = SecureConnectionMethod.NONE, connect_timeout: int = 30) |
| `Status` | get_status() |
| `Error` | execute(sql: String) |
| `void` | rollback(process_id: int, process_key: int, secure_connection_method: int = SecureConnectionMethod.NONE) |
| `void` | close(clean_closure: bool = true) |
| `void` | poll() |

**SIGNALS:**

| Signal |
| --- |
| connection_closed(was_clean_close: bool) |
| connection_error() |
| authentication_error(error_object: Dictionnary) |
| connection_established() |
| data_received(error_object: Dictionary, transaction_status: PostgreSQLClient.TransactionStatus, datas: Array) |

**ENUMARATIONS:**

`enum` SecureConnectionMethod

- NONE = 0 --- Represent a connection that is not secure.
- SSL = 1 --- Represents a connection secured by an overlay of the SSL/TLS protocol.
- GSSAPI = 2 --- Represents a connection secured by an overlay of the GSSAPI protocol.

---

`enum` Status

- STATUS_DISCONNECTED = 0 --- A status representing a `PostgreSQLClient` that is disconnected.
- STATUS_CONNECTING = 1 --- A status representing a `PostgreSQLClient` that is connecting to a host.
- STATUS_CONNECTED = 2 --- A status representing a `PostgreSQLClient` that is connected to a host.
- STATUS_ERROR = 3 --- A status representing a `PostgreSQLClient` in error state.

NOTE: The Status enumeration may not be exposed in future versions.

---

`enum` DataTypePostgreSQL

- BOOLEAN = 16 --- Postgresql data type of type `boolean`.
- SMALLINT = 21 --- Postgresql data type of type `smallint`.
- INTEGER = 23 --- Postgresql data type of type `integer`.
- BIGINT = 20 --- Postgresql data type of type `bigint`.
- REAL = 700 --- Postgresql data type of type `real`.
- DOUBLE_PRECISION = 701 --- Postgresql data type of type `double precision`.
- TEXT = 25 --- Postgresql data type of type `text`.
- CHARACTER = 1042 --- Postgresql data type of type `character` *alias* `char`.
- CHARACTER_VARYING = 3802 --- Postgresql data type of type `character varying` *alias* `varchar`.
- JSON_ = 114 --- Postgresql data type of type `json`.
- JSONB = 3802 --- Postgresql data type of type `jsonb`.
- XML = 142 --- Postgresql data type of type `xml`.
- BITEA = 17 --- Postgresql data type of type `bitea`.
- CIDR = 650 --- Postgresql data type of type `cidr`.
- INET = 869 --- Postgresql data type of type `inet`.
- MACADDR = 829 --- Postgresql data type of type `macaddr`.
- MACADDR8 = 774 --- Postgresql data type of type `macaddr8`.
- BIT = 1560 --- Postgresql data type of type `bit`.
- BIT_VARYING = 1562 --- Postgresql data type of type `bit varying`.
- UUID = 2950 --- Postgresql data type of type `uuid`.
- POINT = 600 --- Postgresql data type of type `point`.
- BOX = 603 --- Postgresql data type of type `box`.
- LSEG = 601 --- Postgresql data type of type `lseg`.
- LINE = 628 --- Postgresql data type of type `line`.
- CIRCLE = 718 --- Postgresql data type of type `circle`.
- DATE = 1082 --- Postgresql data type of type `date`.
- TIME = 1266 --- Postgresql data type of type `time`.

NOTE: Not all PostgreSQL data types are supported by PostgreSQLClient, but will be in a future release.

---

`enum` TransactionStatus

- NOT_IN_A_TRANSACTION_BLOCK = 0 --- Represents one or more querys that is not in a transaction block.
- IN_A_TRANSACTION_BLOCK = 1 --- Represents one or more querys that are in a transaction block.
- IN_A_FAILED_TRANSACTION_BLOCK = 2 --- Represents one or more querys in a transaction block with a error state.

---

**Property Descriptions**

- `float`  PROTOCOL_VERSION *const*

Default value: `3.0`

Version number (minor.major) of the PostgreSQL protocol used when connecting to the backend

---

- `Dictionary` parameter_status *reader alone*

Default value: `{}`

A dictionary that contains various information about the execution state of the server. For security reasons the dictionary is always empty if the frontend is disconnected from the backend and updates once the connection is established.

Noted that the server is free to return whatever value it wants. Always remember to check the presence of the key before accessing the associated value.

Example of a typical value that a backend might return. Values may differ depending on the backend:
```
{"DateStyle":"ISO, DMY", "IntervalStyle":"postgres", "TimeZone":"Europe/Paris", "application_name":"", "client_encoding":"UTF8", "integer_datetimes":"on", "is_superuser":"off", "server_encoding":"UTF8", "server_version":"12.7 (Ubuntu 12.7-0ubuntu0.20.04.1)", "session_authorization":"samuel", "standard_conforming_strings":"on"}
```

---

**Method Descriptions**
- `Error`  connect_to_host(url: String, secure_connection_method: int = SecureConnectionMethod.NONE, connect_timeout: int = 30)

Allows you to connect to a Postgresql backend at the specified `url`.

The `url` parameter is a PostgreSQL URL ideally in the form "postgresql://user:password@host:port/databasename".
All other PostgreSQL URL syntaxes specified in this page [https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING] are not yet fully supported.

Noted that the default port for PostgreSQL is `5432`.

The `secure_connection_method` parameter specifies the secure connection method of the frontend that it will try to establish with the backend.
If the server is unfavorable, the connection will fail. Most of the time, all PostgreSQL backends are good at establishing an SSL / TLS connection.
Old servers can be an exception.

The `connect_timeout` parameter specifies the maximum duration of the connection process. If the backend does not respond during this time, the connection will be considered to have failed.

---

- `Error`  execute(sql: String)

Allows to send an SQL string to the backend that should run.
The `sql` parameter can contain one or more valid SQL statements.

Returns an error which can take the value:

- `OK`, If the value is sent (does not mean that the sql string is valid and does not necessarily mean that the backend will agree to execute the query).
- `ERR_CONNECTION_ERROR`, If the fontend is not connected to backend.
- `ERR_BUSY`, If the frontend or the backend has not finished processing the previous request. If it is, repeat the request until you get `OK`.

---

- `Status`  get_status()

Returns the status of the connection (see the Status enumeration).
Note that you should be able to use PostgreSQLCient without using it.
The method may no longer be exposed in the future version.

---

- `void`  rollback(process_id : int, process_key : int, secure_connection_method: int = SecureConnectionMethod.NONE)

Do not use because it is too unstable, will be subject to modification in future versions.

---

- `void`  close(clean_closure: bool = true)

Allows you to close the connection with the backend. If clean_closure is `true`, the frontend will notify the backend that it requests to close the connection. If `false`, the frontend forcibly closes the connection without notifying the backend (not recommended except in exceptional cases).

Has no effect if the frontend is not already connected to the backend.

---

- `void`  poll()

Poll the connection to check for incoming messages.
Ideally, it should be called before `PostgreSQLClient.execute()` for it to work properly and called frequently in a loop.

---

**Signal Descriptions**
- connection_closed(was_clean_close: bool)

Fires when the connection to the backend closes.
`was_clean_close` is `true` if the connection was closed correctly otherwise `false`.

---

- connection_error()

Do not listen to this signal, does not work. will be subject to change see removed in future versions.

---

authentication_error(error_object: Dictionnary)

Triggered when the authentication process failed during contact with the target backend.
The error_object parameter is a dictionary that contains various information during the nature of the error.

---

- connection_established()

Trigger when the connection between the frontend and the backend is established. This is usually a good time to start making requests to the backend with `execute ()`.

---

- data_received(error_object: Dictionary, transaction_status: PostgreSQLClient.TransactionStatus, datas: Array)

Emitted when data is sent by the backend, usually after using the `execute()` method.
It is also possible for the backend to send data which is not expressly requested by the frontend command flow so you should handle unsolicited messages to avoid any issues.

The `error_object` parameter is a `Dictionary` which contains various information on the execution errors of the last requests made on the backend (usually after using the `execute()` method).
If the dictionary is empty, it means that the backend did not detect any error in the query.

The `datas` parameter is a `Array` of `PostgreSQLQueryResult`. There are as many `PostgreSQLQueryResult` elements in the array as there are SQL statements in `sql` (except in exceptional cases).

---

DOCUMENTATION PostgreSQLQueryResult:
====================================================
**Descriptions**

The `PostgreSQLQueryResult` class is a subclass of `PostgreSQLClient` which is not intended to be created manually. It represents the result of an SQL query and provides an information and method report
 to use the result of the query.

**PROPERTIES:**

| Type | Properties | Default value |
| --- | --- | --- |
| `int` | number_of_fields_in_a_row *reader alone* | 0 |
| `Array` | row_description *reader alone* | \[\] |
| `Array` | data_row *reader alone* | \[\] |
| `Array` | raw_data_row *reader alone* | \[\] |
| `String` | command_tag *reader alone* | \"\" |
| `Dictionary` | notice *reader alone* | {} |

**METHODS:**

| Type | Method |
| --- | --- |
| `Array` | get_field_values(field_name: String) |
| `PostgreSQLClient.DataTypePostgreSQL` | field_data_type(field_name: String) |

---

**Property Descriptions**

`int`  number_of_fields_in_a_row *const*

Default value: `0`

Specifies the number of fields in a row (can be zero).

---

`Array`  row_description *const*

Default value: `[]`

An array that contains dictionaries. these dictionaries represent the description of the rows where the query was executed. The number of dictionary depends on the number of fields resulting from the result of the query which was executed.

Each dictionary is structured like this:

```
{
	"field_name": field_name,
	"table_object_id": table_object_id,
	"column_index": column_index,
	"type_object_id": type_object_id,
	"data_type_size": data_type_size,
	"type_modifier": type_modifier,
	"format_code": format_code
}
```

- Where the `field_name` value is a `String` that represents the name of the field.
- Where the value `table object_id` is an `int` which represents the identifier of the table object whether the field can be identified as a column from a specific table; otherwise `0`.
- Where the `column_index` value is an `int` which represents the attribute number of the column if the field can be identified as a column from a specific table; otherwise zero.
- Where the `type_object_id` value is an `PostgreSQLClient.DataTypePostgreSQL` which represents the object ID of the data type of the field.
- Where the `data_type_size` value is an` int` which represents the size of the data type. Note: that negative values indicate variable width types.
- Where the `type_modifier` value is an` int` which represents the type modifier. Note: The meaning of the modifier is type specific.
- Where the `format_code` value is an` int` which represents the format code used for the field. Currently will be `0` (text) or` 1` (binary). In a RowDescription returned by the instruction variant of Describe, the format code is not yet known and will always be zero. This value is low-level PostgreSQL protocol information that is not useful in most cases. You can ignore this value.

---

`Array`  data_row *const*

Default value: `[]`

An `Array` that contains sub-arrays. these sub-arrays represent for most of the queries the rows of the table where the query was executed. The number of sub-tables depends on the query that has been made. These sub-arrays contain as many elements as `number_of_fields_in_a_row`. These elements are native GDscript types that represent the data resulting from the query.

Example return value:

```
[[1, "Hello my id is 1"], [2, "Hello my id is 2"], [3, "Hello my id is 3"]]
```
There are 3 rows.
Each row contains the value of 2 fields: The row identifier and a character string.


**Table of type PostgreSQL equivalent to Godot**
| Types postgres | Type Godot |
| --- | --- |
| `null` | `null` |
| `smallint`, `integer`, `bigint` | `int` |
| `real`, `double precision` | `float` |
| `text`, `character` *alias* `char`, `character varying` *alias* `varchar`, `json`, `jsonb`, `xml`, `cidr`, `inet`, `macaddr`, `macaddr8`, `bit`, `bit varying`, `uuid`, `date`, `time` | `String` |
| `bitea` | `PackedByteArray` |
| `point` | `Vector2` |
| `box` | `Rect2` |
| `lseg` | `PackedVector2Array` |
| `line`, `circle` | `Vector3` |

Note:
- Not all PostgreSQL types are supported yet.
- I may later change the date and time type to Dictionary, but I'm not sure...

---

`Array`  raw_data_row *const*

Default value: `[]`

Unlike `data_row` which contains elements of native GDscript types, raw_data_row contains the raw data sent by the backend which represents the raw data resulting from the query instead of converting it to a native GDScript type.
Note that the frontend does not check the validity of the data, so you have to check the data manually.
Sub-array data types are of type `String` if `row_description.["format_code"]` is `0` and of type `PackedByteArray` if `1`.

---

`String`  command_tag *const*

Default value: `""`

This is usually a single word that identifies which SQL command was completed.

---

`Dictionary` notice *const*

Default value: `{}`

Represents various information about the execution status of the query notified by the backend. Can be empty.

---

**Method Descriptions**

`Array`  get_field_values(field_name: String)

Returns all the values of a field.
`field_name` is the name of the field on which we get the values. Can be empty if the field name is unknown. The `field_name` parameter is case sensitive.

---

`PostgreSQLClient.DataTypePostgreSQL`  field_data_type(field_name: String)

Returns the object ID of the data type of the field.
`field_name` is the name of the field whose type we get. Can return `-1` if the field name is unknown. The `field_name` parameter is case sensitive.

Contacts:
=======================
- Discord: Kuwazy#8194
- email: sammarzin22@gmail.com
