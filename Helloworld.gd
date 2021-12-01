extends Node


const USER := "Samuel"
const PASSWORD := "my_password"
const HOST := "localhost"
const PORT := 5432 # Default postgres port
const DATABASE := "postgres" # Database name

var database: PostgreSQLClient = PostgreSQLClient.new()

func _init():
	var _error = database.connect("connection_established", Callable(self, "_connection_established"))
	_error = database.connect("authentication_error", Callable(self, "_authentication_error"))
	_error = database.connect("connection_closed", Callable(self, "_connection_close"))
	_error = database.connect("data_received", Callable(self, "_data_received"))
	
	#Connection to the database
	_error = database.connect_to_host("postgresql://%s:%s@%s:%d/%s" % [USER, PASSWORD, HOST, PORT, DATABASE])


func _physics_process(_delta: float) -> void:
	database.poll()


func _connection_established() -> void:
	print(database.parameter_status)
	
	var error := database.execute("""
		BEGIN;
		/*Helloworld*/
		SELECT concat('Hello', 'World');
		COMMIT;
	""")
	
	print(error)


func _data_received(error_object: Dictionary, transaction_status: PostgreSQLClient.TransactionStatus, datas: Array) -> void:
	match transaction_status:
		database.TransactionStatus.NOT_IN_A_TRANSACTION_BLOCK:
			print("NOT_IN_A_TRANSACTION_BLOCK")
		database.TransactionStatus.IN_A_TRANSACTION_BLOCK:
			print("IN_A_TRANSACTION_BLOCK")
		database.TransactionStatus.IN_A_FAILED_TRANSACTION_BLOCK:
			print("IN_A_FAILED_TRANSACTION_BLOCK")
	
	# The datas variable contains an array of PostgreSQLQueryResult object.
	for data in datas:
		#Specifies the number of fields in a row (can be zero).
		print(data.number_of_fields_in_a_row)
		
		# This is usually a single word that identifies which SQL command was completed.
		# note: the "BEGIN" and "COMMIT" commands return empty values
		print(data.command_tag)
		
		print(data.row_description)
		
		print(data.data_row)
		
		prints("Notice:", data.notice)
	
	if not error_object.is_empty():
		prints("Error:", error_object)
	
	database.close()


func _authentication_error(error_object: Dictionary) -> void:
	prints("Error connection to database:", error_object["message"])


func _connection_close(clean_closure := true) -> void:
	prints("DB CLOSE,", "Clean closure:", clean_closure)


func _exit_tree() -> void:
	database.close()
