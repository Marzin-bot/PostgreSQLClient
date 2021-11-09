# Lience MIT
# Written by Samuel MARZIN
# Detailed documentation: https://github.com/Marzin-bot/PostgreSQLClient/wiki/Documentation
extends Object


## Godot PostgreSQL Client is a GDscript script/class that allows you to connect to a Postgres backend and run SQL commands there.
## It is able to send data and receive it from the backend. Useful for managing player user data on a multiplayer game, by saving a large amount of data on a dedicated Postgres server from GDscript.
## The class is written in pure GDScript which allows it not to depend on GDNative. This makes it ultra portable for many platforms.
class_name PostgreSQLClient


## Version number (minor.major) of the PostgreSQL protocol used when connecting to the backend.
const PROTOCOL_VERSION := 3.0


## Backend runtime parameters
## A dictionary that contains various information about the state of the server.
## For security reasons the dictionary is always empty if the frontend is disconnected from the backend and updates once the connection is established.
var parameter_status := {}


## Enemeration the statuts of the connection.
enum Status {
	STATUS_DISCONNECTED, ## A status representing a PostgreSQLClient that is disconnected.
	STATUS_CONNECTING, ## A status representing a PostgreSQLClient that is connecting to a host.
	STATUS_CONNECTED, ## A status representing a PostgreSQLClient that is connected to a host.
	STATUS_ERROR ## A status representing a PostgreSQLClient in error state.
}

# The statut of the connection.
var status = Status.STATUS_DISCONNECTED setget set_status, get_status

## Returns the status of the connection (see the Status enumeration).
func get_status() -> int:
	return status

func set_status(_value) -> void:
	# The value of the "status" variable can only be modified locally.
	pass


var password_global: String
var user_global: String

var client := StreamPeerTCP.new()
var peerstream := PacketPeerStream.new()
var stream_peer_ssl = StreamPeerSSL.new()

var peer: StreamPeer
func _init() -> void:
	peerstream.set_stream_peer(client)
	peer = peerstream.stream_peer


## Fires when the connection to the backend closes.
## was_clean_close is true if the connection was closed correctly otherwise false.
signal connection_closed(was_clean_close)

# No use
signal connection_error() # del /!\

## Triggered when the authentication process failed during contact with the target backend.
## The error_object parameter is a dictionary that contains various information during the nature of the error.
signal authentication_error(error_object)


## Trigger when the connection between the frontend and the backend is established.
## This is usually a good time to start making requests to the backend with execute ().
signal connection_established

signal data_received

################## No use at the moment ###############
## The process ID of this backend.
var process_backend_id: int

################## No use at the moment ###############
## The secret key of this backend.
var process_backend_secret_key: int

var status_ssl = 0

var global_url = ""
var startup_message: PoolByteArray
var next_etape := false
var con_ssl: bool

## Allows you to connect to a Postgresql backend at the specified url.
func connect_to_host(url: String, ssl := false, connect_timeout := 30) -> int:
	global_url = url
	con_ssl = ssl
	var error := 1
	
	# If the fontend was already connected to the backend, we disconnect it before reconnecting.
	if status == Status.STATUS_CONNECTED:
		close(false)
	
	var regex = RegEx.new()
	# https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
	regex.compile("^(?:postgresql|postgres)://(.+):(.+)@(.+)(:\\d*)/(.+)")
	
	var result = regex.search(url)
	
	if result:
		### StartupMessage ###
		
		# "postgres" is the database and user by default.
		startup_message = request("", "user".to_ascii() + PoolByteArray([0]) + result.strings[1].to_utf8() + PoolByteArray([0]) + "database".to_ascii() + PoolByteArray([0]) + result.strings[5].to_utf8() + PoolByteArray([0, 0]))
		
		password_global = result.strings[2]
		user_global = result.strings[1]
		
		# The default port for postgresql.
		var port = 5432
		
		if result.strings[4]:
			port = int(result.strings[4])
		
		if stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_CONNECTED:
			stream_peer_ssl.put_data(startup_message)
		else:
			if not client.is_connected_to_host() and client.get_status() == StreamPeerTCP.STATUS_NONE:
				error = client.connect_to_host(result.strings[3], port)
			
			#if (error == OK)
			# Get the fist message of server.
			if error == OK:
				next_etape = true
			else:
				print("[PostgreSQLClient:%d] Invalid host Postgres." % [get_instance_id()])
	else:
		status = Status.STATUS_ERROR
		
		push_error("[PostgreSQLClient:%d] Invalid Postgres URL." % [get_instance_id()])
	
	return error


## A dictionary which contains various information on the execution errors of the last requests made on the backend (usually after using the execute() method).
## If the dictionary is empty, it means that the backend did not detect any error in the query.
## Should be used ideally after each use of the execute() method.
## For security reasons, the dictionary is empty when the frontend is not connected to the backend.
var error_object := {}


## Allows you to close the connection with the backend.
## If clean_closure is true, the frontend will notify the backend that it requests to close the connection.
## If false, the frontend forcibly closes the connection without notifying the backend (not recommended sof in exceptional cases).
## Has no effect if the frontend is not already connected to the backend.
func close(clean_closure := true) -> void:
	if status == Status.STATUS_CONNECTED:
		### Terminate ###
		
		# Identifies the message as a termination.
		
		if stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_HANDSHAKING or stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_CONNECTED:
			# Deconnection ssl
			if clean_closure:
				stream_peer_ssl.put_data(request('X', PoolByteArray()))
			
			stream_peer_ssl.disconnect_from_stream()
		else:
			if clean_closure:
				peer.put_data(request('X', PoolByteArray()))
			
			client.disconnect_from_host()
		
		# For security reasons, the dictionary is empty when the frontend is not connected to the backend.
		parameter_status = {}
		
		# For security reasons, the dictionary is empty when the frontend is not connected to the backend.
		error_object = {}
		
		status = Status.STATUS_DISCONNECTED
		next_etape = false
		status_ssl = 0
		
		emit_signal("connection_closed", clean_closure)
	else:
		push_warning("[PostgreSQLClient:%d] The fontend was already disconnected from the backend when calling close()." % [get_instance_id()])


## Allows to send an SQL string to the backend that should run.
## The sql parameter can contain one or more valid SQL statements.
## Returns an Array of PostgreSQLQueryResult. (Can be empty)
## There are as many PostgreSQLQueryResult elements in the array as there are SQL statements in sql (sof in exceptional cases).
func execute(sql: String) -> Array:
	if status == Status.STATUS_CONNECTED:
		var request := request('Q', sql.to_utf8() + PoolByteArray([0]))
		
		if stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_CONNECTED:
			stream_peer_ssl.put_data(request)
		else:
			peer.put_data(request)
		
		while client.is_connected_to_host() and client.get_status() == StreamPeerTCP.STATUS_CONNECTED and status == Status.STATUS_CONNECTED:
			var reponce := [OK, PoolByteArray()]
			
			if stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_CONNECTED:
				stream_peer_ssl.poll()
				if stream_peer_ssl.get_available_bytes():
					reponce = stream_peer_ssl.get_data(stream_peer_ssl.get_available_bytes()) # I don't know why it crashes when this value (stream_peer_ssl.get_available_bytes()) is equal to 0 so I pass it a condition. It is probably a Godot bug.
				else:
					continue
			else:
				reponce = peer.get_data(peer.get_available_bytes())
			
			if reponce[0] == OK:
				var result = reponce_parser(reponce[1])
				if result != null:
					return result
			else:
				push_warning("[PostgreSQLClient:%d] The backend did not send any data or there must have been a problem while the backend sent a response to the request." % [get_instance_id()])
	else:
		push_error("[PostgreSQLClient:%d] The frontend is not connected to backend." % [get_instance_id()])
	
	return []


