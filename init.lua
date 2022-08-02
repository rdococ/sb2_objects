--[[
Object interface:
	doReceive(process, context, message, arg)
		Called by the 'Ask/Tell Object' blocks to perform a message send.
		Expected to report either nil (meaning the object does not understand the message) or a MessageResult.

Any object implementing doReceive automatically becomes an SB2 Object, able to receive messages sent by 'Ask Object', 'Tell Object' and 'Forward Message'.
]]

sb2.Object = sb2.registerClass("object")

function sb2.Object:new(closure)
	if closure:getContext():getAttribute("objects:receiver") then return closure:getContext():getAttribute("objects:receiver") end
	
	local inst = self:rawNew()
	inst.closure = closure
	closure:getContext():setAttribute("objects:receiver", inst)
	
	return inst
end
function sb2.Object:doReceive(process, context, message, arg)
	return self.closure:doCall(process, context, {name = message, arg = arg})
end
function sb2.Object:recordString(record)
	return string.format("<object>")
end

--[[
MessageResult interface:
	getResult()
		Returns the result.

MessageResult is a wrapper over the result of a message send. MessageResult indicates that the object understood the message and reacted appropriately even if the object reports nil. This allows the implementation of conditional message forwarding akin to multiple embedding in Golang.
]]

sb2.MessageResult = sb2.registerClass("messageResult")

function sb2.MessageResult:new(result)
	local inst = self:rawNew()
	inst.result = result
	return inst
end
function sb2.MessageResult:getResult()
	return self.result
end

sb2.colors.objects = "#666666"

sb2.registerScriptblock("sb2_objects:create_object", {
	sb2_label = "Create Object",
	
	sb2_explanation = {
		shortExplanation = "Creates and reports an object, a unit of behaviour that can respond to a fixed set of messages.",
		inputSlots = {
			{"Right", "A set of response definitions."}
		},
		additionalPoints = {
			"Use 'Define Response' to define how this object responds to specific messages.",
			"Objects can store private data in variables from where they were created.",
			"To build a class, build a procedure that reports an object!"
		}
	},
	
	sb2_color = sb2.colors.objects,
	sb2_icon  = "sb2_icon_create_object.png",
	sb2_slotted_faces = {"right"},
	
	after_place_node = function (pos, placer, itemstack, pointed_thing)
		local placerName = placer and placer:get_player_name()
		
		local meta = minetest.get_meta(pos)
		local body
		
		local itemMeta = itemstack:get_meta()
		local itemId = itemMeta:get_string("id")
		if itemId ~= "" then
			local existingBody = sb2.ClosureBody:fromName(itemId)
			if existingBody then
				if placerName then
					minetest.chat_send_player(placerName, "This object has already been placed. Creating a new object.")
				end
				
				sb2.log("warning", "Attempted to place closure %s at %s, but it already exists at %s. Generating a new name.", itemId, minetest.pos_to_string(pos), minetest.pos_to_string(existingBody:getPos()))
			else
				body = sb2.ClosureBody:newNamed(itemId, pos)
			end
			
			itemstack:set_count(0)
		end
		
		body = body or sb2.ClosureBody:new(pos)
		local id = body:getName()
		
		sb2.log("action", "Closure %s created at %s", id, minetest.pos_to_string(pos))
		meta:set_string("id", id)
		
		if placerName then
			meta:set_string("owner", placerName)
		end
		
		meta:set_string("infotext", string.format("Owner: %s", placerName or "(unknown)"))
	end,
	on_destruct = function (pos)
		local id = minetest.get_meta(pos):get_string("id")
		if id ~= "" then
			sb2.log("action", "Closure %s destroyed at %s", id, minetest.pos_to_string(pos))
			
			local body = sb2.ClosureBody:fromName(id)
			if body then
				body:delete()
			end
		end
	end,
	
	on_receive_fields = function (pos, formname, fields, sender)
		local senderName = sender:get_player_name()
		if minetest.is_protected(pos, senderName) then return end
		
		local node = minetest.get_node(pos)
		local dirs = sb2.facedirToDirs(node.param2)
		
		local meta = minetest.get_meta(pos)
		local id = meta:get_string("id")
		
		if id == "" then return end
		
		meta:set_string("infotext", string.format("Owner: %s", meta:get_string("owner")))
	end,
	
	preserve_metadata = function (pos, oldNode, oldMeta, drops)
		local drop = drops[1]
		local itemMeta = drop:get_meta()
		
		local id = oldMeta.id or ""
		
		if id == "" then return end
		
		itemMeta:set_string("id", id)
		itemMeta:set_string("description", string.format("Create Object Scriptblock %s", id:sub(1, 8)))
	end,
	
	sb2_action = function (pos, node, process, frame, context)
		local dirs = sb2.facedirToDirs(node.param2)
		local meta = minetest.get_meta(pos)
		
		local closure = frame:getArg("call")
		if closure then
			local meta = minetest.get_meta(pos)
			
			local funcContext = closure:getContext():copy()
			funcContext:setOwner(meta:get_string("owner"))
			funcContext:setAttribute("objects:message", frame:getArg(1))
			
			process:pop()
			return process:push(sb2.Frame:new(vector.add(pos, dirs.right), funcContext))
		else
			local id = meta:get_string("id")
			if id == "" then return process:report(nil) end
			
			body = sb2.ClosureBody:fromName(id)
			
			if not body then body = sb2.ClosureBody:newNamed(id, pos) end
			body:update(pos)
			
			local object = sb2.Object:new(sb2.Closure:new(body, context))
			return process:report(object)
		end
	end,
})

