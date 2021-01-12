extends Node

var database = PostgreSQLClient.new()

func _init():
	database.connect("connection_established", self, "_executer")
	database.connect("connection_closed", self, "_close")
	
	var config = ConfigFile.new()
	
	if config.load(OS.get_executable_path().get_base_dir() + "/settings.cfg") == OK:
		print(database.connect_to_host(config.get_value("database", "url", "")))
	else:
		push_error("Impossible de se connecter a la base de donnée")

func _executer():
	database.execute("""
		BEGIN;
    /*Table des utilisateurs*/
    SELECT concat('Hello', 'World');
		COMMIT;
	""")
	
	print(datas)
	
	database.close()


func _close(clean_closure := true) -> void:
	prints("BD CLOSE", clean_closure)