## Upgrade the connexion to SSL.
func set_ssl_connection() -> void:
	if stream_peer_ssl.get_status() == StreamPeerSSL.STATUS_HANDSHAKING or stream_peer_ssl.get_status() == StreamPeerSSL.STATUS_CONNECTED:
		push_warning("[PostgreSQLClient:%d] The connection is already secured with TLS/SSL." % [get_instance_id()])
	elif client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		### SSLRequest ###
		
		var buffer := StreamPeerBuffer.new()
		
		# Length of message contents in bytes, including self.
		buffer.put_data(get_32byte_invert(8, true))
		
		# The SSL request code.
		# The value is chosen to contain 1234 in the most significant 16 bits, and 5679 in the least significant 16 bits. (To avoid confusion, this code must not be the same as any protocol version number.)
		buffer.put_data(get_32byte_invert(80877103))
		
		peer.put_data(buffer.data_array)
		
		status_ssl = 1
	else:
		push_error("[PostgreSQLClient:%d] The frontend is not connected to backend." % [get_instance_id()])


##### No use #####
## Upgrade the connexion to GSSAPI.
func set_gssapi_connection() -> void:
	if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		### GSSENCRequest ###
		
		var buffer := StreamPeerBuffer.new()
		
		# Length of message contents in bytes, including self.
		buffer.put_data(get_32byte_invert(8, true))
		
		# The GSSAPI Encryption request code.
		# The value is chosen to contain 1234 in the most significant 16 bits, and 5680 in the least significant 16 bits. (To avoid confusion, this code must not be the same as any protocol version number.)
		buffer.put_data(get_32byte_invert(80877104))
		
		peer.put_data(buffer.data_array)
	else:
		push_error("[PostgreSQLClient:%d] The frontend is not connected to backend." % [get_instance_id()])


## This function undoes all changes made to the database since the last Commit.
func rollback(process_id: int, process_key: int) -> void:
	### CancelRequest ###
	
	if status == Status.STATUS_CONNECTED:
		var buffer := StreamPeerBuffer.new()
		
		# Length of message contents in bytes, including self.
		buffer.put_u32(16)
		
		var message_length := buffer.data_array
		
		message_length.invert()
		
		buffer.put_data(message_length)
		
		# The cancel request code.
		# The value is chosen to contain 1234 in the most significant 16 bits, and 5678 in the least 16 significant bits. (To avoid confusion, this code must not be the same as any protocol version number.)
		buffer.put_data(get_32byte_invert(80877102))
		
		# The process ID of the target backend.
		buffer.put_u32(process_id)
		
		# The secret key for the target backend.
		buffer.put_u32(process_key)
		
		
		peer.put_data(buffer.data_array.subarray(4, -1))
	else:
		push_error("[PostgreSQLClient:%d] The frontend is not connected to backend." % [get_instance_id()])


## Poll the connection to check for incoming messages.
## Ideally, it should be called before PostgreSQLClient.execute() for it to work properly and called frequently in a loop.
func poll() -> void:
	if stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_HANDSHAKING or stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_CONNECTED:
		stream_peer_ssl.poll()
	
	if client.is_connected_to_host():
		if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if next_etape:
				if con_ssl:
					### SSLRequest ###
					
					set_ssl_connection()
				else:
					peer.put_data(startup_message)
					startup_message = PoolByteArray()
				
				next_etape = false
			
			if status_ssl == 1:
				var response = peer.get_data(peer.get_available_bytes())
				if response[0] == OK:
					if not response[1].empty():
						match char(response[1][0]):
							'S':
								#var crypto = Crypto.new()
								#var ssl_key = crypto.generate_rsa(4096)
								#var ssl_cert = crypto.generate_self_signed_certificate(ssl_key)
								stream_peer_ssl.connect_to_stream(peer)
								# stream_peer_ssl.blocking_handshake = false
								status_ssl = 2
							'N':
								status = Status.STATUS_ERROR
								
								push_error("[PostgreSQLClient:%d] The connection attempt failed. The backend does not want to establish a secure SSL/TLS connection." % [get_instance_id()])
								
								close(false)
							var value:
								status = Status.STATUS_ERROR
								
								push_error("[PostgreSQLClient:%d] The backend sent an unknown response to the request to establish a secure connection. Response is not recognized: '%c'." % [get_instance_id(), value])
								
								close(false)
				else:
					push_warning("[PostgreSQLClient:%d] The backend did not send any data or there must have been a problem while the backend sent a response to the request." % [get_instance_id()])
		
		
		if status_ssl == 2 and stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_CONNECTED:
			connect_to_host(global_url, false)
			status_ssl = 3
		
		
		if status_ssl != 1 and status_ssl != 2 and not status == Status.STATUS_CONNECTED and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var reponce: Array
			
			if status_ssl == 0:
				reponce = peer.get_data(peer.get_available_bytes())
			else:
				reponce = stream_peer_ssl.get_data(stream_peer_ssl.get_available_bytes())
			
			if reponce[0] == OK and reponce[1].size():
				var servire = reponce_parser(reponce[1])
				
				if servire:
					if status_ssl == 0:
						peer.put_data(servire)
					else:
						stream_peer_ssl.put_data(servire)


func request(type_message: String, message := PoolByteArray()) -> PoolByteArray:
	# Get the size of message.
	var buffer := StreamPeerBuffer.new()
	
	buffer.put_u32(message.size() + (4 if type_message else 8))
	
	var message_length := buffer.data_array
	
	message_length.invert()
	
	# If the message is not StartupMessage...
	if type_message:
		buffer.put_8(ord(type_message))
	
	buffer.put_data(message_length)
	
	# If the message is StartupMessage...
	if not type_message:
		# Version parsing
		var protocol_major_version = int(PROTOCOL_VERSION)
		var protocol_minor_version = protocol_major_version - PROTOCOL_VERSION
		
		for char_number in str(protocol_major_version).pad_zeros(2) + str(protocol_minor_version).pad_zeros(2):
			buffer.put_data(PoolByteArray([int(char_number)]))
	
	buffer.put_data(message)
	
	error_object = {}
	
	return buffer.data_array.subarray(4, -1)


static func get_32byte_invert(integer: int, unsigned := false) -> PoolByteArray:
	var buffer := StreamPeerBuffer.new()
	
	if unsigned:
		buffer.put_u32(integer)
	else:
		buffer.put_32(integer)
	
	var bytes := buffer.data_array
	bytes.invert()
	
	return bytes


static func split_pool_byte_array(pool_byte_array: PoolByteArray, delimiter: int) -> Array:
	var array := []
	var from := 0
	var to := 0
	
	for byte in pool_byte_array:
		if byte == delimiter:
			array.append(pool_byte_array.subarray(from, to))
			from = to + 1
		
		to += 1
		
	return array


