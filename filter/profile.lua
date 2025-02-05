local data = require('filter.data')
local ELE = data.ELE
local MP = data.MP

-- Elevation profile

-- return the distance and index of point furthest away from
-- the line defined by the points at index i1 and i2.
local function max_distance(points, i1, i2)
  if i1 == i2 then
    return i1, 0
  end
  local p1 = points[i1]
  local x1, y1 = p1[ELE], p1[MP]
  local p2 = points[i2]
  local x2, y2 = p2[ELE], p2[MP]
  local dx, dy = x2 - x1, y2 - y1
  local den = math.sqrt(dx ^ 2 + dy ^ 2)

  local max = -1
  local imax = i1

  for i = i1 + 1, i2 - 1 do
    local p = points[i]
    local x, y = p[ELE], p[MP]
    local num = math.abs(dx * (y1 - y) - (x1 - x) * dy)
    local d = num / den
    if d > max then
      max = d
      imax = i
    end
  end

  return imax, max
end

-- return a reduced set of points in the range i1 to i2
-- using using using the Ramer-Douglas-Peucker algorithm.
local function rdp(points, i1, i2, epsilon)
  local imax, max = max_distance(points, i1, i2)
  if max < epsilon then
    return { points[i1], points[i2] }
  end
  local left = rdp(points, i1, imax, epsilon)
  local right = rdp(points, imax, i2, epsilon)
  return table.move(right, 2, #right, #left + 1, left)
end

local function reduceTrack(points)
  local epsilon = 20.0 -- meters
  return rdp(points, 1, #points, epsilon)
end

local function track_range(points)
  local ele_min, mp_min = points[1][1], points[1][2]
  local ele_max, mp_max = ele_min, mp_min
  for _, p in ipairs(points) do
    local x, y = p[ELE], p[MP]
    ele_min = math.min(ele_min, x)
    ele_max = math.max(ele_max, x)
    mp_min = math.min(mp_min, y)
    mp_max = math.max(mp_max, y)
  end
  return ele_min, mp_min, ele_max, mp_max
end

local function profile_svg(track, callouts, width, height)
  -- Collect output in output.
  local output = {}
  local w = function(fmt, ...)
    table.insert(output, string.format(fmt:gsub("\n[ \t]*", " "), ...))
  end

  track = reduceTrack(track)
  local metersPer1KFeet = 304.8
  local ele_min, mp_min, ele_max, mp_max = track_range(track)

  -- Start at 1000'
  local x_min = 1 * metersPer1KFeet
  -- Allocate space for callout bends.
  local x_max = ele_max + (ele_max - ele_min) * 0.25

  local y_min, y_max = mp_min, mp_max
  if callouts and #callouts > 1 then
    local dy = (mp_max - mp_min) / (#callouts - 1)
    y_min = y_min - dy / 2
    y_max = y_max + dy / 2
  end

  w(
    [[<svg xmlns="http://www.w3.org/2000/svg" 
       width=%s height=%s
       preserveAspectRatio=none
       viewbox="%.0f %.0f %.0f %.0f">]],
    width,
    height,
    x_min,
    y_min,
    (x_max - x_min),
    (y_max - y_min)
  )

  w([[<defs>
        <LinearGradient id="profile-gradient">
          <stop offset="0%%" stop-color="darkred" />
          <stop offset="25%%" stop-color="darkorange" />
          <stop offset="55%%" stop-color="yellow" />
          <stop offset="90%%" stop-color="forestgreen" />
        </LinearGradient>
      </defs>]])

  -- Draw and fill the elevation profile.
  -- Use relative output to minimzie output size.
  do
    local path = {}
    do
      local xprev, yprev = 0, 0
      for _, p in ipairs(track) do
        local x, y = p[ELE], p[MP]
        table.insert(path, string.format("l%.0f %.0f", x - xprev, y - yprev))
        xprev, yprev = x, y
      end
      path[1] = string.format("M%.0f %.0f", track[1][ELE], track[1][MP])
      table.insert(path, string.format("L%.0f %.0f L%.0f %.0f Z", x_min, mp_max, x_min, mp_min))
    end

    w(
      [[<path id="profile" 
       d="%s"
       stroke="rgba(0, 0, 0, 0.6)",
       fill="url(#profile-gradient)",
       stroke-width="1px",
       vector-effect="non-scaling-stroke" />]],
      table.concat(path, " ")
    )
  end

  -- Draw elevation lines.
  w([[<clipPath id="profile-clip"><use href="#profile"/></clipPath>]])
  for i = 2, 9 do
    local x = i * metersPer1KFeet
    w(
      [[<path d="M%.0f %.0f L%.0f %.0f" 
          stroke="rgba(0, 0, 0, 0.3)"
          stroke-width="1px"
          vector-effect="non-scaling-stroke"
          fill="none"
          clip-path="url(#profile-clip)"/>]],
      x,
      mp_min,
      x,
      mp_max
    )
  end

  -- Draw callouts.
  if callouts and #callouts > 0 then
    local dy = (y_max - y_min) / #callouts
    local ctl = (ele_max - ele_min) * 0.1

    for i, p in ipairs(callouts) do
      local x, y1 = p[ELE], p[MP]
      local y2 = i * dy - dy / 2 + y_min
      w(
        [[<path
        d="M%0.f %0.f L%.0f %.0f C%.0f %.0f %.0f %.0f %.0f %.0f"
        stroke="black"
        stroke-width="1.5px"
        vector-effect="non-scaling-stroke"
        fill="none" />]],
        x,
        y1,
        ele_max,
        y1,
        ele_max + ctl,
        y1,
        x_max - ctl,
        y2,
        x_max,
        y2
      )
    end
  end

  w("</svg>")
  return table.concat(output, "\n")
end

local function test()
  local common = require("common")
  local waypoints = common.read_waypoints("data/waypoints.json")
  local track = common.read_track("data/geo.json")
  local callouts = {
    "ATA_1009",
    "ATA_1004",
    "ATA_3134",
    "ATA_1138",
    "ATA_1126",
    "ATA_1111",
    "ATA_1000",
    "ATA_0986",
    "AZT_12-080",
    "ATA_1040",
    "ATA_0909",
    "ATA_0410",
    "ATA_0387",
    "ATA_0349",
    "ATA_0721",
    "ATA_0443",
    "ATA_0599",
    "ATA_0287",
    "ATA_0245",
    "ATA_0023",
    "ATA_0210",
  }
  for k, id in pairs(callouts) do
    callouts[k] = waypoints[id]
  end
  local svg = profile_svg(track, callouts, "200", "800")
  common.write_file("profile.html", "<html><body>" .. svg)
end

return {
  test = test,
  profile_svg = profile_svg,
}
