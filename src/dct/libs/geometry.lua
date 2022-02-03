--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- 2D geometry utility functions.
--]]

-- luacheck: max comment line length 100

local class = require("libs.class")
local vec   = require("dct.libs.vector")

local geometry = {}

local Line = class()
function Line:__init(head, tail)
	if head.x > tail.x then
		head, tail = tail, head
	end
	self.head = vec.Vector2D(head)
	self.tail = vec.Vector2D(tail)	
	assert(self.head ~= self.tail, "line must have non-zero length")
end

function Line:getEquation()
	local base = vec.unitvec(self.tail - self.head)
	return math.atan2(base.y, base.x), self.head.y
end

function Line:length()
	return (self.tail - self.head):magnitude()
end

function Line:intersection(other)
	local slope1, intercept1 = self:getEquation()
	local slope2, intercept2 = other:getEquation()
	if slope1 == slope2 then
		local diff = Line(other.head - self.head, other.tail - self.tail)
		if diff:length() < self:length() then
			return other.head
		else
			return nil
		end
	end

	local point = vec.Vector2D.create(
		slope1 * (intercept2 - intercept1) / (slope1 - slope2) + intercept1,
		slope1 * (intercept2 - intercept1) / (slope1 - slope2) + intercept1
	)

	if point.x >= self.head.x and point.y >= self.head.y and
	   point.x <= self.tail.x and point.y <= self.tail.y then
		return point
	end

	return nil
end

function geometry.meanCenter2D(points)
	local min = vec.Vector2D.create( math.huge,  math.huge)
	local max = vec.Vector2D.create(-math.huge, -math.huge)
	for _, point in ipairs(points) do
		min.x = math.min(min.x, point.x)
		min.y = math.min(min.y, point.y)
		max.x = math.max(max.x, point.x)
		max.y = math.max(max.y, point.y)
	end
	return (max + min) / 2
end

local function get(tbl, idx)
	if idx < 1 or idx > #tbl then
		idx = idx % #tbl
	end
	if idx == 0 then
		idx = #tbl
	end
	return tbl[idx]
end

local function intersects(a, b, polygon)
	local line = geometry.Line(a, b)
	for i = 1, #polygon do
		local curr = get(polygon, i)
		local next = get(polygon, i + 1)
		if a ~= curr and a ~= next and b ~= curr and b ~= next then
			local across = geometry.Line(curr, next)
			if line:intersection(across) ~= nil then
				return true
			end
		end
	end
	return false
end

local function signedPolyArea(polygon)
	local total = 0
	for i = 1, #polygon do
		local curr = get(polygon, i)
		local next = get(polygon, i + 1)
		total = total + (next.x - curr.x) * (next.y + curr.y)
	end
	return total / 2
end

local function polygonArea(polygon)
	return math.abs(signedPolyArea(polygon))
end

local function isClockwise(polygon)
	return signedPolyArea(polygon) > 0
end

local function isInside(vertex, triangle)
	local a = polygonArea { vertex, triangle[2], triangle[3] }
	local b = polygonArea { triangle[1], vertex, triangle[3] }
	local c = polygonArea { triangle[1], triangle[2], vertex }
	return math.abs(polygonArea(triangle) - (a + b + c)) < 0.01
end

local function anyInside(triangle, vertices)
	for _, vertex in ipairs(vertices) do
		if vertex ~= triangle[1] and vertex ~= triangle[2] and
		   vertex ~= triangle[3] and isInside(vertex, triangle) then
			return true
		end
	end
	return false
end

-- reference:
-- https://www.gamedev.net/articles/programming/graphics/polygon-triangulation-r3334/
function geometry.triangulate(polygon)
	local clockwise = isClockwise(polygon)
	local triangulated = {}
	local vertices = {}
	for i = 1, #polygon do
		if clockwise then
			table.insert(vertices, 1, vec.Vector2D(polygon[i]))
		else
			table.insert(vertices, vec.Vector2D(polygon[i]))
		end
	end

	while true do
		local continue = false
		for i = 1, #vertices do
			local prev = get(vertices, i - 1)
			local curr = get(vertices, i)
			local next = get(vertices, i + 1)
			local triangle = { prev, curr, next }
			-- make sure we're creating a triangle on the inner side of the polygon
			local crossProduct = vec.cross(prev - curr, next - curr)
			if crossProduct > 0 and
			   not anyInside(triangle, vertices) and
			   not intersects(prev, next, vertices) and
			   not intersects(prev, curr, vertices) and
			   not intersects(curr, next, vertices) then
				table.insert(triangulated, triangle)
				table.remove(vertices, i)
				continue = true
				break
			end
		end
		if not continue then
			break
		end
	end

	assert(#vertices == 2,
		string.format( "not all vertices were triangulated: %d left", #vertices))

	for i = 1, #triangulated do
		assert(#triangulated[i] == 3,
			string.format("polygon idx %d is not a triangle", i))
	end

	return triangulated
end

local result
result = Line({ x = 1, y = 1 }, { x = 2, y = 2 }):intersection(Line({ x = 1.5, y = 1.5 }, { x = 3, y = 3 }))
assert(vec.Vector2D.create(1.5, 1.5) == result, "result not (1.5, 1.5): "..tostring(result))

result = Line({ x = 0, y = 0 }, { x = 1, y = 1 }):intersection(Line({ x = 2, y = 2 }, { x = 4, y = 4 }))
assert(nil == result, "result not nil: "..tostring(result))

result = Line({ x = 0, y = 0 }, { x = 1, y = 1 }):intersection(Line({ x = 1, y = 0 }, { x = 0, y = 1 }))
assert(vec.Vector2D.create(0.5, 0.5) == result, "result not (.5, .5): "..tostring(result))

result = Line({ x = 0, y = 0 }, { x = 100000, y = 0 }):intersection(Line({ x = 0, y = -1 }, { x = 20000, y = 1 }))
assert(nil ~= result, "result is nil: "..tostring(result))

result = Line({ x = -50000, y = -50000 }, { x = 50000, y = 50000 }):intersection(Line({ x = -50000, y = 50000 }, { x = 50000, y = -50000 }))
assert(vec.Vector2D.create(0, 0) == result, "result not (0, 0): "..tostring(result))

result = Line({ x = 0, y = 0 }, { x = 0, y = 100000 }):intersection(Line({ x = -1, y = 0 }, { x = 1, y = 20000 }))
assert(nil ~= result, "result is nil: "..tostring(result))

result = Line({ x = -1, y = 0 }, { x = 1, y = 20000 }):intersection(Line({ x = 0, y = 0 }, { x = 0, y = 100000 }))
assert(nil ~= result, "result is nil: "..tostring(result))

geometry.Line = Line
return geometry