static func pbkdf2(hash_type: int, password: PoolByteArray, salt: PoolByteArray, iterations := 4096, length := 0) -> PoolByteArray:
	var crypto := Crypto.new()
	var hash_length := len(crypto.hmac_digest(hash_type, salt, password))
	if length == 0:
		length = hash_length
	
	var output := PoolByteArray()
	var block_count := ceil(length / hash_length)
	
	var buffer := PoolByteArray()
	buffer.resize(4)
	
	var block := 1
	while block <= block_count:
		buffer[0] = (block >> 24) & 0xFF
		buffer[1] = (block >> 16) & 0xFF
		buffer[2] = (block >> 8) & 0xFF
		buffer[3] = block & 0xFF
		
		var key_1 := crypto.hmac_digest(hash_type, password, salt + buffer)
		var key_2 := key_1
		
		for _index in iterations - 1:
			key_1 = crypto.hmac_digest(hash_type, password, key_1)
			
			for index in key_1.size():
				key_2[index] ^= key_1[index]
		
		output += key_2
		
		block += 1
	
	return output.subarray(0, hash_length - 1)


enum DataTypePostgreSQL {
	BOOLEAN = 16,
	SMALLINT = 21,
	INTEGER = 23,
	BIGINT = 20,
	REAL = 700,
	DOUBLE_PRECISION = 701,
	TEXT = 25,
	CHARACTER = 1042, # Alias CHAR.
	CHARACTER_VARYING = 1043, # Alias VARCHAR.
	JSON = 114,
	JSONB = 3802,
	XML = 142,
	BITEA = 17,
	CIDR = 650,
	INET = 869,
	MACADDR = 829,
	MACADDR8 = 774,
	BIT = 1560,
	BIT_VARYING = 1562,
	UUID = 2950,
	POINT = 600,
	BOX = 603,
	LSEG = 601,
	LINE = 628,
	CIRCLE = 718
}


## The PostgreSQLQueryResult class is a subclass of PostgreSQLClient which is not intended to be created manually.
## It represents the result of an SQL query and provides an information and method report to use the result of the query.
## It is usually returned by the PostgreSQLClient.execute() method in an array of PostgreSQLQueryResult.
class PostgreSQLQueryResult:
	## Specifies the number of fields in a row (can be zero).
	var number_of_fields_in_a_row := 0
	
	## An array that contains dictionaries.
	## These dictionaries represent the description of the rows where the query was executed.
	## The number of dictionary depends on the number of fields resulting from the result of the query which was executed.
	var row_description := []
	
	## An Array that contains sub-arrays.
	## These sub-arrays represent for most of the queries the rows of the table where the query was executed.
	## The number of sub-tables depends on the query that has been made.
	## These sub-arrays contain as many elements as number_of_fields_in_a_row.
	## These elements are native GDscript types that represent the data resulting from the query.
	var data_row := []
	
	## An Array that contains sub-arrays.
	## These sub-arrays represent for most of the queries the rows of the table where the query was executed.
	## The number of sub-tables depends on the query that has been made.
	## These sub-arrays contain as many elements as number_of_fields_in_a_row.
	var raw_data_row := []
	
	## This is usually a single word that identifies which SQL command was completed.
	var command_tag: String
	
	## Represents various information about the execution status of the query notified by the backend. Can be empty.
	var notice := {}
	
	## Returns all the values of a field.
	## field_name is the name of the field on which we get the values.
	## Can be empty if the field name is unknown.
	## The field_name parameter is case sensitive.
	func get_field_values(field_name: String) -> Array:
		var values := []
		
		var fields_index: int
		
		for i in number_of_fields_in_a_row:
			if row_description[i]["field_name"] == field_name:
				fields_index = i
				
				break
		
		if fields_index == null:
			return values
			
		for data in data_row:
			values.append(data[fields_index])
		
		return values
	
	
	## Returns the object ID of the data type of the field.
	## field_name is the name of the field whose type we get.
	## Can return -1 if the field name is unknown.
	## The field_name parameter is case sensitive.
	func field_data_type(field_name: String) -> int:
		for i in number_of_fields_in_a_row:
			if row_description[i]["field_name"] == field_name:
				return row_description[i]["type_object_id"]
		
		return -1


var postgresql_query_result_instance := PostgreSQLQueryResult.new()

var datas_command_sql := []

var response_buffer: PoolByteArray

var client_first_message: String # Authentication SASL
var salted_password: PoolByteArray # Authentication SASL
var auth_message: String # Authentication SASL

