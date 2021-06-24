# Written by Samuel MARZIN
# Detailed documentation: https://github.com/Marzin-bot/PostgreSQLClient/wiki/Documentation

extends Object

class_name PostgreSQLClient

## Backend runtime parameters
## A dictionary that contains various information about the state of the server.
## For security reasons the dictionary is always empty if the frontend is disconnected from the backend and updates once the connection is established.
var parameter_status := {}

## Version number (minor.major) of the PostgreSQL protocol used when connecting to the backend.
const PROTOCOL_VERSION := 3.0

# not using
var is_connected_to_host := false

# Determines if we "authenticate" to the server.
var authentication := false

var password_global: String
var user_global: String

var client := StreamPeerTCP.new()
var peerstream := PacketPeerStream.new()
#var ssl = StreamPeerSSL.new()

var peer
func _init() -> void:
	#client.connect("connection_closed", self, "_executer")
	
	peerstream.set_stream_peer(client)
	peer = peerstream.stream_peer

signal connection_closed(was_clean_close)
signal connection_error #no use
signal connection_established


# True when the server is ready to receive new data.
var rep = true

##################No use at the moment###############
## The process ID of this backend.
var process_backend_id: int

##################No use at the moment###############
## The secret key of this backend.
var process_backend_secret_key: int


## Allows you to connect to a Postgresql backend at the specified url.
func connect_to_host(url: String, ssl := false, connect_timeout := 30) -> int:
	var error := 1
	
	# If the fontend was already connected to the backend, we disconnect it before reconnecting.
	if authentication:
		close()
	
	var regex = RegEx.new()
	# https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
	regex.compile("^(?:postgresql|postgres)://(.+):(.+)@(.+)(:\\d*)/(.+)")
	
	var result = regex.search(url)
	
	if result:
		if ssl:
			### SSLRequest ###
			set_ssl_connection()
		
		### StartupMessage ###
		var startup_message = request("", "user".to_ascii() + PoolByteArray([0]) + result.strings[1].to_utf8() + PoolByteArray([0]) + "database".to_ascii() + PoolByteArray([0]) + result.strings[5].to_utf8() + PoolByteArray([0, 0]))
		
		password_global = result.strings[2]
		user_global = result.strings[1]
		
		# The default port for postgresql.
		var port = 5432
		
		if result.strings[4]:
			port = int(result.strings[4])
		
		#ssl.connect_to_stream(peer)
		error = client.connect_to_host(result.strings[3], port)
		
		while client.get_status() == StreamPeerTCP.STATUS_CONNECTED and error == OK:
			if client.is_connected_to_host() and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				# Get the fist message of server.
				if rep:
					peer.put_data(startup_message)
					rep = false
				
				var reponce = peer.get_data(peer.get_available_bytes())
				
				if reponce[0] == OK and reponce[1].size():
					var servire = reponce_parser(reponce[1])
					
					if !authentication:
						peer.put_data(servire)
					else:
						# Once logged in, the database password and username are deleted from memory for security reasons.
						password_global = ""
						user_global = ""
						
						emit_signal("connection_established")
						
						break
	
	return error


## Close the connexion to host.
func close(clean_closure := true) -> void:
	if authentication:
		if clean_closure:
			### Terminate ###
			peer.put_data(request('X', PoolByteArray()))
		
		client.disconnect_from_host()
		
		parameter_status = {}
		
		authentication = false
		
		emit_signal("connection_closed", clean_closure)
	else:
		push_warning("[PostgreSQLClient:%d] Le fontend étai déjà déconnecter du frontend au moment de l'appel de close()." % [get_instance_id()])


## Run an SQL script and return an array from PostgreSQLQueryResult (can be an empty array).
func execute(sql: String) -> Array:
	if authentication:
		peer.put_data(request('Q', sql.to_utf8() + PoolByteArray([0])))
		
		while client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if client.is_connected_to_host():
				# ssl.poll()
				
				var reponce = peer.get_data(peer.get_available_bytes())
				
				if reponce[0] == OK and reponce[1].size():
					
					var result = reponce_parser(reponce[1])
					if result != null:
						return result
				
			else:
				#disconnect
				break
	else:
		push_error("[PostgreSQLClient:%d] The frontend is not connected to backend." % [get_instance_id()])
	
	return []


