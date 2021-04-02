extends Object

class_name PostgreSQLClient

## backend runtime parameters
var parameter_status := {}

## protocol_version
const PROTOCOL_VERSION := 3.0

# not using
var is_connected_to_host := false

# détermine si on est authentifié auprès du serveur
var authentication := false

var password_global: String
var user_global: String

var client := StreamPeerTCP.new()
var peerstream := PacketPeerStream.new()
#var ssl = StreamPeerSSL.new()

var peer
func _init() -> void:
	peerstream.set_stream_peer(client)
	peer = peerstream.stream_peer

signal connection_closed(was_clean_close)
signal connection_error
signal connection_established


# True quand le serveur est prêt réservoir de nouvelles données.
var rep = true


#####################No use at the moment###############
## L'ID de processus de ce backend
var process_backend_id: int

## La clé secrète de ce backend
var process_backend_secret_key: int


#test ssl
var ssl = false

## Connects to a postgreSQL database at the specified url.
func connect_to_host(url: String, connect_timeout := 30) -> int:
	var error := 1
	
	# si le frontend était déjà connecté au backend, nous le déconnectons avant de se reconnecter.
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
		
		error = client.connect_to_host(result.strings[3], port)
		
		# ssl.connect_to_stream(peer)
		
		while client.get_status() == StreamPeerTCP.STATUS_CONNECTED and error == OK:
			if client.is_connected_to_host() and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				# Get the fist message of server.
				if rep:
					peer.put_data(startup_message)
					rep = false
				
				var reponce = peer.get_data(peer.get_available_bytes())
				
				if reponce[0] == OK and reponce[1].size():
					var servire = reponce_interpretation(reponce[1])
					
					if !authentication:
						peer.put_data(servire)
					else:
						# Une fois connecté, supprime le mot de passe et le nom d'utilisateur de la base de données pour des raisons de sécurité.
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
		
		authentication = false
		
		emit_signal("connection_closed", clean_closure)
	else:
		push_warning("La frontend était déjà déconnectée du backend lorsque close() a été appelé.")


## Execute un script SQL et renvoi le résultat des commands du script en question.
func execute(sql: String) -> Array:
	if authentication:
		peer.put_data(request('Q', sql.to_utf8() + PoolByteArray([0])))
		
		while client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if client.is_connected_to_host():
				# ssl.poll()
				
				var reponce = peer.get_data(peer.get_available_bytes())
				
				if reponce[0] == OK and reponce[1].size():
					
					var result = reponce_interpretation(reponce[1])
					if result != null:
						return result
				
			else:
				print("déconnecter")
				break
	else:
		push_error("The frontend is not connected to backend.")
	
	return []


## Active SSL
func set_ssl_connection():
	### SSLRequest ###
	var buffer := StreamPeerBuffer.new()
	
	# Length of message contents in bytes, including self.
	buffer.put_32(8)
	
	var message_length := buffer.data_array
	
	message_length.invert()
	
	buffer.put_data(message_length)
	
	# The SSL request code.
	# The value is chosen to contain 1234 in the most significant 16 bits, and 5679 in the least significant 16 bits. (To avoid confusion, this code must not be the same as any protocol version number.)
	buffer.put_u32(80877103)
	
	peer.put_data(buffer.data_array.subarray(4, -1))


## Cette function annule toutes les modifications apportées à la base de données depuis le dernier Commit
func rollback(process_id: int, process_key: int) -> void:
	### CancelRequest ###
	
	if authentication:
		var buffer := StreamPeerBuffer.new()
		
		# Length of message contents in bytes, including self.
		buffer.put_32(16)
		
		var message_length := buffer.data_array
		
		message_length.invert()
		
		buffer.put_data(message_length)
		
		# The cancel request code.
		# The value is chosen to contain 1234 in the most significant 16 bits, and 5678 in the least 16 significant bits. (To avoid confusion, this code must not be the same as any protocol version number.)
		buffer.put_u32(80877102)
		
		# The process ID of the target backend.
		buffer.put_32(process_id)
		
		# The secret key for the target backend.
		buffer.put_32(process_key)
		
		peer.put_data(buffer.data_array.subarray(4, -1))
	else:
		push_error("The frontend is not connected to backend.")


var valide = false

func request(type_message: String, message := PoolByteArray()) -> PoolByteArray:
	# Get the size of message.
	var buffer := StreamPeerBuffer.new()
	
	buffer.put_32(message.size() + (4 if type_message else 8))
	
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

var datas_command_sql = []
var datas = []
var type_object_id_in_row = []

var reponce: PoolByteArray