func reponce_parser(response: PoolByteArray):
	response_buffer += response
	
	while client.get_status() == StreamPeerTCP.STATUS_CONNECTED and response_buffer.size() > 4:
		# Get the length of the response.
		var data_length = response_buffer.subarray(1, 4)
		data_length.invert()
		
		var buffer := StreamPeerBuffer.new()
		buffer.put_data(data_length)
		buffer.seek(0)
		
		# Message length.
		var message_length = buffer.get_u32()
		
		# If the size of the buffer is not equal to the length of the message, the request is not processed immediately.
		# The server may send a fragmented response.
		# We must therefore wait to receive the full response.
		if response_buffer.size() < message_length + 1:
			break
		
		# Message type.
		match char(response_buffer[0]):
			'A':
				### NotificationResponse ###
				
				# Get the process ID of the notifying backend process.
				var process_id = response_buffer.subarray(5, 8)
				process_id.invert()
				
				buffer.put_data(process_id)
				buffer.seek(4)
				
				process_id = buffer.get_32()
				
				# We get the following parameters.
				var situation_report_data := split_pool_byte_array(response_buffer.subarray(5, message_length), 0)
				
				# Get the name of the channel that the notify has been raised on.
				var name_of_channel: String = situation_report_data[0].get_string_from_utf8()
				
				# Get the "payload" string passed from the notifying process.
				var payload: String = situation_report_data[1].get_string_from_utf8()
				
				# The result.
				prints(process_id, name_of_channel, payload)
			'C':
				### CommandComplete ###
				
				# Identifies the message as a command-completed response.
				
				# Get the command tag. This is usually a single word that identifies which SQL command was completed.
				var command_tag = response_buffer.subarray(5, message_length).get_string_from_ascii()
				
				# The result.
				postgresql_query_result_instance.command_tag = command_tag
				
				datas_command_sql.append(postgresql_query_result_instance)
				
				# Now is a good time to create a new return object for a possible next request.
				postgresql_query_result_instance = PostgreSQLQueryResult.new()
			'D':
				### DataRow ###
				
				# Identifies the message as a data row.
				
				# Number of column values ​​that follow (can be zero).
				var number_of_columns = response_buffer.subarray(5, 6)
				number_of_columns.invert()
				
				buffer.put_data(number_of_columns)
				buffer.seek(4)
				
				number_of_columns = buffer.get_16()
				
				var cursor := 0
				var row := []
				var raw_row := []
				
				# Next, the following pair of fields appear for each column.
				for i in number_of_columns:
					var value_length = response_buffer.subarray(cursor + 7, cursor + 10)
					value_length.invert()
					
					buffer = StreamPeerBuffer.new()
					buffer.put_data(value_length)
					buffer.seek(0)
					
					value_length = buffer.get_32()
					
					if value_length == -1:
						### NULL ###
						
						# The result.
						row.append(null)
						
						match postgresql_query_result_instance.row_description[i].format_code:
							0:
								raw_row.append("")
							1:
								raw_row.append(PoolByteArray())
							_:
								print("error")
						
						value_length = 0
					else:
						var value_data := response_buffer.subarray(cursor + 11, cursor + value_length + 10)
						
						match postgresql_query_result_instance.row_description[i].format_code:
							0:
								raw_row.append(value_data.get_string_from_ascii())
							1:
								raw_row.append(value_data)
							_:
								print("error")
						
						var error: int
						
						match postgresql_query_result_instance.row_description[i].type_object_id:
							DataTypePostgreSQL.BOOLEAN:
								### BOOLEAN ###
								
								# The type returned is bool.
								match char(value_data[0]):
									't':
										### TRUE ###
										
										# The result.
										row.append(true)
									'f':
										### FALSE ###
										
										# The result.
										row.append(false)
									var value_column:
										push_error("[PostgreSQLClient:%d] The backend sent an invalid BOOLEAN object. Column value is not recognized: '%c'." % [get_instance_id(), value_column])
										
										close(false)
										return
							DataTypePostgreSQL.SMALLINT:
								### SMALLINT ###
								
								# The type returned is int.
								# The result.
								row.append(int(value_data.get_string_from_ascii()))
							DataTypePostgreSQL.INTEGER:
								### INTEGER ###
								
								# The type returned is int.
								# The result.
								row.append(int(value_data.get_string_from_ascii()))
							DataTypePostgreSQL.BIGINT:
								### BIGINT ###
								
								# The type returned is int.
								# The result.
								row.append(int(value_data.get_string_from_ascii()))
							DataTypePostgreSQL.REAL:
								### REAL ###
								
								# The type returned is float.
								# The result.
								row.append(float(value_data.get_string_from_ascii()))
							DataTypePostgreSQL.DOUBLE_PRECISION:
								### DOUBLE PRECISION ###
								
								# The type returned is float.
								# The result.
								row.append(float(value_data.get_string_from_ascii()))
							DataTypePostgreSQL.TEXT:
								### TEXT ###
								
								# The type returned is String.
								# The result.
								row.append(value_data.get_string_from_utf8())
							DataTypePostgreSQL.CHARACTER:
								### CHARACTER ###
								
								# The type returned is String.
								# The result.
								row.append(value_data.get_string_from_utf8())
							DataTypePostgreSQL.CHARACTER_VARYING:
								### CHARACTER_VARYING ###
								
								# The type returned is String.
								# The result.
								row.append(value_data.get_string_from_utf8())
							"tsvector":
								### TSVECTOR ###
								
								pass
							"tsquery":
								### TSQUERY ###
								
								pass
							DataTypePostgreSQL.XML:
								### XML ###
								
								# The type returned is String.
								var xml := XMLParser.new()
								
								error = xml.open_buffer(value_data)
								if error == OK:
									# The result.
									row.append(value_data.get_string_from_utf8())
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid XML object. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									
									response_buffer = PoolByteArray()
									return
							DataTypePostgreSQL.JSON:
								### JSON ###
								
								# The type returned is String.
								var json = value_data.get_string_from_utf8()
								
								var json_error := validate_json(json)
								
								if json_error:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid JSON object: (Error: %d)" % [get_instance_id(), json_error])
									
									close(false)
									response_buffer = PoolByteArray()
									return
								else:
									# The result.
									row.append(json)
							DataTypePostgreSQL.JSONB:
								### JSONB ###
								
								# The type returned is String.
								var json = value_data.get_string_from_utf8()
								
								var json_error := validate_json(json)
								
								if json_error:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid JSONB object: (Error: %d)" % [get_instance_id(), json_error])
									
									close(false)
									response_buffer = PoolByteArray()
									return
								else:
									# The result.
									row.append(json)
							DataTypePostgreSQL.BIT:
								### BIT ###
								
								# The type returned is String.
								
								# Ideally we should validate the value sent by the backend...
								
								# The result.
								row.append(value_data.get_string_from_ascii())
							DataTypePostgreSQL.BIT_VARYING:
								### BIT VARYING ###
								
								# The type returned is String.
								
								# Ideally we should validate the value sent by the backend...
								
								# The result.
								row.append(value_data.get_string_from_ascii())
							DataTypePostgreSQL.BITEA:
								### BITEA ###
								
								# /!\ Support not complet (not end). /!\
								
								# The type returned is PoolByteArray.
								var bitea_data := value_data.get_string_from_ascii()
								
								if bitea_data.substr(2).is_valid_hex_number():
									var bitea := PoolByteArray()
									
									for i_hex in value_data.size() * 0.5 - 1:
										bitea.append(("0x" + bitea_data[i_hex + 2] + bitea_data[i_hex + 2]).hex_to_int())
									
									# The result.
									row.append(bitea)
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid BITEA object." % [get_instance_id()])
									
									close(false)
									response_buffer = PoolByteArray()
									return
							"timestamp":
								### TIMESTAMP ###
								
								pass
							"date":
								### DATE ###
								
								pass
							"interval":
								### INTERVAL ###
								
								pass
							DataTypePostgreSQL.UUID:
								### UUID ###
								
								# The type returned is String.
								
								# Ideally we should validate the value sent by the backend...
								
								# The result.
								row.append(value_data.get_string_from_ascii())
							DataTypePostgreSQL.CIDR:
								### CIDR ###
								
								# The type returned is String.
								
								# Ideally we should validate the value sent by the backend with the line if below...
								#value_data.get_string_from_ascii().is_valid_ip_address()
								
								# The result.
								row.append(value_data.get_string_from_ascii())
							DataTypePostgreSQL.INET:
								### INET ###
								
								# The type returned is String.
								
								# Ideally we should validate the value sent by the backend with the line if below...
								#value_data.get_string_from_ascii().is_valid_ip_address()
								
								# The result.
								row.append(value_data.get_string_from_ascii())
							DataTypePostgreSQL.MACADDR:
								### MACADDR ###
								
								# The type returned is String.
								
								# Ideally we should validate the value sent by the backend...
								
								# The result.
								row.append(value_data.get_string_from_ascii())
							DataTypePostgreSQL.MACADDR8:
								### MACADDR8 ###
								
								# The type returned is String.
								
								# Ideally we should validate the value sent by the backend...
								
								# The result.
								row.append(value_data.get_string_from_ascii())
							DataTypePostgreSQL.POINT:
								### POINT ###
								
								# The type returned is Vector2.
								var regex = RegEx.new()
								
								error = regex.compile("^\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\)")
								if error:
									push_error("[PostgreSQLClient:%d] RegEx compilation of POINT object failed. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									response_buffer = PoolByteArray()
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								
								if result:
									# The result.
									row.append(Vector2(float(result.strings[1]), float(result.strings[2])))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid POINT object." % [get_instance_id()])
									
									close(false)
									response_buffer = PoolByteArray()
									return
							DataTypePostgreSQL.BOX:
								### BOX ###
								
								# The type returned is Rect2.
								var regex = RegEx.new()
								
								error = regex.compile("^\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\),\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\)")
								if error:
									push_error("[PostgreSQLClient:%d] RegEx compilation of BOX object failed. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									response_buffer = PoolByteArray()
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								if result:
									# The result.
									row.append(Rect2(float(result.strings[3]), float(result.strings[4]), float(result.strings[1]), float(result.strings[2])))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid BOX object." % [get_instance_id()])
									
									close(false)
									response_buffer = PoolByteArray()
									return
							DataTypePostgreSQL.LSEG:
								### LSEG ###
								
								# The type returned is PoolVector2Array.
								var regex = RegEx.new()
								
								error = regex.compile("^\\[\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\),\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\)\\]")
								if error:
									push_error("[PostgreSQLClient:%d] RegEx compilation of LSEG object failed. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									response_buffer = PoolByteArray()
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								if result:
									# The result.
									row.append(PoolVector2Array([
										Vector2(float(result.strings[1]), float(result.strings[2])),
										Vector2(float(result.strings[3]), float(result.strings[4]))
									]))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid LSEG object." % [get_instance_id()])
									
									close(false)
									response_buffer = PoolByteArray()
									return
							"polygon":
								### POLYGON ###
								
								# The type returned is PoolVector2Array.
								row.append(PoolVector2Array())
							"path":
								### PATH ###
								
								# The type returned is PoolVector2Array.
								row.append(PoolVector2Array())
							DataTypePostgreSQL.LINE:
								### LINE ###
								
								# The type returned is Vector3.
								var regex = RegEx.new()
								
								error = regex.compile("^\\{(-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\}")
								if error:
									push_error("[PostgreSQLClient:%d] RegEx compilation of LINE object failed. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									response_buffer = PoolByteArray()
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								
								if result:
									# The result.
									row.append(Vector3(float(result.strings[1]), float(result.strings[2]), float(result.strings[3])))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid LINE object." % [get_instance_id()])
									
									close(false)
									response_buffer = PoolByteArray()
									return
							DataTypePostgreSQL.CIRCLE:
								### CIRCLE ###
								
								# The type returned is Vector3.
								var regex = RegEx.new()
								
								error = regex.compile("^<\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\),(\\d+(\\.\\d+)?)>")
								if error:
									push_error("[PostgreSQLClient:%d] RegEx compilation of CIRCLE object failed. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									response_buffer = PoolByteArray()
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								if result:
									# The result.
									row.append(Vector3(float(result.strings[1]), float(result.strings[2]), float(result.strings[3])))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid CIRCLE object." % [get_instance_id()])
									
									close(false)
									response_buffer = PoolByteArray()
									return
							_:
								# The type returned is PoolByteArray.
								row.append(value_data)
					
					cursor += value_length + 4
				
				# The result.
				postgresql_query_result_instance.data_row.append(row)
				postgresql_query_result_instance.raw_data_row.append(raw_row)
			'E':
				### ErrorResponse ###
				
				# Identifies the message as an error.
				
				# The message body consists of one or more identified fields, followed by a zero byte as a terminator.
				# Fields can appear in any order. For each field there is the following:
				for champ_data in split_pool_byte_array(response_buffer.subarray(5, message_length - 1), 0):
					var champ: String = champ_data.get_string_from_ascii()
					
					# A code identifying the field type; if zero, this is the message terminator and no string follows.
					var field_type_code := champ[0]
					
					# The field value.
					var value := champ.trim_prefix(field_type_code)
					
					match field_type_code:
						'S':
							if value == "FATAL":
								# For security reasons, the dictionary is empty when the frontend is not connected to the backend.
								parameter_status = {}
								
								# For security reasons, the dictionary is empty when the frontend is not connected to the backend.
								error_object = {}
								
								status = Status.STATUS_DISCONNECTED
								
								status_ssl = 0
								
								emit_signal("connection_closed", true)
							
							error_object["severity"] = value
						'V':
							error_object["severity_no_localized"] = value
						'C':
							error_object["SQLSTATE_code"] = value
						'M':
							error_object["message"] = value
							
							push_error("[PostgreSQLClient:%d] %s" % [get_instance_id(), value])
						'D':
							error_object["detail"] = value
						'H':
							error_object["hint"] = value
						'P':
							error_object["position"] = value
						'p':
							error_object["internal_position"] = value
						'q':
							error_object["internal_query"] = value
						'W':
							error_object["where"] = value
						's':
							error_object["schema_name"] = value
						't':
							error_object["table_name"] = value
						'c':
							error_object["column_name"] = value
						'd':
							error_object["constraint_name"] = value
						'n':
							error_object["constraint_name"] = value
						'F':
							error_object["file"] = value
						'L':
							error_object["line"] = value
						'R':
							error_object["routine"] = value
						_:
							# Since more field types might be added in future, frontends should silently ignore fields of unrecognized type.
							pass
				
				if error_object["severity"] == "FATAL":
					status = Status.STATUS_ERROR
					
					if status != Status.STATUS_CONNECTED:
						emit_signal("authentication_error", error_object.duplicate())
			'G':
				### CopyInResponse ###
				
				# The message "CopyInResponse" identifies the message as a Start Copy In response. The frontend must now send copy-in data (if not prepared to do so, send a CopyFail message).
				
				buffer = StreamPeerBuffer.new()
				
				# Get overall copy format code.
				# 0 indicates the overall COPY format is textual (rows separated by newlines, columns separated by separator characters, etc). 1 indicates the overall copy format is binary (similar to DataRow format). See COPY for more information.
				var overall_copy_format_code = response_buffer.subarray(5, 6)
				overall_copy_format_code.invert()
				
				buffer.put_data(overall_copy_format_code)
				buffer.seek(0)
				
				overall_copy_format_code = buffer.get_u8()
				
				# Get the number of columns in the data to be copied.
				var number_of_columns = response_buffer.subarray(7, 9)
				number_of_columns.invert()
				
				buffer.put_data(number_of_columns)
				buffer.seek(1)
				
				number_of_columns = buffer.get_u16()
				
				# Get the format codes to be used for each column.
				# Each must presently be zero (text) or one (binary). All must be zero if the overall copy format is textual.
				for index in number_of_columns:
					var format_code = response_buffer.subarray(10, 12)
					format_code.invert()
					
					buffer.put_data(format_code)
					buffer.seek(2 * index + 3)
					
					format_code = buffer.get_u16()
					
					# The result.
					print(format_code)
				
				push_warning("[PostgreSQLClient:%d] CopyInResponse, no support." % [get_instance_id()])
			'H':
				### CopyOutResponse ###
				
				# The message "CopyOutResponse" identifies the message as a Start Copy Out response. This message will be followed by copy-out data.
				
				buffer = StreamPeerBuffer.new()
				
				# Get overall copy format code.
				# 0 indicates the overall COPY format is textual (rows separated by newlines, columns separated by separator characters, etc). 1 indicates the overall copy format is binary (similar to DataRow format). See COPY for more information.
				var overall_copy_format_code = response_buffer.subarray(5, 6)
				overall_copy_format_code.invert()
				
				buffer.put_data(overall_copy_format_code)
				buffer.seek(0)
				
				overall_copy_format_code = buffer.get_8()
				
				# Get the number of columns in the data to be copied.
				var number_of_columns = response_buffer.subarray(7, 9)
				number_of_columns.invert()
				
				buffer.put_data(number_of_columns)
				buffer.seek(1)
				
				number_of_columns = buffer.get_16()
				
				# Get the format codes to be used for each column.
				# Each must presently be zero (text) or one (binary). All must be zero if the overall copy format is textual.
				for index in number_of_columns:
					var format_code = response_buffer.subarray(10, 12)
					format_code.invert()
					
					buffer.put_data(format_code)
					buffer.seek(2 * index + 3)
					
					format_code = buffer.get_16()
					
					# The result.
					print(format_code)
				
				push_warning("[PostgreSQLClient:%d] CopyOutResponse, no support." % [get_instance_id()])
			'N':
				### NoticeResponse ###
				
				# Identifies the message as a notice.
				
				var notice_object := {}
				
				# The message body consists of one or more identified fields, followed by a zero byte as a terminator.
				# Fields can appear in any order.
				# For each field there is the following:
				for champ_data in split_pool_byte_array(response_buffer.subarray(5, message_length - 1), 0):
					var champ: String = champ_data.get_string_from_ascii()
					
					# A code identifying the field type; if zero, this is the message terminator and no string follows.
					var field_type_code := champ[0]
					
					# The field value.
					var value := champ.trim_prefix(field_type_code)
					
					match field_type_code:
						'S':
							notice_object["severity"] = value
						'V':
							notice_object["severity_no_localized"] = value
						'C':
							notice_object["SQLSTATE_code"] = value
						'M':
							notice_object["message"] = value
						'D':
							notice_object["detail"] = value
						'H':
							notice_object["hint"] = value
						'P':
							notice_object["position"] = value
						'p':
							notice_object["internal_position"] = value
						'q':
							notice_object["internal_query"] = value
						'W':
							notice_object["where"] = value
						's':
							notice_object["schema_name"] = value
						't':
							notice_object["table_name"] = value
						'c':
							notice_object["column_name"] = value
						'd':
							notice_object["constraint_name"] = value
						'n':
							notice_object["constraint_name"] = value
						'F':
							notice_object["file"] = value
						'L':
							notice_object["line"] = value
						'R':
							notice_object["routine"] = value
						_:
							# Since more field types might be added in future, frontends should silently ignore fields of unrecognized type.
							pass
				
				var last_datas_command_sql = datas_command_sql.back()
				
				if last_datas_command_sql:
					last_datas_command_sql.notice = notice_object
			'I':
				### EmptyQueryResponse ###
				
				# Identifies the message as a response to an empty query string. (This substitutes for CommandComplete.)
				pass
			'K':
				### BackendKeyData ####
				
				# Identifies the message as cancellation key data. The frontend must save these values if it wishes to be able to issue CancelRequest messages later.
				
				# Get the process ID of this backend.
				var process_backend_id = response_buffer.subarray(5, 8)
				process_backend_id.invert()
				
				buffer.put_data(process_backend_id)
				buffer.seek(4)
				
				# The result.
				process_backend_id = buffer.get_u32()
				
				# Get the secret key of this backend.
				var process_backend_secret_key = response_buffer.subarray(9, message_length)
				process_backend_secret_key.invert()
				
				buffer.put_data(process_backend_secret_key)
				buffer.seek(8)
				
				# The result.
				process_backend_secret_key = buffer.get_u32()
			'R':
				### Authentication ###
				
				# Identifies the message as an authentication request.
				
				var authentication_type_data := response_buffer.subarray(5, 8)
				
				authentication_type_data.invert()
				
				buffer.put_data(authentication_type_data)
				buffer.seek(4)
				
				var authentication_type := buffer.get_32()
				
				match authentication_type:
					0:
						### AuthenticationOk ###
						
						# Specifies that the authentication was successful.
						
						status = Status.STATUS_CONNECTING
					2:
						### AuthenticationKerberosV5 ###
						
						# Specifies that Kerberos V5 authentication is required.
						
						# rfc4120
						# No support
						push_error("AuthenticationKerberosV5 No support")
						close(false)
						
						response_buffer = PoolByteArray()
						return
					3:
						### AuthenticationCleartextPassword ###
						
						# Specifies that a clear-text password is required.
						
						response_buffer = PoolByteArray()
						return request('p', password_global.to_utf8())
					5:
						### AuthentificationMD5Password ###
						
						# Specifies that an MD5-encrypted password is required.
						
						var hashing_context = HashingContext.new()
						hashing_context.start(HashingContext.HASH_MD5)
						hashing_context.update((password_global + user_global).md5_buffer().hex_encode().to_ascii() + response_buffer.subarray(9, 12))
						
						response_buffer = PoolByteArray()
						return request('p', ("md5" + hashing_context.finish().hex_encode()).to_ascii() + PoolByteArray([0]))
					6:
						### AuthenticationSCMCredential ###
						
						# Specifies that an SCM credentials message is required.
						# No support
						push_error("AuthenticationSCMCredential No support")
						close(false)
						
						response_buffer = PoolByteArray()
						return
					7:
						### AuthenticationGSS ###
						
						# Specifies that GSSAPI authentication is required.
						# No support
						push_error("AuthenticationGSS No support")
						close(false)
						
						response_buffer = PoolByteArray()
						return
					8:
						### AuthenticationGSSContinue ###
						
						# Specifies that this message contains GSSAPI or SSPI data.
						# No support
						push_error("AuthenticationGSSContinue No support")
						close(false)
						
						response_buffer = PoolByteArray()
						return
					9:
						### AuthenticationSSPI ###
						
						# Specifies that SSPI authentication is required.
						
						# No support
						push_error("AuthenticationSSPI No support")
						close(false)
						
						response_buffer = PoolByteArray()
						return
					10:
						### AuthenticationSASL ###
						
						# Specifies that SASL authentication is required.
						
						# Get the message body is a list of SASL authentication mechanisms, in the server's order of preference. A zero byte is required as terminator after the last authentication mechanism name.
						# For each mechanism, there is the following:
						for name_sasl_authentication_mechanism in split_pool_byte_array(response_buffer.subarray(9, message_length - 1), 0):
							match name_sasl_authentication_mechanism.get_string_from_ascii():
								"SCRAM-SHA-256":
									### SASLInitialResponse ###
									
									# Identifies the message as an initial SASL response. Note that this is also used for GSSAPI, SSPI and password response messages. The exact message type is deduced from the context.
									
									var crypto := Crypto.new()
									
									var nonce = Marshalls.raw_to_base64(crypto.generate_random_bytes(24))
									
									client_first_message = "%c,,n=%s,r=%s" % ['n', "", nonce] # When SCRAM-SHA-256 is used in PostgreSQL, the server will ignore the user name that the client sends in the client-first-message. The user name that was already sent in the startup message is used instead.
									
									var len_client_first_message := get_32byte_invert(len(client_first_message), true)
									
									var sasl_initial_response := request('p', "SCRAM-SHA-256".to_ascii() + PoolByteArray([0]) + len_client_first_message + client_first_message.to_utf8())
									
									if stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_CONNECTED:
										stream_peer_ssl.put_data(sasl_initial_response)
									else:
										peer.put_data(sasl_initial_response)
									
									response_buffer = PoolByteArray()
									return
								"SCRAM-SHA-256-PLUS":
									continue # I'm still not done implementing SCRAM-SHA-256-PLUS, so we'll skip it for now.
									
									# /!\ Not end /!\
									
									### SASLInitialResponse ###
									
									# Identifies the message as an initial SASL response. Note that this is also used for GSSAPI, SSPI and password response messages. The exact message type is deduced from the context.
									
									var crypto := Crypto.new()
									
									var nonce = Marshalls.raw_to_base64(crypto.generate_random_bytes(24))
									
									client_first_message = "%c,,n=%s,r=%s" % ['y', "", nonce] # When SCRAM-SHA-256-PLUS is used in PostgreSQL, the server will ignore the user name that the client sends in the client-first-message. The user name that was already sent in the startup message is used instead.
									
									var len_client_first_message := get_32byte_invert(len(client_first_message), true)
									
									var sasl_initial_response := request('p', "SCRAM-SHA-256-PLUS".to_ascii() + PoolByteArray([0]) + len_client_first_message + client_first_message.to_utf8())
									
									if stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_CONNECTED:
										stream_peer_ssl.put_data(sasl_initial_response)
									else:
										peer.put_data(sasl_initial_response)
									
									response_buffer = PoolByteArray()
									return
								"SCRAM-SHA-1":
									# No implemented.
									pass
								"SCRAM-SHA-1-PLUS":
									# No implemented.
									pass
								"CRAM-MD5":
									# No implemented.
									pass
								"CRAM-MD5-PLUS":
									# No implemented.
									pass
						
						push_error("[PostgreSQLClient:%d] No SASL mechanism offered by the backend is supported by the frontend for SASL authentication." % [get_instance_id()])
						
						close(false)
						
						response_buffer = PoolByteArray()
						return
					11:
						### AuthenticationSASLContinue ###
						
						# Specifies that this message contains a SASL challenge.
						
						# SCRAM-SHA-256
						var server_first_message = response_buffer.subarray(9, message_length).get_string_from_ascii()
						
						var server_nonce = server_first_message.split(',')[0].substr(2)
						var server_salt = Marshalls.base64_to_raw(server_first_message.split(',')[1].substr(2))
						var server_iterations := int(server_first_message.split(',')[2].substr(2))
						
						var client_final_message := "c=biws,r=%s" % [server_nonce]
						
						# On devrait passer le mot de passe (password_global) dans la fonction SASLprep (rfc7613) (or SASLprep, rfc4013) non implémenté si desous...
						salted_password = pbkdf2(HashingContext.HASH_SHA256, password_global.to_utf8(), server_salt, server_iterations)
						
						var crypto = Crypto.new()
						
						var client_key = crypto.hmac_digest(HashingContext.HASH_SHA256, salted_password, "Client Key".to_ascii())
						
						var hashing_context = HashingContext.new()
						hashing_context.start(HashingContext.HASH_SHA256)
						hashing_context.update(client_key)
						var stored_key = hashing_context.finish()
						
						# AuthMessage is just a concatenation of the initial client message, server challenge, and client response (without ClientProof).
						var client_first_message_bare = client_first_message.substr(3)
						
						client_first_message = ""
						
						auth_message = client_first_message_bare + ',' + server_first_message + ',' + client_final_message
						var client_signature = crypto.hmac_digest(HashingContext.HASH_SHA256, stored_key, auth_message.to_utf8())
						
						var client_proof_buffer := PoolByteArray()
						for index in client_key.size():
							client_proof_buffer.append(client_key[index] ^ client_signature[index])
						
						var client_proof := Marshalls.raw_to_base64(client_proof_buffer)
						
						client_final_message += ",p=" + client_proof
						
						var authentication_sasl_continue := request('p', client_final_message.to_ascii())
						
						if stream_peer_ssl.get_status() == stream_peer_ssl.STATUS_CONNECTED:
							stream_peer_ssl.put_data(authentication_sasl_continue)
						else:
							peer.put_data(authentication_sasl_continue)
					12:
						### AuthenticationSASLFinal ###
						
						# Specifies that SASL authentication has completed.
						
						var server_final_message = response_buffer.subarray(9, message_length).get_string_from_ascii()
						
						# The client verifies the proof from the server by calculating the ServerKey and the ServerSignature, then comparing its ServerSignature to that received from the server.
						# If they are the same, the client has proof that the server has access to the ServerKey.
						
						var crypto = Crypto.new()
						
						var server_key = crypto.hmac_digest(HashingContext.HASH_SHA256, salted_password, "Server Key".to_ascii())
						
						salted_password = PoolByteArray()
						
						var server_signature = crypto.hmac_digest(HashingContext.HASH_SHA256, server_key, auth_message.to_utf8())
						
						auth_message = ""
						
						var server_proof := PoolByteArray()
						for index in server_key.size():
							server_proof.append(server_key[index] ^ server_signature[index])
						
						# Get server proof response
						var server_proof_response = server_final_message.substr(2)
						
						if server_proof_response != Marshalls.raw_to_base64(server_signature):
							# /!\ We should normally trigger the "authentication_error" signal but it is still not implemented... /!\
							push_error("[PostgreSQLClient:%d] An error occurred during SASL authentication. The SCRAM dialogue between the frontend and the backend does not end as expected. The server could not prove that it was in possession of ServerKey. The backend does not seem reliable for the frontend. The authentication attempt failed. Connection between frontend and backend interrupted." % [get_instance_id()])
							
							close(false)
							
							response_buffer = PoolByteArray()
							return
					_:
						push_error("[PostgreSQLClient:%d] The backend requires the frontend to use an authentication method that it does not support. Unknown authentication code." % [get_instance_id()])
						
						close(false)
						
						response_buffer = PoolByteArray()
						return
			'S':
				### ParameterStatus ###
				
				# Identifies the message as a run-time parameter status report.
				var situation_report_data := split_pool_byte_array(response_buffer.subarray(5, message_length), 0)
				
				# Get the name of the run-time parameter being reported.
				var parameter: String = situation_report_data[0].get_string_from_utf8()
				
				# Get the current value of the parameter.
				var value: String = situation_report_data[1].get_string_from_utf8()
				
				# The result
				parameter_status[parameter] = value
			'T':
				### RowDescription ###
				
				# Get the number of fields in a row (can be zero).
				var number_of_fields_in_a_row := response_buffer.subarray(5, 6)
				number_of_fields_in_a_row.invert()
				
				buffer.put_data(number_of_fields_in_a_row)
				buffer.seek(4)
				
				postgresql_query_result_instance.number_of_fields_in_a_row = buffer.get_u16()
				
				# Then, for each field...
				var cursor := 7
				for _index in postgresql_query_result_instance.number_of_fields_in_a_row:
					# Get the field name.
					var field_name := ""
					
					for octet in response_buffer.subarray(cursor, message_length):
						field_name += char(octet)
						
						# If we get to the end of the chain, we get out of the loop.
						if not octet:
							break
					
					cursor += len(field_name)
					
					buffer = StreamPeerBuffer.new()
					
					# Get the object ID of the table.
					# If the field can be identified as a column of a specific table, the object ID of the table; otherwise zero.
					var table_object_id = response_buffer.subarray(cursor, cursor + 4)
					table_object_id.invert()
					
					buffer.put_data(table_object_id)
					buffer.seek(0)
					
					table_object_id = buffer.get_u32()
					
					# Get the attribute number of the column.
					# If the field can be identified as a column of a specific table, the attribute number of the column; otherwise zero.
					var column_index = response_buffer.subarray(cursor + 5, cursor + 6)
					column_index.invert()
					
					buffer.put_data(column_index)
					buffer.seek(4)
					
					column_index = buffer.get_u16()
					
					# Get the object ID of the field's data type.
					var type_object_id = response_buffer.subarray(cursor + 7, cursor + 10)
					type_object_id.invert()
					
					buffer.put_data(type_object_id)
					buffer.seek(6)
					
					type_object_id = buffer.get_u32()
					
					# Get the data type size (see pg_type.typlen).
					# Note that negative values denote variable-width types.
					var data_type_size = response_buffer.subarray(cursor + 11, cursor + 12)
					data_type_size.invert()
					
					buffer.put_data(data_type_size)
					buffer.seek(10)
					
					data_type_size = buffer.get_u16()
					
					# Get the type modifier (see pg_attribute.atttypmod).
					# The meaning of the modifier is type-specific.
					var type_modifier = response_buffer.subarray(cursor + 13, cursor + 16)
					type_modifier.invert()
					
					buffer.put_data(type_modifier)
					buffer.seek(12)
					
					type_modifier = buffer.get_u32()
					
					# Get the format code being used for the field.
					# Currently will be zero (text) or one (binary).
					# In a RowDescription returned from the statement variant of Describe, the format code is not yet known and will always be zero.
					var format_code = response_buffer.subarray(cursor + 17, cursor + 18)
					format_code.invert()
					
					buffer.put_data(format_code)
					buffer.seek(16)
					
					format_code = buffer.get_u16()
					
					cursor += 19
					
					# The result.
					postgresql_query_result_instance.row_description.append({
						"field_name": field_name,
						"table_object_id": table_object_id,
						"column_index": column_index,
						"type_object_id": type_object_id,
						"data_type_size": data_type_size,
						"type_modifier": type_modifier,
						"format_code": format_code
					})
			'V':
				### FunctionCallResponse ###
				
				# Identifies the message as a function call result.
				push_error("FunctionCallResponse no implemented.")
			'W':
				### CopyBothResponse ###
				
				# The message "CopyBothResponse" identifies the message as a Start Copy Both response. This message is used only for Streaming Replication.
				
				buffer = StreamPeerBuffer.new()
				
				# Get overall copy format code.
				# 0 indicates the overall COPY format is textual (rows separated by newlines, columns separated by separator characters, etc). 1 indicates the overall copy format is binary (similar to DataRow format). See COPY for more information.
				var overall_copy_format_code = response_buffer.subarray(5, 6)
				overall_copy_format_code.invert()
				
				buffer.put_data(overall_copy_format_code)
				buffer.seek(0)
				
				overall_copy_format_code = buffer.get_8()
				
				# Get the number of columns in the data to be copied.
				var number_of_columns = response_buffer.subarray(7, 9)
				number_of_columns.invert()
				
				buffer.put_data(number_of_columns)
				buffer.seek(1)
				
				number_of_columns = buffer.get_16()
				
				# Get the format codes to be used for each column.
				# Each must presently be zero (text) or one (binary). All must be zero if the overall copy format is textual.
				for index in number_of_columns:
					var format_code = response_buffer.subarray(10, 12)
					format_code.invert()
					
					buffer.put_data(format_code)
					buffer.seek(2 * index + 3)
					
					format_code = buffer.get_16()
					
					# The result.
					print(format_code)
				
				push_warning("[PostgreSQLClient:%d] CopyBothResponse, no support." % [get_instance_id()])
			'Z':
				### ReadyForQuery ###
				
				# Identifies the message type. ReadyForQuery is sent whenever the backend is ready for a new query cycle.
				
				# Get current backend transaction status indicator.
				match char(response_buffer[message_length]):
					'I':
						# If idle (if not in a transaction block).
						prints("Not in a transaction block.")
					'T':
						# If in a transaction block.
						prints("In a transaction block.")
					'E':
						# If in a failed transaction block (queries will be rejected until block is ended).
						prints("In a failed transaction block.")
					_:
						# We close the connection with the backend if current backend transaction status indicator is not recognized.
						close(false)
				
				var data_returned := datas_command_sql
				
				datas_command_sql = []
				response_buffer = PoolByteArray()
				
				
				if status == Status.STATUS_CONNECTING:
					status = Status.STATUS_CONNECTED
					
					# Once logged in, the database password and username are deleted from memory for security reasons.
					password_global = ""
					user_global = ""
					
					emit_signal("connection_established")
				
				return data_returned
			'c':
				### CopyDone ###
				
				# Identifies the message as a COPY-complete indicator.
				print("CopyDone")
			'd':
				### CopyData ###
				
				# Identifies the message as COPY data.
				
				# Get data that forms part of a COPY data stream. Messages sent from the backend will always correspond to single data rows.
				var data := response_buffer.subarray(5, message_length)
				
				# The result
				print(data)
			'n':
				### NoData ###
				
				# Identifies the message as a no-data indicator.
				pass
			's':
				### ReadyForQuery ###
				
				#Identifies the message as a portal-suspended indicator. Note this only appears if an Execute message's row-count limit was reached.
				pass
			't':
				### ParameterDescription ###
				
				# Identifies the message as a parameter description.
				
				# Get the number of parameters used by the statement (can be zero).
				var number_of_parameters = response_buffer.subarray(5, 6)
				number_of_parameters.invert()
				
				buffer.put_data(number_of_parameters)
				buffer.seek(4)
				
				number_of_parameters = buffer.get_16()
				
				# Then, for each parameter, there is the following:
				var data_types = []
				var cursor := 7
				for index in number_of_parameters:
					# Get the object ID of the parameter data type.
					var object_id = response_buffer.subarray(cursor, cursor + 4)
					object_id.invert()
					
					buffer.put_data(object_id)
					buffer.seek(cursor + index - 1)
					
					data_types.append(buffer.get_32())
					
					cursor += 5
				
				# The result.
				print(data_types)
			'v':
				### NegotiateProtocolVersion ###
				
				# Identifies the message as a protocol version negotiation message.
				
				# Get newest minor protocol version supported by the server for the major protocol version requested by the client.
				var minor_protocol_version = response_buffer.subarray(5, 8)
				minor_protocol_version.invert()
				
				buffer.put_data(minor_protocol_version)
				buffer.seek(4)
				
				minor_protocol_version = buffer.get_u32()
				
				# Get the number of protocol options not recognized by the server.
				var number_of_options = response_buffer.subarray(9, 13)
				number_of_options.invert()
				
				buffer.put_data(number_of_options)
				buffer.seek(8)
				
				number_of_options = buffer.get_u32()
				
				# Then, for each protocol option not recognized by the server...
				var cursor := 0
				for _index in number_of_options:
					# Get the option name.
					pass
				
				# The result.
				prints(minor_protocol_version)
			'1':
				### ParseComplete ###
				
				# Identifies the message as a Parse-complete indicator.
				pass
			'2':
				### BindComplete ###
				
				# Identifies the message as a Bind-complete indicator.
				pass
			'3':
				### CloseComplete ###
				
				# Identifies the message as a Close-complete indicator.
				pass
			var message_type:
				# We close the connection with the backend if the type of message is not recognized.
				
				status = Status.STATUS_ERROR
				
				push_error("[PostgreSQLClient:%d] The type of message sent by the backend is not recognized (%c)." % [get_instance_id(), message_type])
				
				close(false)
		
		# The response from the server can contain several messages, we read the message then delete the message to be processed to read the next one in the loop.
		if response_buffer.size() != message_length + 1:
			response_buffer = response_buffer.subarray(message_length + 1, -1)
		else:
			response_buffer.resize(0)
