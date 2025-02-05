local data = require("filter.data")
local logging = require("filter.logging")

local MP = data.MP
local MILES_PER_METER = data.MILES_PER_METER

local filter2 = {}

function filter2.Code(code)
  if code.classes:includes("mp") then
    local wp = data.waypoint(code.text)
    if not wp then
      print("waypoint not found for " .. code.text)
      return nil
    end
    local nobo = wp[MP] * MILES_PER_METER
    local sobo = (data.trail_length() - wp[MP]) * MILES_PER_METER
    --return pandoc.Str(string.format("%.1f NOBO / %.1f SOBO", nobo, sobo))
    return pandoc.Span(
      pandoc.Inlines(string.format("%.1f nobo / %.1f sobo", nobo, sobo)),
      pandoc.Attr("", { "smallcaps" })
    )
  end
  return nil
end

local filter1 = {}

local doc_filters = {
  ["docs/resupply.html"] = "filter.resupply",
}

function filter1.Pandoc(d)
  local filter = doc_filters[PANDOC_STATE.output_file]
  if filter then
    return require(filter).filter_doc(d)
  end
  return nil
end

return { filter1, filter2 }
