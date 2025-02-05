local pandoc = pandoc

local M = {
  LONG = 1,
  LAT = 2,
  ELE = 3,
  MP = 4,
  MILES_PER_METER = 0.000621371,
}

local function point_from_coords(c)
  return c
end

function M.copy_coords(dest, src)
  for i = 1, 4 do
    dest[i] = src[i]
  end
end

function M.read_file(fname)
  local file = assert(io.open(fname))
  local data = file:read("a")
  file:close()
  return data
end

function M.write_file(fname, data)
  local file = assert(io.open(fname, "w+"))
  assert(file:write(data))
  file:close()
end

function M.read_track(file)
  local data = pandoc.json.decode(M.read_file(file), false)
  local trails = {}
  for _, t in ipairs(data.trails) do
    local m = t.trackId:match("^%d%d%d_AZT Passage (%d*)")
    if m and m ~= "33" then
      local coordinates = t.geometry.coordinates[1]
      table.insert(trails, coordinates)
    end
  end
  table.sort(trails, function(a, b)
    return a[1][4] < b[1][4]
  end)
  local track = {}
  for _, trail in ipairs(trails) do
    for _, c in ipairs(trail) do
      table.insert(track, point_from_coords(c))
    end
  end
  return track
end

function M.read_waypoints(file)
  local waypoints = {}
  local data = pandoc.json.decode(M.read_file(file), false)
  for _, wp in ipairs(data.waypoints) do
    waypoints[wp.waypointId] = point_from_coords(wp.geometry.coordinates)
  end
  return waypoints
end

local waypoints = nil
function M.waypoint(id)
  if not waypoints then
    waypoints = M.read_waypoints("data/waypoints.json")
  end
  local wp = waypoints[id]
  if not wp then
    print("Waypoint not found for identifier " .. id)
    return { 0, 0, 0, 0 }
  end
  return wp
end

local trail_length = nil
function M.trail_length()
  if not trail_length then
    local wp = M.waypoint("AZT_Nothern Terminus")
    assert(wp)
    trail_length = wp[M.MP]
  end
  return trail_length
end

return M