## Active SSL
func set_ssl_connection():
	### SSLRequest ###
	
	var buffer := StreamPeerBuffer.new()
	
	# Length of message contents in bytes, including self.
	buffer.put_u32(8)
	
	var message_length := buffer.data_array
	
	message_length.invert()
	
	buffer.put_data(message_length)
	
	# The SSL request code.
	# The value is chosen to contain 1234 in the most significant 16 bits, and 5679 in the least significant 16 bits. (To avoid confusion, this code must not be the same as any protocol version number.)
	buffer.put_u32(12345679)
	
	
	peer.put_data(buffer.data_array.subarray(4, -1))


## This function undoes all changes made to the database since the last Commit.
func rollback(process_id: int, process_key: int) -> void:
	### CancelRequest ###
	
	if authentication:
		var buffer := StreamPeerBuffer.new()
		
		# Length of message contents in bytes, including self.
		buffer.put_u32(16)
		
		var message_length := buffer.data_array
		
		message_length.invert()
		
		buffer.put_data(message_length)
		
		# The cancel request code.
		# The value is chosen to contain 1234 in the most significant 16 bits, and 5678 in the least 16 significant bits. (To avoid confusion, this code must not be the same as any protocol version number.)
		buffer.put_u32(12345678)
		
		# The process ID of the target backend.
		buffer.put_u32(process_id)
		
		# The secret key for the target backend.
		buffer.put_u32(process_key)
		
		peer.put_data(buffer.data_array.subarray(4, -1))
	else:
		push_error("[PostgreSQLClient:%d] The frontend is not connected to backend." % [get_instance_id()])


var valide = false

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
	
	return buffer.data_array.subarray(4, -1)


func get_32bit_invert(integer: int) -> PoolByteArray:
	var buffer := StreamPeerBuffer.new()
	
	buffer.put_32(integer)
	
	var bit := buffer.data_array
	bit.invert()
	
	return bit


enum DataTypePostgreSQL {
	BOOLEAN = 16,
	SMALLINT = 21,
	INTEGER = 23,
	BIGINT = 20,
	REAL = 700,
	DOUBLE_PRECISION = 701,
	TEXT = 25,
	JSON = 114,
	JSONB = 3802,
	BITEA = 17,
	POINT = 600,
	BOX = 603,
	LSEG = 601,
	LINE = 628,
	CIRCLE = 718
}


class PostgreSQLQueryResult:
	## Specifies the number of fields in a row (can be zero).
	var number_of_fields_in_a_row := 0

	## Row description
	var row_description := []
	
	## An Array that contains sub-arrays. these sub-arrays represented for most of the queries the rows of the table where the query was executed. The number of sub-tables depends on the query that has been made. These sub-arrays contain as many elements as number_of_fields_in_a_row. These elements are native GDscript types that represent the data resulting from the query.Data row
	var data_row := []
	
	## This is usually a single word that identifies which SQL command was completed.
	var command_tag: String
	
	
	## Function that returns all the values ​​of a field.
	## field_name is the name of the field on which we get the values. Can be empty if the field name is unknown. The field_name parameter is case sensitive.
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


	## Returns the object ID of the data type of the field. field_name is the name of the field whose type we get. Can return -1 if the field name is unknown. The field_name parameter is case sensitive.
	func field_data_type(field_name: String) -> int:
		for i in number_of_fields_in_a_row:
			if row_description[i]["field_name"] == field_name:
				return row_description[i]["type_object_id"]
		
		return -1


var postgresql_query_result_instance := PostgreSQLQueryResult.new()

var datas_command_sql = []

var response_buffer: PoolByteArray

