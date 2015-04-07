--# DESCRIPTION
--`xmpv.lua` is an extension of **MPV** and integrates with **TMSU** to provide the following features:
--* Tag files that you liked.
--* Show your favorite files.

--# USAGE

--* Hot keys:
--  * Alt+l: Increment likes.
--  * Alt+d: Decrement likes.
--  * Alt+r: Reset likes to zero.
--  * Alt+i: Print info.

--# INSTALL
--This script should be copied to `~/.config/mpv/scripts/` directory.

--# REFERENCE: 
--* http://bamos.github.io/2014/07/05/mpv-lua-scripting/
--* https://github.com/mpv-player/mpv/blob/master/DOCS/man/lua.rst
--* https://github.com/mpv-player/mpv/blob/master/DOCS/man/input.rst
--* `mpv --list-properties` lists all properties available.

require 'os'
require 'io'
require 'string'

likes_tag = "xlikes"
mark_tag  = "xmark"

file_name_for_cmd = ""


-- On "file-loaded", this function will run.
function initialization()
	file_name_for_cmd = get_file_name_for_cmd()
	check_tmsu()
end


-- ********************************************************************
-- Private functions
-- ********************************************************************

-- Increment the previous likes number by 1.
function increment_likes()

	local likes_number = get_likes_number()
	
	if(likes_number=="") then
		likes_number = 0
	else
		--Remove 'likes=xxx' tag: tmsu untag --tags="likes" <filename>
		local cmd_untag_likes = string.format("tmsu untag --tags=\"%s=%s\" %s", likes_tag, likes_number, file_name_for_cmd)
		execute_command(cmd_untag_likes)
	end
	
	--Increment the number of likes: tmsu tag --tags likes=123 <filename>
	likes_number = likes_number + 1
	local cmd_inc_likes_number = string.format("tmsu tag --tags=\"%s=%s\" %s", likes_tag, likes_number, file_name_for_cmd)
	print(cmd_inc_likes_number)
	execute_command(cmd_inc_likes_number)
	
end

-- Return length in seconds.
function get_length()
	local length = mp.get_property("length")
	
	-- Discard miliseconds
	length = string.gsub(length, "%.%d*", "")
	
	return length
end

-- Return number of likes.
function get_likes_number()
	
	-- Get raw tags of current file.
	local cmd_results = get_raw_tags()	
	
	-- Extract the number of likes.
	local likes_number = ""
	local likes_tag_pattern = likes_tag .. "="
	for token in string.gmatch(cmd_results, "%S+") do
		if string.starts(token, likes_tag_pattern) then
			likes_number = string.gsub(token, likes_tag_pattern, "")
		end
	end
	
	return likes_number
end

-- Return filename.
function get_file_name()
	return mp.get_property("path")
end

-- Execute command and return result.
function execute_command(command)
	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

-- Extract tags of file from TMSU.
function get_tags()

	-- Get raw tags of current file.
	local cmd_results = get_raw_tags()
	
	-- Remove <filename> from result.
  --    [ ]? => With or without a space. No space when no tag at all.
	cmd_results = string.gsub(cmd_results, "^.*:[ ]?", "")

	-- Remove 'likes=XXX' tag from result.
	--	Handle negative value too.
	local likes_tag_pattern = likes_tag .. "=[-]?%d*"
	cmd_results = string.gsub(cmd_results, likes_tag_pattern, "")

	-- Remove 'mark=XXXXX' tag from result.
	local mark_tag_pattern = mark_tag .. "=%d*[.]?%d*"
	cmd_results = string.gsub(cmd_results, mark_tag_pattern, "")
	
	-- Remove newline from result.
	cmd_results = string.gsub(cmd_results, "\n", "")
	
	-- Concatenate all tags with comma.
	local tags = ""
	for token in string.gmatch(cmd_results, "%S+") do
		-- Concatenate tags
		tags = tags .. ", " .. token
	end	
	
	-- Quick clean up of comma if there is only 1 tag.
	tags = string.gsub(tags, "^, ", "")
	
	return tags
end

-- Return raw tags, unformatted from TMSU.
function get_raw_tags()
	-- Get tags of current file: tmsu tags <filename>
	local cmd_get_tags = string.format("tmsu tags %s", file_name_for_cmd)
	return execute_command(cmd_get_tags)	

end

function get_file_name_for_cmd(filename)
	local filename = get_file_name()
	
	--Escape double quotes.
	filename = string.format('%q', filename)
	return filename
end

