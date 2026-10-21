local FalloffChart = class()

EWS.FalloffChart = FalloffChart

local BASELINE_COLOR = Color.white:with_alpha(0.2)

function FalloffChart:init(parent, x, y, w, h)
	self._panel = parent:panel({
		layer = 1,
		x = x,
		y = y,
		w = w,
		h = h
	})

	self._mid = math.floor(h / 2)
	self._scale = h - self._mid - 1
	self._bars = {}
	self._texts = {}

	for i = 1, w do
		self._bars[i] = self._panel:rect({
			x = i - 1,
			y = self._mid,
			w = 1,
			h = 1,
			color = BASELINE_COLOR
		})
	end
end

function FalloffChart:columns()
	return #self._bars
end

function FalloffChart:set_column(i, multiplier, text)
	local bar = self._bars[i]

	if not bar then
		return
	end

	self._texts[i] = text

	local delta = multiplier - 1

	if math.abs(delta) < 0.001 then
		bar:set_y(self._mid)
		bar:set_h(1)
		bar:set_color(BASELINE_COLOR)

		return
	end

	local h = math.clamp(math.ceil(math.abs(delta) * self._scale), 1, self._mid)

	if delta < 0 then
		bar:set_y(self._mid)
		bar:set_color(tweak_data.screen_colors.stats_negative)
	else
		bar:set_y(self._mid + 1 - h)
		bar:set_color(tweak_data.screen_colors.stats_positive)
	end

	bar:set_h(h)
end

function FalloffChart:text_at(x, y)
	if not self._panel:visible() or not self._panel:inside(x, y) then
		return nil
	end

	return self._texts[math.floor(x - self._panel:world_x()) + 1]
end

function FalloffChart:set_visible(visible)
	self._panel:set_visible(visible)
end
