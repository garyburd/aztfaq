local data = require("filter.data")
local logging = require("filter.logging")

local LONG = data.LONG
local LAT = data.LAT
local MP = data.MP
local MILES_PER_METER = data.MILES_PER_METER
local stringify = pandoc.utils.stringify

local function infographc_block(callouts)
  table.sort(callouts, function(a, b)
    return a[MP] < b[MP]
  end)
  local blocks = {}
  for _, callout in ipairs(callouts) do
    local nobo = string.format("%.1f", callout[MP] * MILES_PER_METER)
    local inlines = pandoc.Inlines(nobo .. ":")
    for i, community in ipairs(callout.communities) do
      if i > 1 then
        inlines:extend(pandoc.Inlines(", "))
      end
      inlines:insert(pandoc.Link(community.name, "#" .. community.identifier))
    end
    if callout.description then
      inlines:extend(pandoc.Inlines(" ("))
      inlines:extend(callout.description)
      inlines:extend(pandoc.Inlines(")"))
    end
    table.insert(blocks, pandoc.Div({ pandoc.Plain(inlines) }))
  end
  local track = data.read_track("data/geo.json")
  local svg = require("filter.profile").profile_svg(track, callouts, "100", "100")
  return pandoc.Div({
    pandoc.RawBlock("html", svg),
    pandoc.Div(blocks),
  }, pandoc.Attr("x", { "infographic" }))
end

local function map_inline(s)
  s = stringify(s)

  local coords = {}
  local mode = "driving"
  for coord in s:gmatch("([^;]+)") do
    if coord == "foot" then
      mode = "walking"
    else
      local m = coord:match("(.*)!$")
      if m then
        local wp = data.waypoint(m)
        table.insert(coords, string.format("%f,%f", wp[LAT], wp[LONG]))
      else
        table.insert(coords, coord)
      end
    end
  end
  local url
  if #coords == 2 then
    local base = "https://www.google.com/maps/dir/"
    url = string.format("%s?api=1&basemap=terrain&mode=%s&origin=%s&destination=%s", base, mode, coords[1], coords[2])
  else
    local base = "https://www.openstreetmap.org/"
    url = string.format("%s?mlat=%s&zoom=17", base, coords[1]:gsub(",", "&mlon="))
  end
  return pandoc.Link(pandoc.Inlines("Map"), url)
end

local function access_block(community)
  local inlines = pandoc.List()
  for i, access in ipairs(community.access_points) do
    if i > 1 then
      inlines:insert(pandoc.LineBreak())
    end
    inlines:extend(pandoc.Inlines("Mile: "))
    inlines:insert(pandoc.Code(access.waypoint, pandoc.Attr("", { "mp" })))
    if access.description then
      inlines:extend(pandoc.Inlines(" ("))
      inlines:extend(access.description)
      inlines:extend(pandoc.Inlines(")"))
    end
    if access.map then
      inlines:extend({ pandoc.Space(), map_inline(access.map) })
    end
  end
  return pandoc.Div({ pandoc.Plain(inlines) })
end

local function filter_doc(doc)
  local callouts = {}
  local communities = {}
  for _, community in ipairs(doc.meta.communities) do
    community.identifier = stringify(community.name):gsub(" ", "-"):lower()
    communities[community.identifier] = community
    local callout_count = 0
    for _, access in ipairs(community.access_points) do
      if not access.hide then
        callout_count = callout_count + 1
      end
    end
    for _, access in ipairs(community.access_points) do
      access.waypoint = stringify(access.waypoint)
      if access.hide then
        data.copy_coords(access, data.waypoint(access.waypoint))
      else
        local callout = callouts[access.waypoint]
        if not callout then
          callout = { communities = {} }
          data.copy_coords(callout, data.waypoint(access.waypoint))
          callouts[access.waypoint] = callout
          table.insert(callouts, callout)
        end
        data.copy_coords(access, callout)
        table.insert(callout.communities, community)
        if callout_count > 1 and not callout.description and access.description then
          callout.description = access.description
        end
      end
    end
  end

  return doc:walk({
    Header = function(h)
      if h.identifier == "infographic" then
        return infographc_block(callouts)
      else
        local community = communities[h.identifier]
        if community then
          return { h, access_block(community) }
        end
      end
      return nil
    end,
  })
end

return { filter_doc = filter_doc }