-- Log error if TMSU is not found.
function check_tmsu()
	local cmd_get_tmsu_version = "tmsu --version"
	local cmd_results = execute_command(cmd_get_tmsu_version)
	
	if (string.find(cmd_results, "TMSU")==nil) then
		local message = 	 string.format("ERROR: %s can't run.",mp.get_script_name()) .. "\n"
		message = message .. string.format("ERROR: It requires TMSU. Download it at http://tmsu.org/.")
		mp.msg.error(message)
	end	
end

-- Print top favorites/likes
function print_top_favorites()
	
	-- Get likes values: 'tmsu values <tagname>'.
	local cmd_get_likes_values = string.format("tmsu values %s", likes_tag)
	local cmd_results = execute_command(cmd_get_likes_values)
	
	-- Put likes values in array.
	local likes_values = {}
	local index = 0 -- In lua index starts from 1 instead of 0.
	for token in string.gmatch(cmd_results, "%S+") do
		if(token~=nil) then
			index = index + 1
			likes_values[index] = token
		end
	end	
	
	-- Sort likes values in ascending order by numerical value.
	table.sort(likes_values, function(a,b) return tonumber(a)<tonumber(b) end)
	
	-- Get top favorites
	local max_favorites = 10
	local n=1	-- n will get the final number of favorites.
	local top_favorites = {}
	for i=index,1,-1 do
		-- Put files into top_favorites array.
		local cmd_get_top_favorites = string.format("tmsu files \"%s=%d\"", likes_tag, likes_values[i])
		local cmd_results = execute_command(cmd_get_top_favorites)
		for line in string.gmatch(cmd_results, "[^\r\n]+") do 
			top_favorites[n] = string.format("[%4d] %s", likes_values[i], line)
			n = n + 1
		end
		
		-- Stop looping if it reaches max_favorites.
		if n > max_favorites then
			n = n - 1 -- Discard last increment of the loop above.
			break -- Terminate the loop instantly and do not repeat.
		end
	end
	
	-- Print top favorites
	--	Use n instead of max_favorites. Drawback: It will display all
	--		the 10th likes.
	print("-----------------------------------------------------------")
	print("[Likes]--------------- TOP FAVORITES ----------------------")
	for j=1,n do
		print(top_favorites[j]) 
	end
	
end

-- ********************************************************************
-- Library functions
-- ********************************************************************
function string.starts(String,Start)
	return string.sub(String,1,string.len(Start))==Start
end



-- ********************************************************************
-- Main features
-- ********************************************************************

-- Go to the next marked position.
--  Make it goes around: If it is the end, start over.
--  Special cases:
--    -No marked position.
--    -Only 1 marked position.
--    -Should not take current position == to mark position. Only the next bigger position.
--    -Can do Next, Next ...
function goto_next_mark_position()
  
  local mark_positions = get_mark_positions()
  if(table.getn(mark_positions) < 1) then
    mp.msg.warn("WARN: No marked position.")
  else
  
    local current_pos = mp.get_property("time-pos")
    local found_next_pos = false
    for i, mark_position in ipairs(mark_positions) do
      if tonumber(current_pos) < tonumber(mark_position) then
        mp.commandv("seek", mark_position, "absolute", "exact")
        found_next_pos = true
        mp.msg.warn("Goto ".. mark_position .. " => ".. toTimeFormat(mark_position))
        break
      end
    end
  
    -- 'Make it goes around logic' here.
    if ( not found_next_pos ) then
      mp.msg.warn("WARN: No more next marked position. RESTART.")
      mp.commandv("seek", mark_positions[1], "absolute", "exact")
    end
    
  end
   
end

-- Go to the previous marked position.
--  Make it goes around: If it is the beginning, go to the last position.
--  Special cases:
--    -No marked position.
--    -Only 1 marked position.
--    -Can do Previous, Previous ...
function goto_previous_mark_position()
  
  local mark_positions = get_mark_positions()
  local mark_positions_size = table.getn(mark_positions) 
  if(mark_positions_size < 1) then
    mp.msg.warn("WARN: No marked position.")
  else
  
    local current_pos = mp.get_property("time-pos")
    local found_previous_pos = false
    local previous_pos = mark_positions[mark_positions_size] -- Initialize previous position to be the last pos.
    for i, mark_position in ipairs(mark_positions) do
      if tonumber(current_pos) < tonumber(mark_position) then
        mp.commandv("seek", previous_pos, "absolute", "exact")
        found_previous_pos = true
        mp.msg.warn("Back to ".. previous_pos .. " => ".. toTimeFormat(previous_pos))
        break
      else
        previous_pos = mark_position
      end
    end
  
    -- 'Make it goes around logic' here: If previous pos not found, then goes to the last pos.
    if ( not found_previous_pos ) then
      mp.msg.warn("WARN: No more next marked position. RESTART.")
      mp.commandv("seek", mark_positions[mark_positions_size], "absolute", "exact")
    end
    
  end

