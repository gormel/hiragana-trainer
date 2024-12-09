local M = {}

M.components = {}
M.buttons = {}
M.lists = {}
M.idx = 0

local function register(component)
	M.idx = M.idx + 1
	local idx = M.idx
	M.components[idx] = component
	table.insert(component.array, idx)
	return idx
end

function M.add_button(node, callback)
	return register({ node = node, callback = callback, array = M.buttons })
end

function M.del_component(handle)
	local component = M.components[handle]
	if component ~= nil then
		M.components[handle] = nil
		local array = component.array
		for i = #array, 1, -1 do
			if array[i] == handle then
				table.remove(array, i)
			end
		end

		if component.on_remove then
			component.on_remove()
		end
	end
end

local function fill_list(node, item_template_node, data, bind_fn, idx, nodes, components)
    for i = #components, 1, -1 do
		M.del_component(components[i])
		table.remove(components, i)
    end
    for i = #nodes, 1, -1 do
		gui.delete_node(nodes[i])
		table.remove(nodes, i)
    end

	local list_size = gui.get_size(node)
	local element_size = gui.get_size(item_template_node)
	local cols = math.floor(list_size.x / element_size.x)
	local rows = math.floor(list_size.y / element_size.y)
	local t_idx = idx
	for r = 1, rows do
		for c = 1, cols do
			if t_idx <= #data then
				local tree_clone = gui.clone_tree(item_template_node)
				for _, handle in ipairs({ bind_fn(tree_clone, data[t_idx]) }) do
					table.insert(components, handle)
				end

				local clone_root = tree_clone[gui.get_id(item_template_node)]
				table.insert(nodes, clone_root)

				gui.set_parent(clone_root, node, false)
				gui.set_position(clone_root, vmath.vector3(element_size.x * (c - 1), element_size.y * (r - 1), 0))

				t_idx = t_idx + 1
			end
		end
	end

	return cols * rows
end

function M.add_list(node, item_template_node, data, bind_fn)
	local nodes = {}
	local components = {}
	local start_idx = 1
	local page = fill_list(node, item_template_node, data, bind_fn, start_idx, nodes, components)

	local function clear()
		for i = #components, 1, -1 do
			M.del_component(components[i])
		end
		for i = #nodes, 1, -1 do
			gui.delete_node(nodes[i])
		end
	end

	local component = { array = M.lists, on_remove = clear }
	local function flip(shift)
		local t_idx = start_idx
		local n_idx = math.min(math.max(t_idx + shift, 1), #data)
		if n_idx ~= t_idx then
			start_idx = n_idx
			page = fill_list(node, item_template_node, data, bind_fn, start_idx, nodes, components)
		end
	end

	local function prev()
		flip(-page)
	end

	local function next()
		flip(page)
	end

	return register(component), prev, next
end

function M.on_input(action_id, action)
	if action_id == hash("touch") and action.pressed then
		for i = 1, #M.buttons do
			local button = M.components[M.buttons[i]]
			if gui.is_enabled(button.node, true) and button.callback and gui.pick_node(button.node, action.x, action.y) then
				button.callback()
				return true
			end
		end
	end
	return false
end

function M.final()
	for k, _ in pairs(M.components) do
		M.del_component(k)
	end
end

return M