sb2.registerScriptblock("sb2_objects:get_myself", {
	sb2_label = "Get Myself",
	
	sb2_explanation = {
		shortExplanation = "Gets the recipient of the current message.",
		additionalPoints = {
			"Use this in the body of a Create Object block!"
		}
	},
	
	sb2_color = sb2.colors.objects,
	sb2_icon  = "sb2_icon_get_receiver.png",
	
	sb2_action = sb2.simple_action {
		arguments = {},
		action = function (pos, node, process, frame, context)
			return context:getAttribute("objects:receiver")
		end
	}
})

sb2.registerScriptblock("sb2_objects:define_response", {
	sb2_label = "Define Response",
	
	sb2_explanation = {
		shortExplanation = "Defines an object's response to a specific message.",
		inputValues = {
			{"Message", "The name of the message."},
			{"Parameter", "The name of the parameter."}
		},
		inputSlots = {
			{"Right", "What to do when the object receives this message."},
			{"Front", "Other responses if the object did not receive this message."}
		},
		additionalPoints = {
			"Use this in the body of a Create Object block!"
		}
	},
	
	sb2_color = sb2.colors.objects,
	sb2_icon  = "sb2_icon_receive.png",
	sb2_slotted_faces = {"right", "front"},
	
	after_place_node = function (pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		
		meta:set_string("infotext", "Message: \"\"\nParameter: \"\"")
		meta:set_string("formspec", [[
			formspec_version[4]
			size[10,7.5]
			field[2.5,1;5,1;message;Message;${message}]
			field[2.5,2.5;5,1;parameter;Parameter;${parameter}]
			button_exit[3.5,6;3,1;proceed;Proceed]
		]])
	end,
	
	on_receive_fields = function (pos, formname, fields, sender)
		local senderName = sender:get_player_name()
		if minetest.is_protected(pos, senderName) then minetest.record_protection_violation(pos, senderName); return end
		
		local meta = minetest.get_meta(pos)
		
		if fields.message then
			meta:set_string("message", fields.message)
		end
		if fields.parameter then
			meta:set_string("parameter", fields.parameter)
		end
		
		meta:set_string("infotext", string.format("Message: %q\nParameter: %q", meta:get_string("message"), meta:get_string("parameter")))
	end,
	
	sb2_action = function (pos, node, process, frame, context)
		local dirs = sb2.facedirToDirs(node.param2)
		local meta = minetest.get_meta(pos)
		
		local message = context:getAttribute("objects:message")
		if not message or message.name ~= meta:get_string("message") then
			process:pop()
			return process:push(sb2.Frame:new(vector.add(pos, dirs.front), context))
		end
		
		if not frame:isArgEvaluated("result") then
			frame:selectArg("result")
			
			local funcContext = context:copy()
			funcContext:declareVar(meta:get_string("parameter"), message.arg)
			
			return process:push(sb2.Frame:new(vector.add(pos, dirs.right), funcContext))
		end
		
		return process:report(sb2.MessageResult:new(frame:getArg("result")))
	end,
})

sb2.registerScriptblock("sb2_objects:forward_message", {
	sb2_label = "Forward Message",
	
	sb2_explanation = {
		shortExplanation = "Forwards messages to the given object.",
		inputSlots = {
			{"Right", "The object to receive the forwarded message."},
			{"Front", "Other responses if the object does not have a response for this message."}
		},
		additionalPoints = {
			"Use this in the body of a Create Object block!"
		}
	},
	
	sb2_color = sb2.colors.objects,
	sb2_icon  = "sb2_icon_forward_message.png",
	sb2_slotted_faces = {"right", "front"},
	
	sb2_action = function (pos, node, process, frame, context)
		local dirs = sb2.facedirToDirs(node.param2)
		local meta = minetest.get_meta(pos)
		
		local message = context:getAttribute("objects:message")
		if not message then
			process:pop()
			return process:push(sb2.Frame:new(vector.add(pos, dirs.front), context))
		end
		
		if not frame:isArgEvaluated("forwardee") then
			frame:selectArg("forwardee")
			return process:push(sb2.Frame:new(vector.add(pos, dirs.right), context))
		end
		
		local forwardee = frame:getArg("forwardee")
		if type(forwardee) ~= "table" or not forwardee.doReceive then
			process:pop()
			return process:push(sb2.Frame:new(vector.add(pos, dirs.front), context))
		end
		
		if not frame:isArgEvaluated("result") then
			frame:selectArg("result")
			return forwardee:doReceive(process, context, message.name, message.arg)
		end
		
		local result = frame:getArg("result")
		if result ~= nil then
			return process:report(result)
		end
		
		process:pop()
		return process:push(sb2.Frame:new(vector.add(pos, dirs.front), context))
	end,
})

sb2.registerScriptblock("sb2_objects:ask_object", {
	sb2_label = "Ask Object",
	
	sb2_explanation = {
		shortExplanation = "Sends a message to an object and reports the result.",
		inputValues = {
			{"Message", "The name of the message to send."},
		},
		inputSlots = {
			{"Front", "The object to send the message to."},
			{"Right", "The argument to pass with the message."}
		}
	},
	
	sb2_color = sb2.colors.objects,
	sb2_icon  = "sb2_icon_ask_object.png",
	sb2_slotted_faces = {"front", "right"},
	
	sb2_input_name = "message",
	sb2_input_label = "Message",
	sb2_input_default = "",
	
	sb2_action = function (pos, node, process, frame, context)
		local dirs = sb2.facedirToDirs(node.param2)
		local meta = minetest.get_meta(pos)
		
		if not frame:isArgEvaluated("object") then
			frame:selectArg("object")
			return process:push(sb2.Frame:new(vector.add(pos, dirs.front), context))
		end
		if not frame:isArgEvaluated(1) then
			frame:selectArg(1)
			return process:push(sb2.Frame:new(vector.add(pos, dirs.right), context))
		end
		
		local object = frame:getArg("object")
		if type(object) ~= "table" or not object.doReceive then return process:report(nil) end
		
		if not frame:isArgEvaluated("result") then
			frame:selectArg("result")
			return object:doReceive(process, context, meta:get_string("message"), frame:getArg(1))
		end
		
		local result = frame:getArg("result")
		if type(result) == "table" and result.getResult then
			return process:report(result:getResult())
		end
		
		return process:report(nil)
	end,
})

sb2.registerScriptblock("sb2_objects:tell_object", {
	sb2_label = "Tell Object",
	
	sb2_explanation = {
		shortExplanation = "Sends a message to an object, then continues.",
		inputValues = {
			{"Message", "The name of the message to send."},
		},
		inputSlots = {
			{"Left", "The object to send the message to."},
			{"Right", "The argument to pass with the message."},
			{"Front", "What to do afterwards."}
		}
	},
	
	sb2_color = sb2.colors.objects,
	sb2_icon  = "sb2_icon_send.png",
	sb2_slotted_faces = {"left", "right", "front"},
	
	sb2_input_name = "message",
	sb2_input_label = "Message",
	sb2_input_default = "",
	
	sb2_action = function (pos, node, process, frame, context)
		local dirs = sb2.facedirToDirs(node.param2)
		local meta = minetest.get_meta(pos)
		
		if not frame:isArgEvaluated("object") then
			frame:selectArg("object")
			return process:push(sb2.Frame:new(vector.add(pos, dirs.left), context))
		end
		if not frame:isArgEvaluated(1) then
			frame:selectArg(1)
			return process:push(sb2.Frame:new(vector.add(pos, dirs.right), context))
		end
		
		local object = frame:getArg("object")
		if type(object) ~= "table" or not object.doReceive then return process:report(nil) end
		
		if not frame:isArgEvaluated("result") then
			frame:selectArg("result")
			return object:doReceive(process, context, meta:get_string("message"), frame:getArg(1))
		end
		
		process:pop()
		return process:push(sb2.Frame:new(vector.add(pos, dirs.front), context))
	end,
})