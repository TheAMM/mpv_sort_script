function exclude_entries(entries)
	local filtered_entries = {}
	for i, entry in ipairs(entries) do
		if not entry:match(EXCLUDE_PATTERN) then
			filtered_entries[#filtered_entries+1] = entry
		end
		entries[i] = nil
	end
	for i, entry in ipairs(filtered_entries) do
		entries[i] = entry
	end
end


function filter_files(files)
	local filtered_files = {}
	for i, file in ipairs(files) do
		local ext = file:match('%.([^%.]+)$') or ''
		if EXTENSIONS[ext:lower()] then
			filtered_files[#filtered_files+1] = file
		end
		files[i] = nil
	end
	for i, file in ipairs(filtered_files) do
		files[i] = file
	end
end


function get_directory_entries(directory_path)
	local files = utils.readdir(directory_path, 'files') or {}
	local dirs  = utils.readdir(directory_path, 'dirs')  or {}
	filter_files(files)

	for i, v in ipairs(files) do
		files[i] = path_utils.join(directory_path, v)
	end
	for i, v in ipairs(dirs) do
		dirs[i] = path_utils.join(directory_path, v)
	end

	if EXCLUDE_PATTERN then
		exclude_entries(files)
		exclude_entries(dirs)
	end

	return files, dirs
end


function get_directory_entries_recursive(directory_path, current_depth)
	current_depth = current_depth or 0

	local files, dirs = get_directory_entries(directory_path)

	if current_depth < option_values.max_recurse_depth then
		for i, sub_directory_path in ipairs(dirs) do
			msg.verbose('Traversing into', sub_directory_path)
			local sub_files = get_directory_entries_recursive(sub_directory_path, current_depth + 1)

			for i, sub_file in ipairs(sub_files) do
				files[#files+1] = sub_file
			end
		end
	end

	return files, {}
end


function _sort_by_infos(entries, infos, sort, descending)
	local directory_entry_counts = {}
	function count_directory_entries(entry)
		local count = directory_entry_counts[entry]
		if not count then
			count = #(utils.readdir(entry) or {})
			directory_entry_counts[entry] = count
			msg.trace('Counted entries for directory:', entry, count)
		end
		return count
	end

	local namecomp = option_values.alphanumeric_sort and function(a, b) return alnumcomp(a, b) end or function(a, b) return a < b end

	local compfunc = function(a, b)
		local info_a = infos[a]
		local info_b = infos[b]

		if sort == 'name' then
			return namecomp(a,b)

		elseif sort == 'size' then
			-- Comparing files and directories is weirder, so let's decide all directories are 'less' than files
			-- This only happens when precedence is 'both'

			if info_a.is_dir and info_b.is_dir then
				-- Order by directory entry count (instead of 'filesize')
				return count_directory_entries(a) < count_directory_entries(b)
			elseif info_a.is_dir then
				return true
			elseif info_b.is_dir then
				return false
			else
				if info_a.size == info_b.size then
					return namecomp(a,b)
				else
					return info_a.size < info_b.size
				end
			end

		elseif sort == 'date' then
			if info_a.mtime == info_b.mtime then
				return namecomp(a,b)
			else
				return info_a.mtime < info_b.mtime
			end

		end
	end

	if sort == 'random' then
		-- Simple shuffle
		for i = #entries, 2, -1 do
			local j = math.random(i)
			entries[i], entries[j] = entries[j], entries[i]
		end
	else
		local used_sort = compfunc
		if descending then
			used_sort = function(a,b) return compfunc(b,a) end
		end
		table.sort(entries, used_sort)
	end
end


function sort_entries(files, dirs, sort, precedence, descending)
	local infos = {}
	for i, file in ipairs(files) do
		infos[file] = utils.file_info(file)
	end
	for i, dir in ipairs(dirs) do
		infos[dir] = utils.file_info(dir)
	end

	local entries = nil
	if precedence == 'files' then
		-- Sort files first, then directories
		_sort_by_infos(files, infos, sort, descending)
		_sort_by_infos(dirs, infos, sort, descending)

		entries = files
		for i, v in ipairs(dirs) do entries[#entries+1] = v end
	elseif precedence == 'dirs' then
		-- Sort directories first, then files
		_sort_by_infos(files, infos, sort, descending)
		_sort_by_infos(dirs, infos, sort, descending)

		entries = dirs
		for i, v in ipairs(files) do entries[#entries+1] = v end
	elseif precedence == 'mix' then
		-- Sort together
		entries = files
		for i, v in ipairs(dirs) do entries[#entries+1] = v end
		_sort_by_infos(entries, infos, sort, descending)
	end

	return entries, infos
end


mp.add_hook('on_load', 50, function()
	local path = mp.get_property_native('path')

	local sort_key = option_values.default_sort
	local sort_precedence = option_values.default_precedence
	local sort_descending = option_values.default_descending
	local sort_recursive  = option_values.recursive_sort

	local explicit_sort, real_path = path:match('^(/?r?sort.-:)(.+)$')
	if explicit_sort then
		path = real_path

		if explicit_sort:find('/') ~= 1 then
			-- prefix the sort protocol with / because load-unsafe-playlists doesn't like URIs in playlists
			explicit_sort = '/' .. explicit_sort
		end
		-- sort - normal sort; rsort - recursive sort
		sort_recursive = explicit_sort:find('r') == 2

		local custom_key = explicit_sort:match('^/r?sort%-(.-):$')
		if custom_key then
			-- Check if we want to sort ascending or descending
			if custom_key:match('[-+]$') then
				sort_descending = custom_key:sub(custom_key:len()) == '-'
				custom_key = custom_key:sub(1, custom_key:len() - 1)
			end

			if SORT_KEYS[custom_key] then
				sort_key = custom_key
			else
				msg.warn(('Ignoring bad sort key: %s. Allowed values: %s'):format(custom_key, table.concat(SORT_KEY_NAMES, ', ')))
			end
		end

	elseif option_values.always_sort then
		msg.debug('Implictly sorting path (always_sort enabled)!')
		-- Make up the sort prefix for later use
		explicit_sort = ('/%ssort-%s%s:'):format(sort_recursive and 'r' or '', sort_key, sort_descending and '-' or '+')
	else
		-- Not explicitly called or sorted by default, so exit
		return
	end

	local file_info = utils.file_info(path)
	if not file_info then
		-- Not a local file, abort
		if explicit_sort and not option_values.always_sort then
			msg.error('Unable to stat given path, aborting')
		end
		return
	end

	if file_info.is_dir then
		msg.verbose('Reading directory entries:', path)
		local files, dirs
		if sort_recursive then
			files, dirs = get_directory_entries_recursive(path)
		else
			files, dirs = get_directory_entries(path)
		end
		msg.verbose(('Got %d files, %d directories'):format(#files, #dirs))

		msg.verbose(('Sorting with: key: %s, sort_descending: %s, precedence: %s'):format(sort_key, sort_descending and 'true' or 'false', sort_precedence))
		if sort_precedence == 'mix' and sort_key == 'size' then
			msg.warn('Sorting both files and directories together by size may give unintuitive results')
		end

		if option_values.stable_random_sort and sort_key == 'random' then
			local seed_string = ('%s-%d-%d-%s'):format(path, #files, #dirs, option_values.random_seed)
			local seed_bytes = { seed_string:byte(1, #seed_string) }
			-- Simple djb2 hash to turn the string into a number
			local seed = 5381
			for i, b in ipairs(seed_bytes) do
				seed = seed * 33 + b
			end
			msg.verbose(('Using seed %d (%s) for stable random sort'):format(seed, seed_string))
			math.randomseed(seed)
		end

		local entries, infos = sort_entries(files, dirs, sort_key, sort_precedence, sort_descending)

		local playlist_lines = {'#EXTM3U'}
		for i, entry in ipairs(entries) do
			-- Prefix directories with our custom sort info, so we'll parse them too
			local prefix = infos[entry].is_dir and explicit_sort or ''
			playlist_lines[#playlist_lines+1] = '#EXTINF:0,' .. path_utils.basename(entry)
			playlist_lines[#playlist_lines+1] = prefix .. path_utils.abspath(entry)
		end

		local data = 'memory://' .. table.concat(playlist_lines, '\n')
		mp.set_property_native('stream-open-filename', data)
		mp.set_property_native('file-local-options/load-unsafe-playlists', true)

		msg.verbose(('Set sorted playlist with %d entries'):format(#entries))
	end

end)