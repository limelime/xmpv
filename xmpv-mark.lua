-----------------------------------------------------------------------------
-- Likes class. 
-----------------------------------------------------------------------------
dofile("/root/.config/mpv/scripts/xmpv-tmsu.lua")

-- ***** Variables *****
Mark = {
  TAG_NAME="xmark",
  file_path="",
  
  tmsu = Tmsu:new(),
}

-- 'Constructor'
function Mark:new(o, file_path)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  
  -- Extra arguments
  self.file_path = file_path
  
  return o
end

--  It breeds from goto_previous_position().
function Mark:delete_previous_position()

  local mark_positions = self:get_mark_positions()
  local mark_positions_size = table.getn(mark_positions) 
  if(mark_positions_size < 1) then
    mp.msg.warn("WARN: No marked position.")
  else
  
    local current_pos = mp.get_property("time-pos")
    local found_previous_pos = false
    local previous_pos = mark_positions[mark_positions_size] -- Initialize previous position to be the last pos.
    for i, mark_position in ipairs(mark_positions) do
      if tonumber(current_pos) < tonumber(mark_position) then
        self.tmsu:untag(self.TAG_NAME, previous_pos, self.file_path)
        found_previous_pos = true
        local warn_msg = string.format("WARN: Delete marked position %s.", toTimeFormat(previous_pos))
        mp.msg.warn(warn_msg)        
        break
      else
        previous_pos = mark_position
      end
    end
  
    -- 'Make it goes around logic' here: If previous pos not found, then goes to the last pos.
    if ( not found_previous_pos ) then
      previous_pos = mark_positions[mark_positions_size]
      self.tmsu:untag(self.TAG_NAME, previous_pos, self.file_path)
      local warn_msg = string.format("WARN: Delete marked position %s.", toTimeFormat(previous_pos))
      mp.msg.warn(warn_msg)
    end
    
  end

end


-- Go to the next marked position.
--  Make it goes around: If it is the end, start over.
--  Special cases:
--    -No marked position.
--    -Only 1 marked position.
--    -Should not take current position == to mark position. Only the next bigger position.
--    -Can do Next, Next ...
function Mark:goto_next_position()
  
  local mark_positions = self:get_mark_positions()
  if(table.getn(mark_positions) < 1) then
    mp.msg.warn("WARN: No marked position.")
  else
  
    local current_pos = mp.get_property("time-pos")
    local found_next_pos = false
    for i, mark_position in ipairs(mark_positions) do
      if tonumber(current_pos) < tonumber(mark_position) then
        mp.commandv("seek", mark_position, "absolute", "exact")
        found_next_pos = true
        local warn_msg = string.format("Goto %d => %s.", mark_position, toTimeFormat(mark_position))
        mp.msg.warn(warn_msg)        
        break
      end
    end
  
    -- 'Make it goes around logic' here.
    if ( not found_next_pos ) then
      mp.commandv("seek", mark_positions[1], "absolute", "exact")
      local warn_msg = string.format("WARN: No more next marked position. Go to the first position at %s.", toTimeFormat(mark_positions[1]))
      mp.msg.warn(warn_msg)
    end
    
  end
   
end

-- Go to the previous marked position.
--  Make it goes around: If it is the beginning, go to the last position.
--  It breeds from goto_next_position().
--  Special cases:
--    -No marked position.
--    -Only 1 marked position.
--    -Can do Previous, Previous ...
function Mark:goto_previous_position()
  
  local mark_positions = self:get_mark_positions()
  local mark_positions_size = table.getn(mark_positions) 
  if(mark_positions_size < 1) then
    mp.msg.warn("WARN: No marked position.")
  else
  
    local current_pos = mp.get_property("time-pos") - 2 --  Minus 2 seconds to allow time for user to do Previous, Previous, ... 
    local found_previous_pos = false
    local previous_pos = mark_positions[mark_positions_size] -- Initialize previous position to be the last pos.
    for i, mark_position in ipairs(mark_positions) do
      if tonumber(current_pos) < tonumber(mark_position) then
        mp.commandv("seek", previous_pos, "absolute", "exact")
        found_previous_pos = true
        local warn_msg = string.format("Back to %d => %s.", previous_pos, toTimeFormat(previous_pos))
        mp.msg.warn(warn_msg)        
        break
      else
        previous_pos = mark_position
      end
    end
  
    -- 'Make it goes around logic' here: If previous pos not found, then goes to the last pos.
    if ( not found_previous_pos ) then
      previous_pos = mark_positions[mark_positions_size]
      mp.commandv("seek", previous_pos, "absolute", "exact")
      local warn_msg = string.format("WARN: No more previous marked position. Back to the last position at %s.", toTimeFormat(previous_pos))
      mp.msg.warn(warn_msg)
    end
    
  end

end

-- Mark position but discard fraction of second.
function Mark:mark_position()
  local current_position = math.floor(mp.get_property("time-pos"))
  self.tmsu:tag(self.TAG_NAME, current_position, self.file_path)
  
  -- OSD display
  local osd_text = string.format("M %s", toTimeFormat(current_position))
  mp.osd_message(osd_text, 1)
end


-- Return a string of formatted marked positions.
--  Marked positions formatted as HH:MM:SS, HH:MM:SS, HH:MM:SS
function Mark:get_formatted_positions()
  local mark_positions = self:get_mark_positions()
  for i, mark_position in ipairs(mark_positions) do
    mark_positions[i] = toTimeFormat(mark_position)
  end
  
  return table.concat(mark_positions, ", ")
end


-- Return marked positions in ascending order
function Mark:get_mark_positions()

  local raw_tags = self.tmsu:get_tags()
  
  local mark_tag_label = self.TAG_NAME .."="
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