func reponce_interpretation(reponcee: PoolByteArray):
	reponce += reponcee
	
	while client.get_status() == StreamPeerTCP.STATUS_CONNECTED and reponce.size() > 4:
		# Get the length of the response
		var longeur_data = reponce.subarray(1, 4)
		longeur_data.invert()
		
		var buffer := StreamPeerBuffer.new()
		buffer.put_data(longeur_data)
		buffer.seek(0)
		
		# longeur du message
		var message_length = buffer.get_u32()
		
		if reponce.size() < message_length + 1:
			print("Trop petit")
			break
		
		# message_type
		match char(reponce[0]):
			'A':
				### NotificationResponse ###
				
				# Get the process ID of the notifying backend process.
				var process_id = reponce.subarray(5, 8)
				process_id.invert()
				
				buffer.put_data(process_id)
				buffer.seek(4)
				
				process_id = buffer.get_32()
				
				# We get the following parameters.
				var situation_report_data := split_pool_byte_array(reponce.subarray(5, message_length), 0)
				
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
				var tag = reponce.subarray(5, message_length).get_string_from_ascii()
				
				# The result (don't using).
				print(tag)
				
				datas_command_sql.append(datas)
				
				type_object_id_in_row = []
				datas = []
			'D':
				### DataRow ###
				
				# Nombre de valeurs de colonnes qui suivent (peut valoir zéro).
				var number_of_columns = reponce.subarray(5, 6)
				number_of_columns.invert()
				
				buffer.put_data(number_of_columns)
				buffer.seek(4)
				
				number_of_columns = buffer.get_16()
				
				var cursor := 0
				var row := []
				
				for i in number_of_columns:
					var value_length = reponce.subarray(cursor + 7, cursor + 10)
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
						var value_data := reponce.subarray(cursor + 11, cursor + value_length + 10)
						var error: int
						
						match type_object_id_in_row[i]:
							16:
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
										push_error("(PostgreSQLClient) The backend sent an invalid BOOLEAN object. Column value is not recognized: " + value_column)
										
										close(false)
							21, 23, 20:
								### SMALLINT or INTEGER or BIGINT ###
								
								# The type returned is int.
								# The result.
								row.append(int(value_data.get_string_from_ascii()))
							700, 701:
								### REAL or DOUBLE PRECISION ###
								
								# The type returned is float.
								# The result.
								row.append(float(value_data.get_string_from_ascii()))
							25:
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
									push_error("(PostgreSQLClient) The backend sent an invalid XML object. (Error: %d)" % [error])
									
									close(false)
									return
							114, 3802:
								### JSON or JSONB ###
								
								# The type returned is JSONParseResult.
								var json = JSON.parse(value_data.get_string_from_utf8())
								
								if not json.error_string:
									# The result.
									row.append(json)
								else:
									push_error("(PostgreSQLClient) The backend sent an invalid JSON/JSONB object: %s (Error line: %d)" % [json.error_string, json.error_line])
									
									close(false)
									return
							"Bit":
								### BIT ###
								pass
							17:
								### BITEA ###
								################################# support no complet ##############################
								# The type returned is PoolByteArray.
								var bitea_data = value_data.get_string_from_ascii()
								
								if bitea_data.substr(2).is_valid_hex_number():
									var bitea := PoolByteArray()
									
									for i_hex in value_data.size() * 0.5 - 1:
										bitea.append(("0x" + bitea_data[i_hex+2] + bitea_data[i_hex+2]).hex_to_int())
									
									# The result.
									row.append(bitea)
								else:
									push_error("(PostgreSQLClient) The backend sent an invalid BITEA object.")
									
									close(false)
									return
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
							600:
								### POINT ###
								
								# The type returned is Vector2.
								var regex = RegEx.new()
								
								error = regex.compile("^\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\)")
								if error:
									push_error("(PostgreSQLClient) RegEx compilation of POINT object failed. (Error: %d)" % [error])
									
									close(false)
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								
								if result:
									# The result.
									row.append(Vector2(float(result.strings[1]), float(result.strings[2])))
								else:
									push_error("(PostgreSQLClient) The backend sent an invalid POINT object.")
									
									close(false)
									return
							603:
								### BOX ###
								
								# The type returned is Rect2.
								var regex = RegEx.new()
								
								error = regex.compile("^\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\),\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\)")
								if error:
									push_error("(PostgreSQLClient) RegEx compilation of BOX object failed. (Error: %d)" % [error])
									
									close(false)
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								if result:
									# The result.
									row.append(Rect2(float(result.strings[3]), float(result.strings[4]), float(result.strings[1]), float(result.strings[2])))
								else:
									push_error("(PostgreSQLClient) The backend sent an invalid BOX object.")
									
									close(false)
									return
							601:
								### LSEG ###
								
								# The type returned is PoolVector2Array.
								var regex = RegEx.new()
								
								error = regex.compile("^\\[\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\),\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\)\\]")
								if error:
									push_error("(PostgreSQLClient) RegEx compilation of LSEG object failed. (Error: %d)" % [error])
									
									close(false)
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								if result:
									# The result.
									row.append(PoolVector2Array([Vector2(float(result.strings[1]), float(result.strings[2])), Vector2(float(result.strings[3]), float(result.strings[4]))]))
								else:
									push_error("(PostgreSQLClient) The backend sent an invalid LSEG object.")
									
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
							628:
								### LINE ###
								
								# The type returned is Vector3.
								var regex = RegEx.new()
								
								error = regex.compile("^\\{(-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\}")
								if error:
									push_error("(PostgreSQLClient) RegEx compilation of LINE object failed. (Error: %d)" % [error])
									
									close(false)
									return
								
								var result = regex.search(value_data.get_string_from_ascii())
								
								if result:
									# The result.
									row.append(Vector3(float(result.strings[1]), float(result.strings[2]), float(result.strings[3])))
								else:
									push_error("(PostgreSQLClient) The backend sent an invalid LINE object.")
									
									close(false)
									return
							718:
								### CIRCLE ###
								
								# The type returned is Vector3.
								
								#row.append(value_data.get_string_from_ascii())
								var regex = RegEx.new()
								
								error = regex.compile("^<\\((-?\\d+(?:\\.\\d+)?),(-?\\d+(?:\\.\\d+)?)\\),(\\d+(\\.\\d+)?)>")
								if error:
									push_error("(PostgreSQLClient) RegEx compilation of CIRCLE object failed. (Error: %d)" % [error])
									
									close(false)
									return
									
								var result = regex.search(value_data.get_string_from_ascii())
								if result:
									# The result.
									row.append(Vector3(float(result.strings[1]), float(result.strings[2]), float(result.strings[3])))
								else:
									push_error("(PostgreSQLClient) The backend sent an invalid CIRCLE object.")
									
									close(false)
									return
							_:
								# The type returned is PoolByteArray.
								row.append(value_data)
						
					cursor += value_length + 4
				
				# The result.
				datas.append(row)
			'G', 'H', 'W':
				### CopyInResponse or CopyOutResponse or CopyBothResponse ###
				
				# The message "CopyInResponse" identifies the message as a Start Copy In response. The frontend must now send copy-in data (if not prepared to do so, send a CopyFail message).
				# The message "CopyOutResponse" identifies the message as a Start Copy Out response. This message will be followed by copy-out data.
				# The message "CopyBothResponse" identifies the message as a Start Copy Both response. This message is used only for Streaming Replication.
				print("CopyInResponse OR CopyOutResponse OR CopyBothResponse no implemented.")
			'E', 'N':
				### ErrorResponse or NoticeResponse ###
				
				for champ_data in split_pool_byte_array(reponce.subarray(5, message_length - 1), 0):
					var champ: String = champ_data.get_string_from_ascii()
					var field_type_id := champ[0]
					var value := champ.trim_prefix(field_type_id)
					
					match field_type_id:
						'S':
							prints("Severity:", value)
						'V':
							prints("Severity no localized:", value)
						'C':
							prints("SQLSTATE code:", value)
						'M':
							prints("Message:", value)
							push_error("(PostgreSQLClient) " + value)
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
				var process_backend_id = reponce.subarray(5, 8)
				process_backend_id.invert()
				
				buffer.put_data(process_backend_id)
				buffer.seek(4)
				
				process_backend_id = buffer.get_u32()
				
				# Get the secret key of this backend.
				var process_backend_secret_key = reponce.subarray(9, message_length)
				process_backend_secret_key.invert()
				
				buffer.put_data(process_backend_secret_key)
				buffer.seek(8)
				
				process_backend_secret_key = buffer.get_u32()
				
				# The result.
				prints(process_backend_id, process_backend_secret_key)
			'R':
				### Authentication ###
				
				# Identifies the message as an authentication request.
				var authentication_type_data := reponce.subarray(5, 8)
				
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
						
						reponce = PoolByteArray()
						return request('p', password_global.to_utf8())
					5: 
						### AuthentificationMD5Password ###
						
						var ctx = HashingContext.new()
						ctx.start(HashingContext.HASH_MD5)
						ctx.update((password_global + user_global).md5_buffer().hex_encode().to_ascii() + reponce.subarray(9, 12))
						
						reponce = PoolByteArray()
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
						push_error("Code d'autenfication inconnu")
						
						close(false)
			'S':
				### ParameterStatus ###
				
				# Identifies the message as a run-time parameter status report.
				var situation_report_data := split_pool_byte_array(reponce.subarray(5, message_length), 0)
				
				# Get the name of the run-time parameter being reported.
				var parameter: String = situation_report_data[0].get_string_from_utf8()
				
				# Get the current value of the parameter.
				var value: String = situation_report_data[1].get_string_from_utf8()
				
				# The result
				parameter_status[parameter] = value
			'T':
				### RowDescription ###
				
				# Get the number of fields in a row (can be zero).
				var number_of_value = reponce.subarray(5, 6)
				number_of_value.invert()
				
				buffer.put_data(number_of_value)
				buffer.seek(4)
				
				number_of_value = buffer.get_16()
				
				# Then, for each field...
				var cursor := 6
				for _i in number_of_value:
					# Get the field name.
					var name_field := ""
					
					for octet in reponce.subarray(cursor, message_length):
						name_field += char(octet)
						
						# Si on arrive a la fin de la chaine on sort de la boucle
						if !octet:
							break
					
					cursor += len(name_field)
					
					buffer = StreamPeerBuffer.new()
					
					# Get the object ID of the table.
					# If the field can be identified as a column of a specific table, the object ID of the table; otherwise zero.
					var table_object_id = reponce.subarray(cursor, cursor + 4)
					table_object_id.invert()
					
					buffer.put_data(table_object_id)
					buffer.seek(0)
					
					table_object_id = buffer.get_32()
					
					# Get the attribute number of the column.
					# If the field can be identified as a column of a specific table, the attribute number of the column; otherwise zero.
					var column_index = reponce.subarray(cursor + 5, cursor + 6)
					column_index.invert()
					
					buffer.put_data(column_index)
					buffer.seek(4)
					
					column_index = buffer.get_16()
					
					# Get the object ID of the field's data type.
					var type_object_id = reponce.subarray(cursor + 7, cursor + 10)
					type_object_id.invert()
					
					buffer.put_data(type_object_id)
					buffer.seek(6)
					
					type_object_id = buffer.get_32()
					
					# Get the data type size.
					# Note that negative values denote variable-width types.
					var data_type_size = reponce.subarray(cursor + 11, cursor + 12)
					data_type_size.invert()
					
					buffer.put_data(data_type_size)
					buffer.seek(10)
					
					data_type_size = buffer.get_16()
					
					# Get the type modifier.
					# The meaning of the modifier is type-specific.
					var type_modifier = reponce.subarray(cursor + 13, cursor + 16)
					type_modifier.invert()
					
					buffer.put_data(type_modifier)
					buffer.seek(12)
					
					type_modifier = buffer.get_32()
					
					# Get the format code being used for the field.
					# Currently will be zero (text) or one (binary). In a RowDescription returned from the statement variant of Describe, the format code is not yet known and will always be zero.
					var format_code = reponce.subarray(cursor + 17, cursor + 18)
					format_code.invert()
					
					buffer.put_data(format_code)
					buffer.seek(16)
					
					format_code = buffer.get_16()
					
					cursor += 19
					
					# The result.
					type_object_id_in_row.append(type_object_id)
					
					prints(name_field, table_object_id, column_index, type_object_id, data_type_size, type_modifier, format_code)
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
				match char(reponce[message_length]):
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
				reponce = PoolByteArray()
				
				return data_returned
			'c':
				### CopyDone ###
				
				# Identifies the message as a COPY-complete indicator.
				print("CopyDone")
			'd':
				### CopyData ###
				
				# Identifies the message as COPY data.
				
				# Get data that forms part of a COPY data stream. Messages sent from the backend will always correspond to single data rows.
				var data := reponce.subarray(5, message_length)
				
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
				var number_of_parameters = reponce.subarray(5, 6)
				number_of_parameters.invert()
				
				buffer.put_data(number_of_parameters)
				buffer.seek(4)
				
				number_of_parameters = buffer.get_16()
				
				# Then, for each parameter, there is the following:
				var data_types = []
				var cursor := 7
				for i in number_of_parameters:
					# Get the object ID of the parameter data type.
					var object_id = reponce.subarray(cursor, cursor + 4)
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
				var minor_protocol_version = reponce.subarray(5, 8)
				minor_protocol_version.invert()
				
				buffer.put_data(minor_protocol_version)
				buffer.seek(4)
				
				minor_protocol_version = buffer.get_u32()
				
				# Get the number of protocol options not recognized by the server.
				var number_of_options = reponce.subarray(9, 13)
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
				push_error("(PostgreSQLClient) The type of message envoyer pas le backend is not recognized (%c)." % [message_type])
				
				close(false)
		
		# Comme la reponce du serveur peu contenir plusieur messages on lit le message puis on suprime le message traiter pour lire le suivant dans la boucle
		reponce = reponce.subarray(message_length + 1, -1)


func split_pool_byte_array(pool_byte_array: PoolByteArray, delimiter: int) -> Array:
	var array := []
	var from := 0
	var to := 0
	
	for byte in pool_byte_array:
		if byte == delimiter:
			array.append(pool_byte_array.subarray(from, to))
			from = to + 1
		
		to += 1
		
	return array