func reponce_parser(response: PoolByteArray):
	response_buffer += response
	
	while client.get_status() == StreamPeerTCP.STATUS_CONNECTED and response_buffer.size() > 4:
		# Get the length of the response.
		var longeur_data = response_buffer.subarray(1, 4)
		longeur_data.invert()
		
		var buffer := StreamPeerBuffer.new()
		buffer.put_data(longeur_data)
		buffer.seek(0)
		
		# Message length
		var message_length = buffer.get_u32()
		
		# Mf the size of the buffer is not equal to the length of the message, the request is not processed immediately.
		if response_buffer.size() < message_length + 1:
			break
		
		# Message_type
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
				
				# Number of column values ​​that follow (can be zero).
				var number_of_columns = response_buffer.subarray(5, 6)
				number_of_columns.invert()
				
				buffer.put_data(number_of_columns)
				buffer.seek(4)
				
				number_of_columns = buffer.get_16()
				
				var cursor := 0
				var row := []
				
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
						
						value_length = 0
					else:
						var value_data := response_buffer.subarray(cursor + 11, cursor + value_length + 10)
						var error: int
						
						match postgresql_query_result_instance.row_description[i]["type_object_id"]:
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
							DataTypePostgreSQL.SMALLINT, DataTypePostgreSQL.INTEGER, DataTypePostgreSQL.BIGINT:
								### SMALLINT or INTEGER or BIGINT ###
								
								# The type returned is int.
								# The result.
								row.append(int(value_data.get_string_from_ascii()))
							DataTypePostgreSQL.REAL, DataTypePostgreSQL.DOUBLE_PRECISION:
								### REAL or DOUBLE PRECISION ###
								
								# The type returned is float.
								# The result.
								row.append(float(value_data.get_string_from_ascii()))
							DataTypePostgreSQL.TEXT:
								### TEXT ###
								
								# The type returned is String.
								# The result.
								row.append(value_data.get_string_from_utf8())
							"PoolStringArray":
								### CHARACTER ###
								
								# The type returned is PoolStringArray.
								pass
							"tsvector":
								pass
							"tsquery":
								pass
							"XML":
								### XML ###
								
								# The type returned is XMLParser.
								var xml := XMLParser.new()
								
								error = xml.open_buffer(value_data)
								if error == OK:
									# The result.
									row.append(xml)
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid XML object. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									return
							DataTypePostgreSQL.JSON, DataTypePostgreSQL.JSONB:
								### JSON or JSONB ###
								
								# The type returned is JSONParseResult.
								var json = JSON.parse(value_data.get_string_from_utf8())
								
								if json.error_string:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid JSON/JSONB object: %s (Error line: %d)" % [get_instance_id(), json.error_string, json.error_line])
									
									close(false)
									return
								else:
									# The result.
									row.append(json)
							"Bit":
								### BIT ###
								pass
							DataTypePostgreSQL.BITEA:
								### BITEA ###
								################################# support no complet ##############################
								# The type returned is PoolByteArray.
								var bitea_data := value_data.get_string_from_ascii()
								
								if bitea_data.substr(2).is_valid_hex_number():
									var bitea := PoolByteArray()
									
									for i_hex in value_data.size() * 0.5 - 1:
										bitea.append(("0x" + bitea_data[i_hex+2] + bitea_data[i_hex+2]).hex_to_int())
									
									# The result.
									row.append(bitea)
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid BITEA object." % [get_instance_id()])
									
									close(false)
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
							"UUID":
								### UUID ###
								pass
							"cidr":
								### CIDR ###
								pass
							"inet":
								### INET ###
								pass
							"macaddr":
								### MACADDR ###
								pass
							"macaddr8":
								### MACADDR8 ###
								pass
							DataTypePostgreSQL.POINT:
								### POINT ###
								
								# The type returned is Vector2.
								var regex = RegEx.new()
								
								error = regex.compile("^\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\)")
								if error:
									push_error("[PostgreSQLClient:%d] RegEx compilation of POINT object failed. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								
								if result:
									# The result.
									row.append(Vector2(float(result.strings[1]), float(result.strings[2])))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid POINT object." % [get_instance_id()])
									
									close(false)
									return
							DataTypePostgreSQL.BOX:
								### BOX ###
								
								# The type returned is Rect2.
								var regex = RegEx.new()
								
								error = regex.compile("^\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\),\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\)")
								if error:
									push_error("[PostgreSQLClient:%d] RegEx compilation of BOX object failed. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								if result:
									# The result.
									row.append(Rect2(float(result.strings[3]), float(result.strings[4]), float(result.strings[1]), float(result.strings[2])))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid BOX object." % [get_instance_id()])
									
									close(false)
									return
							DataTypePostgreSQL.LSEG:
								### LSEG ###
								
								# The type returned is PoolVector2Array.
								var regex = RegEx.new()
								
								error = regex.compile("^\\[\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\),\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\)\\]")
								if error:
									push_error("[PostgreSQLClient:%d] RegEx compilation of LSEG object failed. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								if result:
									# The result.
									row.append(PoolVector2Array([Vector2(float(result.strings[1]), float(result.strings[2])), Vector2(float(result.strings[3]), float(result.strings[4]))]))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid LSEG object." % [get_instance_id()])
									
									close(false)
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
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								
								if result:
									# The result.
									row.append(Vector3(float(result.strings[1]), float(result.strings[2]), float(result.strings[3])))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid LINE object." % [get_instance_id()])
									
									close(false)
									return
							DataTypePostgreSQL.CIRCLE:
								### CIRCLE ###
								
								# The type returned is Vector3.
								
								#row.append(value_data.get_string_from_ascii())
								var regex = RegEx.new()
								
								error = regex.compile("^<\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\),(\\d+(\\.\\d+)?)>")
								if error:
									push_error("[PostgreSQLClient:%d] RegEx compilation of CIRCLE object failed. (Error: %d)" % [get_instance_id(), error])
									
									close(false)
									return
									
								var result = regex.search(value_data.get_string_from_ascii())
								if result:
									# The result.
									row.append(Vector3(float(result.strings[1]), float(result.strings[2]), float(result.strings[3])))
								else:
									push_error("[PostgreSQLClient:%d] The backend sent an invalid CIRCLE object." % [get_instance_id()])
									
									close(false)
									return
							_:
								# The type returned is PoolByteArray.
								row.append(value_data)
						
					cursor += value_length + 4
				
				# The result.
				postgresql_query_result_instance.data_row.append(row)
			'G', 'H', 'W':
				### CopyInResponse or CopyOutResponse or CopyBothResponse ###
				
				# The message "CopyInResponse" identifies the message as a Start Copy In response. The frontend must now send copy-in data (if not prepared to do so, send a CopyFail message).
				# The message "CopyOutResponse" identifies the message as a Start Copy Out response. This message will be followed by copy-out data.
				# The message "CopyBothResponse" identifies the message as a Start Copy Both response. This message is used only for Streaming Replication.
				print("CopyInResponse OR CopyOutResponse OR CopyBothResponse no implemented.")
			'E', 'N':
				### ErrorResponse or NoticeResponse ###
				
				for champ_data in split_pool_byte_array(response_buffer.subarray(5, message_length - 1), 0):
					var champ: String = champ_data.get_string_from_ascii()
					var field_type_id := champ[0]
					var value := champ.trim_prefix(field_type_id)
					
					match field_type_id:
						'S':
							if value == "FATAL":
								authentication = false
								
								emit_signal("connection_closed", true)
							
							prints("Severity:", value)
						'V':
							prints("Severity no localized:", value)
						'C':
							prints("SQLSTATE code:", value)
						'M':
							prints("Message:", value)
							push_error("[PostgreSQLClient:%d] %s" % [get_instance_id(), value])
						'D':
							prints("Detail:", value)
						'H':
							prints("Hint:", value)
						'P':
							prints("Position:", value)
						'p':
							prints("Internal position:", value)
						'q':
							prints("Internal query:", value)
						'W':
							prints("Where:", value)
						's':
							prints("Schema name:", value)
						't':
							prints("Table name:", value)
						'c':
							prints("Column name:", value)
						'd':
							prints("Data type name:", value)
						'n':
							prints("Constraint name:", value)
						'F':
							prints("File:", value)
						'L':
							prints("Line:", value)
						'R':
							prints("Routine:", value)
						_:
							close(false)
			'I':
				### EmptyQueryResponse ###
				
				# Identifies the message as a response to an empty query string. (This substitutes for CommandComplete.)
				print("EmptyQueryResponse")
			'K':
				### BackendKeyData ####
				
				# Identifies the message as cancellation key data. The frontend must save these values if it wishes to be able to issue CancelRequest messages later.
				
				# Get the process ID of this backend.
				var process_backend_id = response_buffer.subarray(5, 8)
				process_backend_id.invert()
				
				buffer.put_data(process_backend_id)
				buffer.seek(4)
				
				process_backend_id = buffer.get_u32()
				
				# Get the secret key of this backend.
				var process_backend_secret_key = response_buffer.subarray(9, message_length)
				process_backend_secret_key.invert()
				
				buffer.put_data(process_backend_secret_key)
				buffer.seek(8)
				
				process_backend_secret_key = buffer.get_u32()
				
				# The result.
				prints(process_backend_id, process_backend_secret_key)
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
						
						authentication = true
					2:
						### AuthenticationKerberosV5 ###
						
						print("AuthenticationKerberosV5")
						close(false)
					3:
						### AuthenticationCleartextPassword ###
						
						response_buffer = PoolByteArray()
						return request('p', password_global.to_utf8())
					5: 
						### AuthentificationMD5Password ###
						
						var ctx = HashingContext.new()
						ctx.start(HashingContext.HASH_MD5)
						ctx.update((password_global + user_global).md5_buffer().hex_encode().to_ascii() + response_buffer.subarray(9, 12))
						
						response_buffer = PoolByteArray()
						return request('p', "md5".to_ascii() + ctx.finish().hex_encode().to_ascii() + PoolByteArray([0]))
					6:
						### AuthenticationSCMCredential ###
						
						print("AuthenticationSCMCredential")
						close(false)
					7:
						### AuthenticationGSS ###
						
						print("AuthenticationGSS")
						close(false)
					8:
						### AuthenticationGSSContinue ###
						
						print("AuthenticationGSSContinue")
						close(false)
					9:
						### AuthenticationSSPI ###
						
						print("AuthenticationSSPI")
						close(false)
					10:
						### AuthenticationSASL ###
						
						print("AuthenticationSASL")
						close(false)
					11:
						### AuthenticationSASLContinue ###
						
						print("AuthenticationSASLContinue")
						close(false)
					12:
						### AuthenticationSASLFinal ###
						
						print("AuthenticationSASLFinal")
						close(false)
					_:
						push_error("[PostgreSQLClient:%d] Code d'autenfication inconnu" % [get_instance_id()])
						
						close(false)
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
				
				postgresql_query_result_instance.number_of_fields_in_a_row = buffer.get_16()
				
				# Then, for each field...
				var cursor := 7
				for _i in postgresql_query_result_instance.number_of_fields_in_a_row:
					# Get the field name.
					var field_name := ""
					
					for octet in response_buffer.subarray(cursor, message_length):
						field_name += char(octet)
						
						# If we get to the end of the chain, we get out of the loop.
						if !octet:
							break
					
					cursor += len(field_name)
					
					buffer = StreamPeerBuffer.new()
					
					# Get the object ID of the table.
					# If the field can be identified as a column of a specific table, the object ID of the table; otherwise zero.
					var table_object_id = response_buffer.subarray(cursor, cursor + 4)
					table_object_id.invert()
					
					buffer.put_data(table_object_id)
					buffer.seek(0)
					
					table_object_id = buffer.get_32()
					
					# Get the attribute number of the column.
					# If the field can be identified as a column of a specific table, the attribute number of the column; otherwise zero.
					var column_index = response_buffer.subarray(cursor + 5, cursor + 6)
					column_index.invert()
					
					buffer.put_data(column_index)
					buffer.seek(4)
					
					column_index = buffer.get_16()
					
					# Get the object ID of the field's data type.
					var type_object_id = response_buffer.subarray(cursor + 7, cursor + 10)
					type_object_id.invert()
					
					buffer.put_data(type_object_id)
					buffer.seek(6)
					
					type_object_id = buffer.get_32()
					
					# Get the data type size.
					# Note that negative values denote variable-width types.
					var data_type_size = response_buffer.subarray(cursor + 11, cursor + 12)
					data_type_size.invert()
					
					buffer.put_data(data_type_size)
					buffer.seek(10)
					
					data_type_size = buffer.get_16()
					
					# Get the type modifier.
					# The meaning of the modifier is type-specific.
					var type_modifier = response_buffer.subarray(cursor + 13, cursor + 16)
					type_modifier.invert()
					
					buffer.put_data(type_modifier)
					buffer.seek(12)
					
					type_modifier = buffer.get_32()
					
					# Get the format code being used for the field.
					# Currently will be zero (text) or one (binary). In a RowDescription returned from the statement variant of Describe, the format code is not yet known and will always be zero.
					var format_code = response_buffer.subarray(cursor + 17, cursor + 18)
					format_code.invert()
					
					buffer.put_data(format_code)
					buffer.seek(16)
					
					format_code = buffer.get_16()
					
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
				print("FunctionCallResponse no implemented.")
			'W':
				### CopyBothResponse ###
				
				# Identifies the message as a Start Copy Both response. This message is used only for Streaming Replication.
				print("CopyBothResponse no implemented.")
			'Z':
				### ReadyForQuery ###
				
				# Identifies the message type. ReadyForQuery is sent whenever the backend is ready for a new query cycle.
				match char(response_buffer[message_length]):
					'I':
						# If idle (if not in a transaction block).
						prints("Not in a transaction block.")
					'T':
						# If in a transaction block.
						prints("In a transaction block.")
					'E':
						# If in a failed transaction block.
						prints("In a failed transaction block.")
					_:
						# We close the connection with the backend if current backend transaction status indicator is not recognized.
						close(false)
				
				var data_returned: Array = datas_command_sql
				
				datas_command_sql = []
				response_buffer = PoolByteArray()
				
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
				print("NoData")
			's':
				### ReadyForQuery ###
				
				#Identifies the message as a portal-suspended indicator. Note this only appears if an Execute message's row-count limit was reached.
				print("ReadyForQuery")
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
				for i in number_of_parameters:
					# Get the object ID of the parameter data type.
					var object_id = response_buffer.subarray(cursor, cursor + 4)
					object_id.invert()
					
					buffer.put_data(object_id)
					buffer.seek(cursor + i - 1)
					
					data_types.append(buffer.get_32())
					
					cursor += 5
				
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
				for _i in number_of_options:
					# Get the option name.
					pass
				
				# The result.
				prints(minor_protocol_version)
			'1':
				### ParseComplete ###
				
				# Identifies the message as a Parse-complete indicator.
				print("ParseComplete")
			'2':
				### BindComplete ###
				
				# Identifies the message as a Bind-complete indicator.
				print("BindComplete")
			'3':
				### CloseComplete ###
				
				# Identifies the message as a Close-complete indicator.
				print("CloseComplete")
			var message_type:
				# We close the connection with the backend if the type of message is not recognized.
				push_error("[PostgreSQLClient:%d] The type of message envoyer pas le backend is not recognized (%c)." % [get_instance_id(), message_type])
				
				close(false)
		
		# The response from the server can contain several messages, we read the message then delete the message to be processed to read the next one in the loop.
		if response_buffer.size() != message_length + 1:
			response_buffer = response_buffer.subarray(message_length + 1, -1)
		else:
			response_buffer = PoolByteArray()


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
