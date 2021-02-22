extends Node

var database := PostgreSQLClient.new()

func _init() -> void:
	database.connect("connection_established", self, "_executer")
	database.connect("connection_closed", self, "_close")
	
	#Connection to the database
	var _error = database.connect_to_host("postgresql://user:passworld@localhost:5432/database_name")


func _executer() -> void:
	var data = database.execute("""
		BEGIN;
		/*Helloworld*/
		SELECT concat('Hello', 'World');
		COMMIT;
	""")

	# note: the "BEGIN" and "COMMIT" commands return empty values
	print(data)

	database.close()


func _close(clean_closure := true) -> void:
	prints("BD CLOSE", clean_closure)


func _exit_tree() -> void:
	database.close()
