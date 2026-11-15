-- StringsUI: strings owned by the UI/UX workstream. Entries:  key = { "русский", "English" }.
local P = {
	-- HUD
	ui_your_role = { "Твоя роль", "Your role" },
	ui_your_job = { "Твоё задание", "Your job" },
	ui_assembly = { "Сборка", "Assembly" },
	ui_carrying = { "В руках", "Carrying" },
	ui_go = { "GO", "GO" },
	ui_nogo = { "NO-GO", "NO-GO" },
	ui_open = { "Открыть", "Open" },
	ui_close = { "Закрыть", "Close" },
	ui_nasa_file = { "Папка миссии NASA", "NASA mission file" },
	ui_sources = { "Источники", "Sources" },
	ui_source = { "Источник", "Source" },
	ui_offline = { "нет связи", "offline" },
	ui_hotkeys = { "Клавиши", "Keys" },
	-- shop
	ui_suit = { "Скафандр", "Spacesuit" },
	ui_suit_sub = { "Цвета и шлемы", "Colours and helmets" },
	ui_suit_soon = { "Мастерская скафандров скоро откроется!", "The suit workshop opens soon!" },
	ui_balance = { "Баланс", "Balance" },
	-- rocket lab
	ui_lab_src = { "Источник: NASA Glenn, «Ракеты для начинающих»", "Source: NASA Glenn, Beginner's Guide to Rockets" },
	ui_lab_meters = { "Проверка", "Check" },
	-- units
	u_kg = { "кг", "kg" },
	u_m = { "м", "m" },
	u_km = { "км", "km" },
	u_kms = { "км/с", "km/s" },
	u_w = { "Вт", "W" },
	u_wh = { "Вт·ч", "Wh" },
	u_mb = { "МБ", "MB" },
}
local out = { ru = {}, en = {} }
for k, v in P do out.ru[k] = v[1] out.en[k] = v[2] end
return out
