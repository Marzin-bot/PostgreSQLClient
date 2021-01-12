extends Node

var database = PostgreSQLClient.new()

func _init():
	database.connect("connection_established", self, "_executer")
	database.connect("connection_closed", self, "_close")
	
	#Connection to the database
	var _error = database.connect_to_host("postgresql://user:passworld@127.0.0.1:5432/database_name")


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
