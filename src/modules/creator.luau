local types = require("@types")
local binder = require("./binder")

local creator = {}

type Registration = {
	callback: ((any) -> ())?,
	previous: Registration?,
	next: Registration?,
}

function creator.Value(value: any): types.ValueState
	local callbacks = {}
	local first: Registration? = nil
	local last: Registration? = nil

	return binder.Wrap({
		Value = value,
		Connect = function(self, fn)
			local registration: Registration = { callback = fn, previous = last, next = nil }
			if last then
				last.next = registration
			else
				first = registration
			end
			last = registration
			callbacks[fn] = callbacks[fn] or {}
			table.insert(callbacks[fn], registration)
			return fn
		end,
		Disconnect = function(self, fn)
			local registrations = callbacks[fn]
			if not registrations then
				return
			end
			-- Connect returns the callback, so disconnect removes all registrations of it.
			callbacks[fn] = nil
			for _, registration in ipairs(registrations) do
				local previous, following = registration.previous, registration.next
				if previous then
					previous.next = following
				else
					first = following
				end
				if following then
					following.previous = previous
				else
					last = previous
				end
				registration.callback = nil
				registration.previous = nil
				registration.next = nil
			end
		end,
	}, {
		Value = function(newValue)
			-- Keep registration order; additions during notification wait for the next update.
			local pending = {}
			local registration = first
			while registration do
				table.insert(pending, registration)
				registration = registration.next
			end
			for _, entry in ipairs(pending) do
				local callback = entry.callback
				if callback then
					pcall(callback, newValue)
				end
			end
		end,
	})
end

function creator.Create(className: string)
	return function(properties)
		properties = properties or {}

		local instance = Instance.new(className)
		local bindings = {}
		local disposed = false

		for key, value in pairs(properties) do
			if key == "__dynamicKeys" and type(value) == "table" then
				for property, valueObject: types.ValueState in pairs(value) do
					pcall(function()
						instance[property] = valueObject.Value
					end)

					local function update(newValue)
						task.defer(pcall, function()
							if disposed then
								return
							end
							if properties["__contextKeys"] and properties["__contextKeys"]["_general"] then
								properties["__contextKeys"]["_general"]()
							end

							instance[property] = properties["__contextKeys"]
									and properties["__contextKeys"][property]
									and properties["__contextKeys"][property]()
								or newValue
						end)
					end
					valueObject:Connect(update)
					table.insert(bindings, { value = valueObject, callback = update })
				end

				continue
			end

			if typeof(value) == "table" and value.__unique then
				value.Parent = instance
			end

			pcall(function()
				instance[key] = value
			end)
		end

		if #bindings > 0 then
			instance.Destroying:Once(function()
				disposed = true
				for _, binding in ipairs(bindings) do
					if binding.value.Disconnect then
						binding.value:Disconnect(binding.callback)
					end
				end
				table.clear(bindings)
			end)
		end

		return setmetatable({ __unique = true }, {
			__metatable = instance,
			__index = function(_, key)
				if key == "__instance" then
					return instance
				end

				local value = instance[key]

				if typeof(value) == "function" then
					return function(_, ...)
						return value(instance, ...)
					end
				else
					return value
				end
			end,
			__newindex = function(_, key, value)
				instance[key] = value
			end,
		})
	end
end

return creator
