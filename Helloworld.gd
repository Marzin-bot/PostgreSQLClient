extends Node

var database := PostgreSQLClient.new()

const USER = "Samuel"
const PASSWORD = "my_password"
const HOST = "localhost"
const PORT = 5432 # Default postgres port
const DATABASE = "my_database"


func _init() -> void:
	var _error := database.connect("connection_established", self, "_executer")
	_error = database.connect("connection_closed", self, "_close")
	
	#Connection to the database
	_error = database.connect_to_host("postgresql://%s:%s@%s:%d/%s" % [USER, PASSWORD, HOST, PORT, DATABASE])


func _executer() -> void:
	var data := database.execute("""
		BEGIN;
		/*Helloworld*/
		SELECT concat('Hello', 'World');
		COMMIT;
	""")

	# note: the "BEGIN" and "COMMIT" commands return empty values
	print(data)

	database.close()


func _close(clean_closure := true) -> void:
	prints("DB CLOSE", clean_closure)


func _exit_tree() -> void:
	database.close()
