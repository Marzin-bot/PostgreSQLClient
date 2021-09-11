extends Node

var database := PostgreSQLClient.new()

const USER = "Samuel"
const PASSWORD = "my_password"
const HOST = "localhost"
const PORT = 5432 # Default postgres port
const DATABASE = "my_database" # Database name


func _init() -> void:
	var _error := database.connect("connection_established", self, "_executer")
	_error = database.connect("authentication_error", self, "_authentication_error")
	_error = database.connect("connection_closed", self, "_close")
	
	#Connection to the database
	_error = database.connect_to_host("postgresql://%s:%s@%s:%d/%s" % [USER, PASSWORD, HOST, PORT, DATABASE])


func _physics_process(_delta: float) -> void:
	database.poll()


func _authentication_error(error_object: Dictionary) -> void:
	prints("Error connection to database:", error_object["message"])


func _executer() -> void:
	print(database.parameter_status)
	
	var datas := database.execute("""
		BEGIN;
		/*Helloworld*/
		SELECT concat('Hello', 'World');
		COMMIT;
	""")
	
	
	#The datas variable contains an array of PostgreSQLQueryResult object.
	for data in datas:
		#Specifies the number of fields in a row (can be zero).
		print(data.number_of_fields_in_a_row)

		# This is usually a single word that identifies which SQL command was completed.
		# note: the "BEGIN" and "COMMIT" commands return empty values
		print(data.command_tag)

		print(data.row_description)

		print(data.data_row)
			
		prints("Notice:", data.notice)
	
	if not database.error_object.empty():
		prints("Error:", database.error_object)

	database.close()


func _close(clean_closure := true) -> void:
	prints("DB CLOSE,", "Clean closure:", clean_closure)


func _exit_tree() -> void:
	database.close()