end

-- Mark position but discard fraction of second.
function mark_position()
  local current_position = math.floor(mp.get_property("time-pos"))
  tmsu_tag(mark_tag, current_position, file_name_for_cmd)
end


-- Return a string of formatted marked positions.
--  Marked positions formatted as HH:MM:SS, HH:MM:SS, HH:MM:SS
function get_formatted_mark_positions()
  local mark_positions = get_mark_positions()
  for i, mark_position in ipairs(mark_positions) do
    mark_positions[i] = toTimeFormat(mark_position)
  end
  
  return table.concat(mark_positions, ", ")
end

-- Return seconds formatted as HH:MM:SS
function toTimeFormat(seconds)
  return string.format("%.2d:%.2d:%.2d", seconds/(60*60), seconds/60%60, seconds%60)
end

-- Return marked positions in ascending order
function get_mark_positions()

  local raw_tags = get_raw_tags()
  
  local mark_tag_label = mark_tag .."="
  local i = 1
  local mark_position_values = {}
	for token in string.gmatch(raw_tags, "%S+") do
		if string.starts(token, mark_tag_label) then
			mark_position_values[i]=string.gsub(token, mark_tag_label, "")
      i = i + 1
		end
	end

  table.sort(mark_position_values, function(a,b) return tonumber(a)<tonumber(b) end)  
  return mark_position_values
end


function tmsu_tag(tag_name, tag_value, cmd_file_path)
  local cmd_tag = string.format("tmsu tag --tags=\"%s=%s\" %s", tag_name, tag_value, cmd_file_path)
  execute_command(cmd_tag)
end

-- Auto increment the number of times likes, when playback has elapsed
--	for more than half.
function auto_increment_likes(event)
	mp.add_timeout((get_length()/2), increment_likes)
end


-- Decrement the previous likes number by 1.
function decrement_likes()

	local likes_number = get_likes_number()
	
	if(likes_number=="") then
		likes_number = 0
	else
		--Remove 'likes=xxx' tag: tmsu untag --tags="likes" <filename>
		local cmd_untag_likes = string.format("tmsu untag --tags=\"%s=%s\" %s", likes_tag, likes_number, file_name_for_cmd)
		execute_command(cmd_untag_likes)
	end	
	
	--Decrement the number of likes: tmsu tag --tags likes=123 <filename>
	likes_number = likes_number - 1
	local cmd_inc_likes_number = string.format("tmsu tag --tags=\"%s=%s\" %s", likes_tag, likes_number, file_name_for_cmd)
	print(cmd_inc_likes_number)
	execute_command(cmd_inc_likes_number)
	
end

-- Reset likes number to 0.
function reset_likes()

	local likes_number = get_likes_number()
	
	if(likes_number=="") then
		likes_number = 0
	else  
		--Remove 'likes=xxx' tag: tmsu untag --tags="likes" <filename>
		local cmd_untag_likes = string.format("tmsu untag --tags=\"%s=%s\" %s", likes_tag, likes_number, file_name_for_cmd)
		execute_command(cmd_untag_likes)
	end	
	
	--Set the number of likes to zero: tmsu tag --tags likes=0 <filename>
	likes_number = 0
	local cmd_inc_likes_number = string.format("tmsu tag --tags=\"%s=%s\" %s", likes_tag, likes_number, file_name_for_cmd)
	print(cmd_inc_likes_number)
	execute_command(cmd_inc_likes_number)
	
end

-- Print information about this file.
function print_stats()
	print("-----------------------------------------------------------")
	print("  Filename: " .. get_file_name())
	print("     Likes: " .. get_likes_number())
	print("      Tags: " .. get_tags())
  print("Marked Pos: " .. get_formatted_mark_positions())
	print()
end



------------------------------------------------------------------------
-- Set key bindings.
--	Note: Ensure this section to be at the end of file
--			so that all functions needed are defined.
------------------------------------------------------------------------
mp.add_key_binding("Alt+l", "increment_likes", increment_likes)
mp.add_key_binding("Alt+d", "decrement_likes", decrement_likes)
mp.add_key_binding("Alt+r", "reset_likes", reset_likes)
mp.add_key_binding("Alt+t", "top_favorites", print_top_favorites)
mp.add_key_binding("Alt+i", "show_statistics", print_stats)
mp.add_key_binding("Alt+m", "mark_position", mark_position)
mp.add_key_binding("Alt+n", "goto_next_mark_position", goto_next_mark_position)
mp.add_key_binding("Alt+b", "goto_previous_mark_position", goto_previous_mark_position)

-- Auto increment after X seconds.
mp.register_event("file-loaded", initialization)
mp.register_event("file-loaded", auto_increment_likes)

