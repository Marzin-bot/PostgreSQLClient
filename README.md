# PostgreSQLClient
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

**Property Descriptions**
- `float` PROTOCOL_VERSION *const*```

| Default | `3.0` |

Version number (minor.major) of the PostgreSQL protocol used when connecting to the backend

**Method Descriptions**
not finalized

**Signal Descriptions**
not finalized
